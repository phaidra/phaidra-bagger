package PhaidraBagger::Controller::Bag;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(encode_json decode_json);
use File::Find;
use lib "lib";
use PhaidraBagMan qw(list_bags print_bags);
use base 'Mojolicious::Controller';

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

sub import {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $projectconfig = $self->app->config->{projects}->{$self->current_user->{project}};
	my $bagdirpath = $projectconfig->{bags}->{in};

	my $bags = list_bags($bagdirpath);

	foreach my $bag (keys %{$bags}){
		$self->app->log->info("Importing bag ".$bag);

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
		my $owner = $metadata->{owner};

		unless(defined($bagid)){
	    	push @{$res->{alerts}}, { type => 'danger', msg => "Error reading metadata.json of bag $bag, no bagid"};
	    	next;
	    }
	    unless(defined($owner)){
	    	push @{$res->{alerts}}, { type => 'danger', msg => "Error reading metadata.json of bag $bag, no owner"};
	    	next;
	    }

	    my $found = $self->mango->db->collection('bags')->find_one({bagid => $bagid, owner => $owner});

		if(defined($found->{bagid})){
			push @{$res->{alerts}}, { type => 'warning', msg => "Not importing bag $bag, already exists with bagid ".$found->{bagid}};
			next;
		}

		my $reply  = $self->mango->db->collection('bags')->insert({ bagid => $bagid, label => $bagid, folderid => '', owner => $owner, path => $bagpath, , metadata => $metadata, created => time, updated => time } );

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

sub get_languages() {
	my $self = shift;
	my $rs = $self->get_uwmetadata_tree();
	return $rs->{languages};
}

sub load {

	my $self = shift;
	my $bagid = $self->stash('bagid');

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	$self->app->log->info("[".$self->current_user->{username}."] Loading bag $bagid");

	my $bag = $self->mango->db->collection('bags')->find_one({bagid => $bagid, owner => $owner});

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
				alerts => [{ type => 'danger', msg => "Bag with id ".$bagid." was not found" }]
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

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	$self->app->log->info("[".$self->current_user->{username}."] Saving bag $bagid");

	my $reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => time, 'metadata.uwmetadata' => $self->req->json->{uwmetadata}} } );

	$self->render(json => { alerts => [] }, status => 200);

}

sub delete {

	my $self = shift;
	my $bagid = $self->stash('bagid');

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	$self->app->log->info("[".$self->current_user->{username}."] Removing bag $bagid");

	my $reply = $self->mango->db->collection('bags')->remove({bagid => $bagid, owner => $owner});

	$self->render(json => { alerts => [] }, status => 200);
}

sub _edit_prepare_data {
	my $self = shift;

	my $project_config = $self->config->{projects}->{$self->current_user->{project}};
	my $thumb_path = $project_config->{thumbnails}->{url_path};
	my $redmine_baseurl = $project_config->{redmine_baseurl};

    my $templates = $self->mango->db->collection('templates.uwmetadata')
		->find({ project => $self->current_user->{project}})
		->sort({created => 1})
		->fields({ title => 1, created => 1, updated => 1, created_by => 1 })->all();

	my $init_data = { bagid => $self->stash('bagid'), templates => $templates, current_user => $self->current_user, thumb_path => $thumb_path, redmine_baseurl => $redmine_baseurl};

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};
	my $bag = $self->mango->db->collection('bags')->find_one({bagid => $self->stash('bagid'), owner => $owner}, {label => 1});

	$init_data->{navtitle} = $bag->{label};
	$init_data->{navtitlelink} = 'bag/'.$self->stash('bagid').'/edit';

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
	   		my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};
	   		my $folder = $self->mango->db->collection('folders')->find_one({folderid => $filter->{folderid}, owner => $owner},{ name => 1 });
	   		$init_data->{folder} = { folderid => $filter->{folderid}, name => $folder->{name} };
	   	}
    }

    #$self->app->log->debug("XXXXXXXX :".$self->app->dumper($init_data));

    $self->stash(init_data => encode_json($init_data));

	$self->render('bag/'.$self->current_user->{project}.'_edit');
}

=cut /bags, currently not used
sub bags {
    my $self = shift;
	my $thumb_path = $self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path};
	my $members = $self->config->{projects}->{$self->current_user->{project}}->{members};
	my $redmine_baseurl = $self->config->{projects}->{$self->current_user->{project}}->{redmine_baseurl};
	my $ingest_instances = $self->config->{ingest_instances};
    my $init_data = { current_user => $self->current_user, thumb_path => $thumb_path, redmine_baseurl => $redmine_baseurl, members => $members, ingest_instances => $ingest_instances };
    $self->stash(init_data => encode_json($init_data));

	$self->render('bags/list');
}
=cut

sub _folder_bags_prepare_data {
	my $self = shift;

    my $folderid = $self->stash('folderid');

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};
	my $folder = $self->mango->db->collection('folders')->find_one({folderid => $folderid, owner => $owner},{ name => 1 });

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
    	$sortfield = 'updated';
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

    my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

    $find{owner} = $owner;
    $find{folderid} = $folderid;
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
		->fields({ bagid => 1, status => 1, label => 1, created => 1, updated => 1, owner => 1, tags => 1, assignee => 1, alerts => 1, pids => 1, job => 1 })
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

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Adding $attribute $value to bag $bagid");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => time}, '$addToSet' =>	{ tags => $value }} );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute of bag $bagid to $value");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => time, $attribute => $value }} );
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

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Removing $attribute $value from bag $bagid");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => time}, '$pullAll' =>	{ tags => $value }} );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute of bag $bagid to ''");
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => time, $attribute => '' }} );
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

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Adding $attribute $value for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => time }, '$addToSet' =>	{ tags => $value }}, { multi => 1 } );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute to $value for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => time, $attribute => $value }}, { multi => 1 } );
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

	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	my $reply;
	if($attribute eq 'tags'){
		$self->app->log->info("[".$self->current_user->{username}."] Removing $attribute $value from bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => time}, '$pullAll' => { tags => [$value] }}, { multi => 1 }  );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute to '' for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => time, $attribute => '' }}, { multi => 1 }  );
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
    my $dir = shift;
    opendir my $dh, $dir or die $!;
    my $tree = {}->{$dir} = {};
    while( my $file = readdir($dh) ) {
        next if $file =~ m[^\.{1,2}$];
        my $path = $dir .'/' . $file;
        $tree->{$file} = hashdir($path), next if -d $path;
        push @{$tree->{'.'}}, $file;
    }
    return $tree;
}

1;
