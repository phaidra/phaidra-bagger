package PhaidraBagger::Controller::Bag;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(encode_json decode_json);
use File::Find;
use Mojo::Util qw(slurp);
use lib "lib";
use PhaidraBagMan qw(list_bags print_bags);
use base 'Mojolicious::Controller';
use utf8;

sub get_uwmetadata_tree {
    my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $cachekey = 'uwmetadata_tree';
	my $cacheval = $self->app->chi->get($cachekey);
	if($cacheval){
		$self->app->log->debug("[cache hit] $cachekey");
		return $cacheval;
	}

	if($self->app->config->{phaidra}->{local_uwmetadata_tree}){

		$self->app->log->debug("Reading uwmetadata tree from file");

		# read metadata tree
		my $content;
		open my $fh, "<", $self->app->config->{phaidra}->{local_uwmetadata_tree} or push @{$res->{alerts}}, "Error reading uwmetadata/tree.json, ".$!;
	    local $/;
	    $content = <$fh>;
	    close $fh;

	    unless(defined($content)){
	    	push @{$res->{alerts}}, "Error reading local_uwmetadata_tree, no content";
	    	next;
	    }

		my $metadata = decode_json($content);
 		$res->{tree} = $metadata->{tree};
 		$res->{languages} = $metadata->{languages};

 		$cacheval = $res;
 		$self->app->chi->set($cachekey, $cacheval, '1 day');
	    # serialization check
	    $cacheval = $self->app->chi->get($cachekey);

 		return $res;
	}

	$self->app->log->debug("Reading uwmetadata tree from api");

	my $url = Mojo::URL->new;
	$url->scheme('https');
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/uwmetadata/tree");
	}else{
		$url->path("/uwmetadata/tree");
	}
	$url->query({mfv => $self->app->config->{phaidra}->{metadata_format_version}});

	 my $tx = $self->ua->get($url);

		  	if (my $rs = $tx->success) {

				$res->{languages} = $rs->json->{languages};
				$res->{tree} = $rs->json->{tree};
				push @{$res->{alerts}}, $rs->json->{alerts};

				$cacheval = $res;
		 		$self->app->chi->set($cachekey, $cacheval, '1 day');
			    # serialization check
			    $cacheval = $self->app->chi->get($cachekey);
		  		return $res;

		  	}else {
			 	my ($err, $code) = $tx->error;
			  	if(exists($tx->res->json->{alerts})) {
			  		push @{$res->{alerts}}, $tx->res->json->{alerts};
			  		$res->{status} = $code ? $code : 500;
			  		return $res;

				 }else{
				 	push @{$res->{alerts}}, $err;
				  	$res->{status} = $code ? $code : 500;
			  		return $res;
				 }
			}
}

sub import_uwmetadata_xml {
  my $self = shift;
  my $res = { alerts => [], status => 200 };

  my $projectconfig = $self->app->config->{projects}->{$self->current_user->{project}};
  my $basepath = $projectconfig->{folders}->{uwmetadata_import};
  $self->app->log->info("[Uwmetadata import] Basepath: $basepath");
  my $folders = $self->hashdir($basepath);

  $self->app->log->info($self->app->dumper($folders));

  my $cnt = 0;
  foreach my $folder (keys %{$folders}){
    $self->app->log->info("[Uwmetadata import] folder $folder");

	$cnt++;
    #last if($cnt > 1);

    my $folderpath = $basepath;

    $folderpath .= '/' unless substr($folderpath, -1) eq '/';
    $folderpath .= $folder;

    $self->app->log->info("[Uwmetadata import] folderpath $folderpath");

    # folder name is the folder id
    my $folderid = $folder;
    # clean folder id of special chars
    $folderid =~ s/\W//g;

    # importing files
    my $cntf = 0;
    foreach my $file (@{$folders->{$folder}->{'.'}}){

      $cntf++;
    	#last if($cntf > 1);

      $self->app->log->info("[Uwmetadata import] $cnt Importing object ".$file);

      # remove the .xml, then it should be the same bagid as the data file had
      my $file_no_xml_suff = $file;
      $file_no_xml_suff =~ s/\.xml//g;

      # folder + filename, is the id
      my $bagid = $folderid."_".$file_no_xml_suff;
      # clean file id of special chars
      $bagid =~ s/\W//g;

      my $bag = $self->mango->db->collection('bags')->find_one({bagid => $bagid, project => $self->current_user->{project}});

      if(defined($bag->{folderid})){

        push @{$res->{alerts}}, "[Uwmetadata import] $cnt Found bag ".$bag->{bagid};

        if($bag->{metadata}){
            if($bag->{metadata}->{uwmetadata}){
              push @{$res->{alerts}}, "[Uwmetadata import] $cnt bag ".$bag->{bagid}." already contains metadata, skipping.";
              next;
            }
        }

        my $filepath = $basepath;
        $filepath.= '/' unless substr($basepath, -1) eq '/';
        $filepath .= $folder.'/'.$file;

        my $xml = slurp($filepath);
        $self->app->log->info("[Uwmetadata import] reading file $filepath");

        # use api to turn xml to json
        my $url = Mojo::URL->new;
        $url->scheme('https');
        my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
        $url->host($base[0]);
        if(exists($base[1])){
          $url->path($base[1]."/uwmetadata/xml2json");
        }else{
          $url->path("/uwmetadata/xml2json");
        }

        my $token = $self->load_token;
        #$self->app->log->info("[Uwmetadata import] posting to ".$url);
        my $tx = $self->ua->post($url => {$self->app->config->{authentication}->{token_header} => $token} => $xml);

        if (my $result = $tx->success) {
           my $uwmetadata = $result->json->{uwmetadata};

		   # do some fixing
           if($self->current_user->{project} eq 'DiFaB'){
             $self->fix_difab_taxon_paths($bag->{bagid}, $uwmetadata);
           }

           # move the geo info from uwmetadata to geo
           my $geo = $self->extract_geo($bag->{bagid}, $uwmetadata);

           my $set = {
			 updated => time,
			 'metadata.uwmetadata' => $uwmetadata
		   };

           if($geo){
             $set->{'metadata.geo'} = $geo;
           }

           #$self->app->log->debug("[Uwmetadata import] got json ".$self->app->dumper($uwmetadata));
           push @{$res->{alerts}}, "[Uwmetadata import] $cnt saving uwmetadata bag ".$bag->{bagid};
           my $reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => $set } );
        }else {
           my ($err, $code) = $tx->error;
           $self->app->log->error("[Uwmetadata import] got error ".$self->app->dumper($err));
           if($tx->res->json){
              if(exists($tx->res->json->{alerts})) {
                foreach my $a (@{$tx->res->json->{alerts}}){
                  push @{$res->{alerts}}, "[Uwmetadata import] $cnt ERROR bag ".$bag->{bagid}.": ".$a->{msg};
                }
              }else{
                push @{$res->{alerts}}, "[Uwmetadata import] $cnt ERROR bag ".$bag->{bagid}.": ".$self->app->dumper($tx->res->json);
              }
           }else{
             push @{$res->{alerts}}, "[Uwmetadata import] $cnt ERROR bag ".$bag->{bagid}.": ".$self->app->dumper($err);
           }
       }
      }else{
        push @{$res->{alerts}}, "[Uwmetadata import] $cnt Bag $bagid not found";
      }
    }
  }
  $self->render(json => $res, status => $res->{status});
}

=cut
 my @s = split('\|',$val);

	  my $lat = $s[0];
	  my $lon = $s[1];

	  my $lat_char = ($lat =~ m/([-]+)/) ? 'S' : 'N';
	  my $lon_char = ($lon =~ m/([-]+)/) ? 'W' : 'E';

	  my ($deg_lat, $mm_lat, $ss_lat) = $self->_to_degrees($lat);
	  my ($deg_lon, $mm_lon, $ss_lon) = $self->_to_degrees($lon);

	  my $new = "$deg_lat°$mm_lat'$ss_lat''$lat_char|$deg_lon°$mm_lon'$ss_lon''$lon_char";

	  $gps_node->{ui_value} = $new;
	  $gps_node->{loaded_ui_value} = $new;
	  $gps_node->{loaded_value} = $new;
=cut
sub _to_degrees {
	my $self = shift;
	my $dec = shift;

	my $deg = int($dec);
	my $dm = abs($dec - $deg) * 60;

	my $mm = int($dm);
	my $ss = sprintf("%3.5f", (abs($mm - $dm) * 60));

	return ($deg, $mm, $ss);
}

# hack, remove after DiFaB stops using xmls as ingest input
sub fix_difab_taxon_paths {
  my $self = shift;
  my $bagid = shift;
  my $uwmetadata = shift;

  my $basicns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0';
  my $classns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification';
  my $hns = 'http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0';

  # get alt_titles node - fix 'gr', greece is 'el'
  my $gen_node = $self->get_json_node($self, $basicns, 'general', $uwmetadata);
  foreach my $n (@{$gen_node->{children}}){
  	if($n->{xmlname} eq 'alt_title' && $n->{value_lang} eq 'gr'){
  		$n->{value_lang} = 'el';
  	}
  }

  # get classification node paths
  my $class_node = $self->get_json_node($self, $basicns, 'classification', $uwmetadata);

  # if there's just one taxon and seq is -1 then it's not a phaidra taxon path, but just upstreamid
  # get taxon id (tid) for this upstream_id and get the whole taxon path
  my @ok_children;
  foreach my $n (@{$class_node->{children}}){
    if($n->{xmlname} eq 'taxonpath'){
      my $source;
      my $taxon;
      my $taxon_seq;
      my $taxon_cnt = 0;
      foreach my $tn (@{$n->{children}}){

        if($tn->{xmlname} eq 'source'){
            $source = $tn->{ui_value};
        }
        if($tn->{xmlname} eq 'taxon'){
            $taxon_cnt++;
            $taxon_seq = $tn->{data_order};
            $taxon = $tn->{ui_value};
        }
     }
     if($taxon_cnt == 1 && $taxon_seq eq '-1'){

        # parse upstream_identifier out of the 'uri'
        # 300000994 out of http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_5/300000994
        $taxon =~ m/($classns)\/(cls)_(\d+)\/(\w+)\/?$/;
        my $upstream_identifier = $4;

        unless($upstream_identifier){
          $self->app->log->error("[fix_difab_taxon_paths][$bagid] ERROR: cannot parse upstream_identifier out of uri: $taxon");
          next;
        }

        # get tid for this upstream identifier
        my $projectconfig = $self->app->config->{projects}->{'DiFaB'};
        use DBI;
        my $dbh = DBI->connect($projectconfig->{phaidradb}->{connection_string}, $projectconfig->{phaidradb}->{username}, $projectconfig->{phaidradb}->{password}, {AutoCommit => 1, mysql_enable_utf8 => 1});
        my $ss = qq/SELECT tid FROM taxon WHERE upstream_identifier = (?)/;
        my $sth = $dbh->prepare($ss) || $self->app->log->error("DB ERROR:".$dbh->errstr);
        $sth->execute($upstream_identifier) || $self->app->log->error("DB ERROR:".$dbh->errstr);
        my ($tid);
        $sth->bind_columns(undef,\$tid) || $self->app->log->error("DB ERROR:".$dbh->errstr);
        $sth->fetch;

        unless($tid){
          $self->app->log->error("[fix_difab_taxon_paths][$bagid] ERROR: cannot get tid for upstream_identifier: $upstream_identifier");
          next;
        }

        # get taxonpath for this tid
        my $url = Mojo::URL->new;
        $url->scheme('https');
        my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
        $url->host($base[0]);
        if(exists($base[1])){
          $url->path($base[1]."/terms/taxonpath");
        }else{
          $url->path("/terms/taxonpath/");
        }
        $url->query({uri => "$source/$tid"});
        my $token = $self->load_token;
        my $tx = $self->ua->get($url => {$self->app->config->{authentication}->{token_header} => $token});
        if (my $result = $tx->success) {

          # remove taxon
          splice($n->{children},1,1);

           my $taxonpath = $result->json->{taxonpath};
           my $i = 0;
           foreach my $taxondata (@{$taxonpath}){
             $i++;
             next if($i == 1); # first is 'source', that was ok, we don't need to change it

             my $txn = {
               xmlns => $classns,
               xmlname => "taxon",
               datatype => "Taxon",
               ordered => 1,
               data_order => $i-2,
               ui_value => $taxondata->{uri},
               value_labels => {
                 labels => $taxondata->{labels},
                 upstream_identifier => $taxondata->{upstream_identifier},
                 term_id => $taxondata->{term_id},
                 nonpreferred => $taxondata->{nonpreferred}
               }
             };

             push $n->{children}, $txn;
           }

           push @ok_children, $n;

        }else{
          $self->app->log->error("[fix_difab_taxon_paths][$bagid] ERROR: cannot get taxonpath for tid: $tid");
          next;
        }

      }else{
      	   push	@ok_children, $n;
      }
    }else{
    	push @ok_children, $n;
    }
  }
  # this deletes the failed onesg
  $class_node->{children} = \@ok_children;

}

# hack, remove after DiFaB stops using xmls as ingest input
sub extract_geo {
  my $self = shift;
  my $bagid = shift;
  my $uwmetadata = shift;

  my $basicns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0';
  my $hns = 'http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0';

  my $name = '';
  # get title so we can name the placemark
  my $gen_node = $self->get_json_node($self, $basicns, 'general', $uwmetadata);
  foreach my $n (@{$gen_node->{children}}){
  	if($n->{xmlname} eq 'title'){
  		 $name = $n->{ui_value};
  	}
  }

  my $gps_node = $self->get_json_node($self, $hns, 'gps', $uwmetadata);
  my $val = $gps_node->{ui_value};

  if($val){

	# delete it from uwmetadata
	$gps_node->{ui_value} = "";
	$gps_node->{loaded_ui_value} = "";
	$gps_node->{loaded_value} = "";

	my @s = split('\|',$val);

	my $lat = $s[0];
	my $lon = $s[1];

	return {
		kml => {
			document => {
				placemark => [
			  		{
			  			name => $name,
			  			description => '',
				  		point => {
				  			coordinates => {
				  				latitude => $lat,
				  				longitude => $lon
				  			}
				  		}
			  		}
			  	]
			}
		}
  	}
  }
}

# this method finds node of given namespace and xmlname
#
# xxx !! DANGER !! xxx
# A node is generally not defined only with namespace and xmlname
# but also with the position in the tree.
# The only node however, where the namespace and xmlname is not enough is:
# namespace: http://phaidra.univie.ac.at/XML/metadata/lom/V1.0
# xmlname: description
# because there are two, one on 'general' tab and one on 'rights'
# xxx !! xxxxxx !! xxx
#
sub get_json_node(){
	my ($self, $c, $namespace, $xmlname, $metadata) = @_;

	my $ret;
	foreach my $n (@{$metadata}){
		if($n->{xmlns} eq $namespace && $n->{xmlname} eq $xmlname){
			$ret = $n;
			last;
		}else{
			my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
			if($children_size > 0){
				$ret = $self->get_json_node($c, $namespace, $xmlname, $n->{children});
				last if($ret);
			}
		}
	}
	return $ret;
}

=cut not used currently, Folder::import is used instead
sub import {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $projectconfig = $self->app->config->{projects}->{$self->current_user->{project}};
	my $bagdirpath = $projectconfig->{bags}->{in};

	my $bags = list_bags($bagdirpath);

	foreach my $bag (keys %{$bags}){
		$self->app->log->info("Found bag ".$bag);

		my $bagpath = $bagdirpath;

		$bagpath .= '/' unless substr($bagpath, -1) eq '/';
		$bagpath .= $bag;

		# read bag metadata
		my $content;
		my $metadatapath = "$bagpath/data/metadata.json";
		open my $fh, "<", $metadatapath or push @{$res->{alerts}}, { type => 'danger', msg => "Error reading metadata.json of bag $bag, ".$!};
	    local $/;
	    $content = <$fh>;
	    close $fh;

	    unless(defined($content)){
	    	push @{$res->{alerts}}, { type => 'danger', msg => "Error reading metadata.json of bag $bag, no content"};
	    	next;
	    }

		my $metadata = decode_json($content);

		my $bagid = $metadata->{'ticket-reference'};
		my $project = $metadata->{project};

		unless(defined($bagid)){
	    	push @{$res->{alerts}}, { type => 'danger', msg => "Error reading metadata.json of bag $bag, no bagid"};
	    	next;
	    }
	    unless(defined($self->current_user->{project})){
	    	push @{$res->{alerts}}, { type => 'danger', msg => "Error reading metadata.json of bag $bag, no project"};
	    	next;
	    }

	    my $found = $self->mango->db->collection('bags')->find_one({bagid => $bagid, project => $self->current_user->{project}});

		if(defined($found->{bagid})){
			push @{$res->{alerts}}, { type => 'warning', msg => "Not importing bag $bag, already exists with bagid ".$found->{bagid}};
			next;
		}

		my $reply  = $self->mango->db->collection('bags')->insert({ bagid => $bagid, label => $bagid, folderid => '', project => $self->current_user->{project}, path => $bagpath, , metadata => $metadata, created => time, updated => time } );

		my $oid = $reply->{oid};
		if($oid){
			push @{$res->{alerts}}, { type => 'info', msg => "Imported bag $bagid [oid: $oid]"};
		}else{
			push @{$res->{alerts}}, { type => 'danger', msg => "Importing bag $bagid failed"};
		}

		if(exists($projectconfig->{thumbnails})){
			$self->app->log->info("Generating thumbnails for bag ".$bag);
			$self->generate_thumbnails($projectconfig, $bags, $bag, $bagid);
		}
	}

	$self->render(json => $res, status => $res->{status});
}


sub generate_thumbnails {
	my $self = shift;
	my $projectconfig = shift;
	my $bags = shift;
	my $bag = shift;
	my $bagid = shift;

	my $bagdirpath = $projectconfig->{bags}->{in};
	my $bagpath = $bagdirpath;
	$bagpath .= '/' unless substr($bagpath, -1) eq '/';
	$bagpath .= $bag;

	my $thumb_dir = $projectconfig->{thumbnails}->{dir};

	my $thumb_dir_path = $thumb_dir;
	$thumb_dir_path .= '/' unless substr($thumb_dir_path, -1) eq '/';

	my $c_cmd = $projectconfig->{thumbnails}->{convert_cmd};
	my $m_cmd = $projectconfig->{thumbnails}->{thumbnail_medium_cmd};
	my $s_cmd = $projectconfig->{thumbnails}->{thumbnail_small_cmd};

	# if the thumbnails are needed than there is an /images folder (assumption)
	my $idx = 0;
	foreach my $img (@{$bags->{$bag}->{data}->{images}->{'.'}}){
		$idx++;

		$img =~ m/(^.*)\.([a-zA-Z0-9]*)$/;
		my $name = $1;
		my $ext = $2;
		my $newname = $bagid.'_'.$idx;

		my $imgpath = "$bagpath/data/images/$img";
		my $thumb_c_path = $thumb_dir_path."c_".$newname.'.png';
		my $thumb_m_path = $thumb_dir_path."m_".$newname.'.png';
		my $thumb_s_path = $thumb_dir_path."s_".$newname.'.png';

		my $generate_from_path = $imgpath;

		$self->app->log->info("Generating thumbnail for img $img");

		unless($ext eq 'png' || $ext eq 'PNG'){
			$self->app->log->debug("Converting $img to png");
			# first convert to png
			system("$c_cmd $imgpath $thumb_c_path");
			if( $? == -1 ){
			  $self->app->log->error("failed to convert image $imgpath to png: $!");
			}

			$generate_from_path = $thumb_c_path;
		}

		# medium, for bag detail
		$self->app->log->debug("Generating medium thumbnail from $generate_from_path");
		system("$m_cmd $generate_from_path $thumb_m_path");
		if( $? == -1 ){
		  $self->app->log->error("failed to generate medium thumbnail for $imgpath: $!");
		}

		# small, for bag list
		$self->app->log->debug("Generating small thumbnail from $generate_from_path");
		system("$s_cmd $generate_from_path $thumb_s_path");
		if( $? == -1 ){
		  $self->app->log->error("failed to generate small thumbnail for $imgpath: $!");
		}

		unless($ext eq 'png' || $ext eq 'PNG'){
			$self->app->log->debug("Deleting temp conversion file $thumb_c_path");
			# delete the png conversion file
			unlink $thumb_c_path or $self->app->log->error("failed to delete $thumb_c_path: $!");;
		}
	}
}
=cut

sub get_languages {
	my $self = shift;
	my $rs = $self->get_uwmetadata_tree();
	return $rs->{languages};
}

sub get_geo {
	my $self = shift;
	my $bagid = $self->stash('bagid');
	$self->app->log->info("[".$self->current_user->{username}."] Loading bag (get_geo) $bagid");

	my $bag = $self->mango->db->collection('bags')->find_one({bagid => $bagid, project => $self->current_user->{project}}, {'metadata.geo' => 1});
	unless($bag){

		$self->app->log->error("[".$self->current_user->{username}."] Error loading bag ".$bagid);
		$self->render(
			json => {
				geo => '',
				alerts => [{ type => 'danger', msg => "Error loading bag with id ".$bagid }]
			},
		status => 500);

	}else{
		$self->render( json => { geo => $bag->{metadata}->{geo}}, status => 200);
	}
}

sub load {

	my $self = shift;
	my $bagid = $self->stash('bagid');

	$self->app->log->info("[".$self->current_user->{username}."] Loading bag $bagid");

	my $bag = $self->mango->db->collection('bags')->find_one({bagid => $bagid, project => $self->current_user->{project}});

  # TODO: get ingest_instance to every job, for baginfo

	if(defined($bag)){

		#$self->app->log->info("[".$self->current_user->{username}."] Loaded bag $bagid: ".$self->app->dumper($bag));
		my $metadata_exists = 0;
		if($bag->{metadata}){
			if($bag->{metadata}->{uwmetadata}){
				$metadata_exists = 1;
			}
		}

		unless($metadata_exists){

          # load projects default template, if available
          my $tid = $self->get_default_template_id();
          if($tid){
            my $oid = Mango::BSON::ObjectID->new($tid);
            my $tmplt = $self->mango->db->collection('templates.uwmetadata')->find_one({_id => $oid});
            $self->app->log->info("[".$self->current_user->{username}."] Loaded default template '".$tmplt->{title}."' [$tid]");
            # init
            $bag->{metadata} = undef unless($bag->{metadata});
            $bag->{metadata}->{uwmetadata} = $tmplt->{uwmetadata};
            $bag->{metadata}->{languages} = $self->get_languages();
          }else{
  				  my $rs = $self->get_uwmetadata_tree();
            # init
  				  $bag->{metadata} = undef unless($bag->{metadata});
    		  	if($rs->{status} eq 200){
    		   		$bag->{metadata}->{uwmetadata} = $rs->{tree};
    		   		$bag->{metadata}->{languages} = $rs->{languages};
    		   	}
          }

		}else{
			$bag->{metadata}->{languages} = $self->get_languages();
		}
    $self->apply_hide_filter($bag->{metadata}->{uwmetadata});

		#$self->app->log->debug("[".$self->current_user->{username}."] Loaded bag $bagid");
		$self->render(json => $bag, status => 200);

	}else{
		$self->app->log->error("[".$self->current_user->{username}."] Error loading bag ".$bagid);
		$self->render(
			json => {
				metadata => '',
				created => '',
				updated => '',
				alerts => [{ type => 'danger', msg => "Error loading bag ".$bagid }]
			},
		status => 500);

	}

}

sub get_default_template_id {
    my $self = shift;

    # get user default template, if not availabe search for project default template
    my $length = 0;
    my $settings;
    my $res = $self->mango->db->collection('user.settings')->find_one({username => $self->current_user->{username}});
    if($res){
      $settings = $res->{settings};
      if($settings->{default_template}){
        return $settings->{default_template};
      }else{
        $res = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
        if($res){
          $settings = $res->{settings};
          if($settings->{default_template}){
            return $settings->{default_template};
          }
        }
      }
    }
}


sub save_uwmetadata {

	my $self = shift;
	my $bagid = $self->stash('bagid');

	$self->app->log->info("[".$self->current_user->{username}."] Saving uwmetadata for bag $bagid");

	my $reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => {updated => time, 'metadata.uwmetadata' => $self->req->json->{uwmetadata}} } );

	$self->render(json => { alerts => [] }, status => 200);

}

sub save_geo {

	my $self = shift;
	my $bagid = $self->stash('bagid');

	$self->app->log->info("[".$self->current_user->{username}."] Saving geo for bag $bagid");

	my $reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => {updated => time, 'metadata.geo' => $self->req->json->{geo}} } );

	$self->render(json => { alerts => [] }, status => 200);

}

sub delete {

	my $self = shift;
	my $bagid = $self->stash('bagid');

	$self->app->log->info("[".$self->current_user->{username}."] Removing bag $bagid");

	my $reply = $self->mango->db->collection('bags')->remove({bagid => $bagid, project => $self->current_user->{project}});

	$self->render(json => { alerts => [] }, status => 200);
}

sub _edit_prepare_data {
	my $self = shift;

	my $project_config = $self->config->{projects}->{$self->current_user->{project}};
	my $thumb_path = $project_config->{thumbnails}->{url_path};
	my $redmine_baseurl = $project_config->{redmine_baseurl};
  my $included_classifications = $project_config->{included_classifications};

    my $templates = $self->mango->db->collection('templates.uwmetadata')
		->find(
			{ '$or' =>
				[
					{ project => $self->current_user->{project}, created_by => $self->current_user->{username} },
					{ project => $self->current_user->{project}, shared => Mojo::JSON->true }
				]
			}
		)
		->sort({created => 1})
		->fields({ title => 1, created => 1, updated => 1, created_by => 1, shared => 1 })->all();

  my $bag = $self->mango->db->collection('bags')->find_one({bagid => $self->stash('bagid'), project => $self->current_user->{project}}, {label => 1, created => 1, updated => 1, assignee => 1, status => 1, project => 1});

	my $init_data = {
    bagid => $self->stash('bagid'),
    baginfo => $bag ,
    templates => $templates,
    current_user => $self->current_user,
    thumb_path => $thumb_path,
    redmine_baseurl => $redmine_baseurl,
    included_classifications => $included_classifications,
    navtitle => $bag->{label},
    navtitlelink => 'bag/'.$self->stash('bagid').'/edit',
    members => $self->config->{projects}->{$self->current_user->{project}}->{members},
    statuses => $self->config->{projects}->{$self->current_user->{project}}->{statuses},
    restricted_ops => $self->config->{projects}->{$self->current_user->{project}}->{restricted_operations}
  };

	$self->stash(
    	navtitle => $init_data->{navtitle},
    	navtitlelink => $init_data->{navtitlelink}
    );

	return $init_data;
}

sub edit {
	my $self = shift;

    #my $payload = $self->req->json;
	#my $query = $payload->{query};

    my $init_data = $self->_edit_prepare_data();

    my $filter = $self->param('filter');
    my $from = $self->param('from');
    my $limit = $self->param('limit');
    my $sortfield = $self->param('sortfield');
    my $sortvalue = $self->param('sortvalue');

    if($filter){
    	$filter = decode_json($filter);

	    my %query = (
	    	filter => $filter,
	    	from => $from,
	    	limit => $limit,
	    	sortfield => $sortfield,
	    	sortvalue => $sortvalue
	    );

	    # get next and prev bags
	    my ($hits, $coll) = $self->_search($filter, $from, $limit, $sortfield, $sortvalue);
	    my $prev;
	    my $next;
	    my $tmp;
	    my $bagid = $self->stash('bagid');

	    foreach my $bag (@{$coll}){
	    	if($bag->{bagid} eq $bagid){
	    		$prev = $tmp;
	    	}
	    	if($tmp){
		    	if($tmp->{bagid} eq $bagid){
		    		$next = $bag; last;
		    	}
	    	}
	    	$tmp = $bag;
	    }

	    #$self->app->log->debug("XXXXXXXXXXXX q:".$self->app->dumper(\%query));

	   	$init_data->{current_bags_query} = \%query;

	   	if($prev){
	   		$init_data->{prev_bag} = { bagid => $prev->{bagid}, label => $prev->{label} };
	   	}
	   	if($next){
	   		$init_data->{next_bag} = { bagid => $next->{bagid}, label => $next->{label} };
	   	}


	   	if($filter->{folderid}){
	   		my $folder = $self->mango->db->collection('folders')->find_one({folderid => $filter->{folderid}, project => $self->current_user->{project}},{ name => 1 });
	   		$init_data->{folder} = { folderid => $filter->{folderid}, name => $folder->{name} };
	   	}
    }

    #$self->app->log->debug("XXXXXXXX :".$self->app->dumper($init_data));

    $self->stash(init_data => encode_json($init_data));

	$self->render('bag/'.$self->current_user->{project}.'_edit');
}

sub bags {
  my $self = shift;

  my $init_data = {
    current_user => $self->current_user,
    thumb_path => $self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path},
    redmine_baseurl => $self->config->{projects}->{$self->current_user->{project}}->{redmine_baseurl},
    members => $self->config->{projects}->{$self->current_user->{project}}->{members},
    statuses => $self->config->{projects}->{$self->current_user->{project}}->{statuses},
    restricted_ops => $self->config->{projects}->{$self->current_user->{project}}->{restricted_operations},
    ingest_instances => $self->config->{ingest_instances}
  };

  $self->stash(
    navtitle => $init_data->{navtitle},
    navtitlelink => $init_data->{navtitlelink}
  );

  $self->stash(init_data => encode_json($init_data));

	$self->render('bags/list');
}


sub _folder_bags_prepare_data {
	my $self = shift;

  my $folderid = $self->stash('folderid');

	my $folder = $self->mango->db->collection('folders')->find_one({folderid => $folderid, project => $self->current_user->{project}},{ name => 1 });

    my $init_data = {
    	folderid => $folderid,
    	navtitlelink => 'bags/folder/'.$folderid,
    	navtitle => $folder->{name},
    	current_user => $self->current_user,
    	thumb_path => $self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path},
    	redmine_baseurl => $self->config->{projects}->{$self->current_user->{project}}->{redmine_baseurl},
    	members => $self->config->{projects}->{$self->current_user->{project}}->{members},
    	statuses => $self->config->{projects}->{$self->current_user->{project}}->{statuses},
    	restricted_ops => $self->config->{projects}->{$self->current_user->{project}}->{restricted_operations},
    	ingest_instances => $self->config->{ingest_instances}
    };

    $self->stash(
    	navtitle => $init_data->{navtitle},
    	navtitlelink => $init_data->{navtitlelink}
    );

    return $init_data;
}

sub folder_bags_with_query {
	my $self = shift;

	my $payload = $self->req->json;
	my $query = $payload->{query};

  my $init_data = $self->_folder_bags_prepare_data();

  if($query){
  	$init_data->{query} = $query;
  }

  $self->stash(init_data => encode_json($init_data));

  $self->render('bags/list');
}

sub folder_bags {
  my $self = shift;

  my $init_data = $self->_folder_bags_prepare_data();

  $self->stash(init_data => encode_json($init_data));

	$self->render('bags/list');
}

sub search {
  my $self = shift;

  my $filterfield = $self->stash('filterfield');
  my $filtervalue = $self->stash('filtervalue');

  my $payload = $self->req->json;
	my $query = $payload->{query};

  my $filter = $query->{'filter'};
  my $from = $query->{'from'};
  my $limit = $query->{'limit'};
  my $sortfield = $query->{'sortfield'};
  my $sortvalue = $query->{'sortvalue'};

	my ($hits, $coll) = $self->_search($filter, $from, $limit, $sortfield, $sortvalue, $filterfield, $filtervalue);
	#$self->app->log->debug("XXXXXXXX :".$self->app->dumper($coll));
	$self->render(json => { items => $coll, hits => $hits, alerts => []}, status => 200);
}

sub _search {
    my $self = shift;
    my $filter = shift;
    my $from = shift;
    my $limit = shift;
    my $sortfield = shift;
    my $sortvalue = shift;
    my $filterfield = shift;
    my $filtervalue = shift;

    unless($sortfield){
    	$sortfield = 'label';
    }

    unless($sortvalue){
    	$sortvalue = -1;
    }

    #$self->app->log->info("Filter:".$self->app->dumper($query));

    my $folderid = $filter->{folderid};
    my $assignee = $filter->{assignee};
    my $tag = $filter->{tag};
    my $statuses = $filter->{status};

    my %find;

    $find{project} = $self->current_user->{project};
    if($folderid){
      $find{folderid} = $folderid;
    }
    if($assignee){
    	$find{assignee} = $assignee;
    }
    if($statuses){
    	$find{status} = { '$in' => $statuses };
    }

    if($tag){
    	my @tags;
    	if(ref($tag) eq 'ARRAY'){
    		@tags = @{$tag};
    	}else{
			push @tags, $tag;
    	}
    	$find{tags} = { '$all' => \@tags };
    }

    if($filterfield && $filtervalue){
    	$find{$filterfield} = $filtervalue;
    }

	#$self->app->log->info("Find:".$self->app->dumper(\%find)." sortfield: $sortfield, sortvalue: $sortvalue");

	my $cursor = $self->mango->db->collection('bags')->find(\%find);

	# bug? count needs to be executed before the additional sorts, limits etc although in mongo it does not matter!
	my $hits = $cursor->count;

	$cursor
		->sort({$sortfield => int $sortvalue})
		->fields({ bagid => 1, status => 1, label => 1, created => 1, updated => 1, project => 1, tags => 1, assignee => 1, alerts => 1, pids => 1, job => 1 })
		->skip($from)
		->limit($limit);

	my $coll = $cursor->all();

	#$self->app->log->info("coll:".$self->app->dumper($coll));

	return ($hits, $coll);

=cut

non-blocing only after update to mongo 2.6 because of
https://groups.google.com/forum/#!topic/mojolicious/4_X9FPPlaVw

		->all(
			sub {
			    my ($reply, $error, $coll) = @_;

			    if ( $error ){
			    	$self->app->log->info("[".$self->current_user->{username}."] Error searching folders: ".$self->app->dumper($error));
			    	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching folders" }] }, status => 500);
			    }

			    # $self->app->log->debug("[".$self->current_user->{username}."] Hits: ".$hits."\nColl:".$self->app->dumper($reply));

			    $self->render(json => { items => $coll, hits => $hits, alerts => [] , status => 200 });
			}
	);
=cut

}

sub set_attribute {

	my $self = shift;
	my $bagid = $self->stash('bagid');
	my $attribute = $self->stash('attribute');
	my $value = $self->stash('value');

	my $restricted_ops = $self->app->config->{projects}->{$self->current_user->{project}}->{restricted_operations};

	foreach my $op (@{$restricted_ops}){
		if($op eq "set_$attribute"){
			unless($self->current_user->{role} eq 'manager'){
				$self->render(json => { alerts => [{ type => 'danger', msg => "You are not authorized for this operation" }] }, status => 403);
				return;
			}
			last;
		}
	}

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Adding $attribute $value to bag $bagid");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => {updated => time}, '$addToSet' =>	{ tags => $value }} );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute of bag $bagid to $value");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => {updated => time, $attribute => $value }} );
	}

	$self->render(json => { alerts => [] }, status => 200);
}

sub unset_attribute {

	my $self = shift;
	my $bagid = $self->stash('bagid');
	my $attribute = $self->stash('attribute');
	# used if attribute is an array
	my $value = $self->stash('value');

	my $restricted_ops = $self->app->config->{projects}->{$self->current_user->{project}}->{restricted_operations};

	foreach my $op (@{$restricted_ops}){
		if($op eq "unset_$attribute"){
			unless($self->current_user->{role} eq 'manager'){
				$self->render(json => { alerts => [{ type => 'danger', msg => "You are not authorized for this operation" }] }, status => 403);
				return;
			}
			last;
		}
	}

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Removing $attribute $value from bag $bagid");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => {updated => time}, '$pullAll' =>	{ tags => $value }} );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute of bag $bagid to ''");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, project => $self->current_user->{project}},{ '$set' => {updated => time, $attribute => '' }} );
	}

	$self->render(json => { alerts => [] }, status => 200);
}

sub set_attribute_mass {

	my $self = shift;

	my $payload = $self->req->json;
	my $selection = $payload->{selection};

	my $attribute = $self->stash('attribute');
	my $value = $self->stash('value');

	my $restricted_ops = $self->app->config->{projects}->{$self->current_user->{project}}->{restricted_operations};

	foreach my $op (@{$restricted_ops}){
		if($op eq "set_$attribute"){
			unless($self->current_user->{role} eq 'manager'){
				$self->render(json => { alerts => [{ type => 'danger', msg => "You are not authorized for this operation" }] }, status => 403);
				return;
			}
			last;
		}
	}

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Adding $attribute $value for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, project => $self->current_user->{project}},{ '$set' => {updated => time }, '$addToSet' =>	{ tags => $value }}, { multi => 1 } );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute to $value for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, project => $self->current_user->{project}},{ '$set' => {updated => time, $attribute => $value }}, { multi => 1 } );
	}

	$self->render(json => { alerts => [] }, status => 200);
}

sub unset_attribute_mass {

	my $self = shift;

	my $payload = $self->req->json;
	my $selection = $payload->{selection};

	my $attribute = $self->stash('attribute');
	# used if attribute is an array
	my $value = $self->stash('value');

	my $restricted_ops = $self->app->config->{projects}->{$self->current_user->{project}}->{restricted_operations};

	foreach my $op (@{$restricted_ops}){
		if($op eq "set_$attribute"){
			unless($self->current_user->{role} eq 'manager'){
				$self->render(json => { alerts => [{ type => 'danger', msg => "You are not authorized for this operation" }] }, status => 403);
				return;
			}
			last;
		}
	}

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Removing $attribute $value from bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, project => $self->current_user->{project}},{ '$set' => {updated => time}, '$pullAll' => { tags => [$value] }}, { multi => 1 }  );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute to '' for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, project => $self->current_user->{project}},{ '$set' => {updated => time, $attribute => '' }}, { multi => 1 }  );
	}

	$self->render(json => { alerts => [] }, status => 200);
}

sub apply_hide_filter {
    my $self = shift;
    my $children = shift;

    # get user include filter
    my $length = 0;
    my $settings;
    my $res = $self->mango->db->collection('user.settings')->find_one({username => $self->current_user->{username}});
    if($res){
      $settings = $res->{settings};
      if($settings->{visible_uwmfields}){
        $length = scalar @{$settings->{visible_uwmfields}};
      }
    }

    # if there is not user filter, fetch project settings
    if($length == 0){
      $res = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
    }

    if($res){
      $settings = $res->{settings};
      if($settings->{visible_uwmfields}){
        $length = scalar @{$settings->{visible_uwmfields}};
      }
    }

    if($length > 0){
      my %filter;
      foreach my $uri (@{$settings->{visible_uwmfields}}){
          $filter{$uri} = 1;
      }
      $self->apply_hide_filter_rec($children, \%filter);
    }
}


sub apply_hide_filter_rec {
  my $self = shift;
  my $children = shift;
  my $filter = shift;

  foreach my $child (@{$children}){
    my $childuri = $child->{xmlns}."#".$child->{xmlname};
    if($child->{help_id} eq "helpmeta_37"){
      $childuri = $child->{xmlns}."/rights#".$child->{xmlname};
    }

    unless($filter->{$childuri}){
      $child->{hide} = 1;
    }

    my $children_size = defined($child->{children}) ? scalar (@{$child->{children}}) : 0;
    if($children_size > 0){
      $self->apply_hide_filter_rec($child->{children}, $filter);
    }
  }
}

sub load_template {

  my $self = shift;
  my $tid = $self->stash('tid');

  $self->app->log->info("[".$self->current_user->{username}."] Loading template $tid");

  my $oid = Mango::BSON::ObjectID->new($tid);

  $self->render_later;
  my $reply = $self->mango->db->collection('templates.uwmetadata')->find_one(
    {_id => $oid} =>
      sub {
            my ($reply, $error, $doc) = @_;

            if ( $error ){
              $self->app->log->error("[".$self->current_user->{username}."] Error loading template ".$tid.":".$self->app->dumper($error));
            $self->render(
                json => {
                  uwmetadata => '',
                  title => '',
                  alerts => [{ type => 'danger', msg => "Template with id ".$tid." was not found" }]
                },
            status => 500);
            }

            $self->app->log->info("[".$self->current_user->{username}."] Loaded template ".$doc->{title}." [$tid]");

            my $uwmetadata = $doc->{uwmetadata};

            $self->apply_hide_filter($uwmetadata);

          $self->render(
              json => {
                uwmetadata => $uwmetadata,
                title => $doc->{title},
                #alerts => [{ type => 'success', msg => "Template ".$doc->{title}." loaded" }]
              },
          status => 200);

        }
  );

}

=cut
sub difab_filter(){

	my $self = shift;
	my $children = shift;
	my $include_children = shift;
	my $set_default = shift;

	foreach my $child (@{$children}){

		my $children_size = defined($child->{children}) ? scalar (@{$child->{children}}) : 0;

		my $chid = $child->{xmlns}."#".$child->{xmlname};

		#$self->app->log->debug("checking $chid");

		my $def = $filter{$chid};
		if(defined($def)){

			#$self->app->log->debug("def found ".$self->app->dumper($def));

			# include
			if(defined($def->{include})){
				$child->{include} = $def->{include};
			}else{
				$child->{include} = 1;
			}

			if($set_default){
				# default
				if(defined($def->{default})){
					$child->{ui_value} = $def->{default};
				}
				# value_lang
				if(defined($def->{value_lang})){
					$child->{value_lang} = $def->{value_lang};
				}

			}


		}else{
			# HACK rights>description has same xmlns & xmlname as general>description (WTAF)
			if($child->{help_id} eq "helpmeta_37"){
				$child->{include} = 0;
			}

			$child->{include} = $include_children ? 1 : 0;
		}

		if($children_size > 0){
			if(defined($def)){
				if(defined($def->{include_children})){
					$self->difab_filter($child->{children}, $def->{include_children}, $set_default);
					return;
				}
			}
			$self->difab_filter($child->{children}, $include_children, $set_default);
		}
	}

}


sub load_difab_template {

	my $self = shift;
	my $tid = $self->stash('tid');

	$self->app->log->info("[".$self->current_user->{username}."] Loading template $tid");

	my $oid = Mango::BSON::ObjectID->new($tid);

	$self->render_later;
	my $reply = $self->mango->db->collection('templates.uwmetadata')->find_one(
		{_id => $oid} =>
			sub {
				    my ($reply, $error, $doc) = @_;

				    if ( $error ){
				    	$self->app->log->error("[".$self->current_user->{username}."] Error loading template ".$tid.":".$self->app->dumper($error));
						$self->render(
								json => {
									uwmetadata => '',
									title => '',
									alerts => [{ type => 'danger', msg => "Template with id ".$tid." was not found" }]
								},
						status => 500);
				    }

				    $self->app->log->info("[".$self->current_user->{username}."] Loaded template ".$doc->{title}." [$tid]");

				    my $uwmetadata = $doc->{uwmetadata};

				    $self->difab_filter($uwmetadata, 0, 0);

					$self->render(
							json => {
								uwmetadata => $uwmetadata,
								title => $doc->{title},
								#alerts => [{ type => 'success', msg => "Template ".$doc->{title}." loaded" }]
							},
					status => 200);

				}
	);

}
=cut

sub hashdir {
  my $self = shift;
    my $dir = shift;
    opendir my $dh, $dir or die $!;
    my $tree = {}->{$dir} = {};
    while( my $file = readdir($dh) ) {
        next if $file =~ m[^\.{1,2}$];
        my $path = $dir .'/' . $file;
        $tree->{$file} = $self->hashdir($path), next if -d $path;
        push @{$tree->{'.'}}, $file;
    }
    return $tree;
}

1;
