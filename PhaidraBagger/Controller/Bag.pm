package PhaidraBagger::Controller::Bag;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::Home;
use Mojo::JSON qw(encode_json decode_json);
use File::Find;
use lib "lib";
use PhaidraBagMan qw(list_bags print_bags);
my $home = Mojo::Home->new;
$home->detect('PhaidraBagger');

use base 'Mojolicious::Controller';

sub get_uwmetadata_tree {
    my $self = shift;
    
	my $res = { alerts => [], status => 200 };
	
	if($self->app->config->{phaidra}->{local_uwmetadata_tree}){
		
		$self->app->log->debug("Reading uwmetadata tree from file");
		
		# read metadata tree
		my $content;
		my $metadatapath = $home->rel_file('public/uwmetadata/tree.json');
		open my $fh, "<", $metadatapath or push @{$res->{alerts}}, "Error reading uwmetadata/tree.json, ".$!;
	    local $/;
	    $content = <$fh>;
	    close $fh;  
	    
	    unless(defined($content)){	    	
	    	push @{$res->{alerts}}, "Error reading uwmetadata/tree.json, no content";
	    	next;
	    }

		my $metadata = decode_json($content);
 		$res->{tree} = $metadata->{tree};
 		$res->{languages} = $metadata->{languages};
 		
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
		open my $fh, "<", $metadatapath or push @{$res->{alerts}}, "Error reading metadata.json of bag $bag, ".$!;
	    local $/;
	    $content = <$fh>;
	    close $fh;  
	    
	    unless(defined($content)){	    	
	    	push @{$res->{alerts}}, "Error reading metadata.json of bag $bag, no content";
	    	next;
	    }

		my $metadata = decode_json($content);				
			
		my $bagid = $metadata->{'ticket-reference'};
		my $owner = $metadata->{owner};
		
		unless(defined($bagid)){
	    	push @{$res->{alerts}}, "Error reading metadata.json of bag $bag, no bagid";
	    	next;
	    }
	    unless(defined($owner)){
	    	push @{$res->{alerts}}, "Error reading metadata.json of bag $bag, no owner";
	    	next;
	    }
	    
	    my $found = $self->mango->db->collection('bags')->find_one({bagid => $bagid, owner => $owner});
		
		if(defined($found->{bagid})){
			push @{$res->{alerts}}, "Not importing bag $bag, already exists with bagid ".$found->{bagid};
			next;
		}
		
		my $reply  = $self->mango->db->collection('bags')->insert({ bagid => $bagid, label => $bagid, folderid => '', owner => $owner, path => $bagpath, metadata => $metadata, created => bson_time, updated => bson_time } );
		
		my $oid = $reply->{oid};
		if($oid){
			push @{$res->{alerts}}, "Imported bag $bagid [oid: $oid]";			
		}else{
			push @{$res->{alerts}}, "Importing bag $bagid failed";
		}
		
		if(exists($projectconfig->{thumbnails})){
			$self->app->log->info("Generating thumbnails for bag ".$bag);
			$self->generate_thumbnails($projectconfig, $bags, $bag, $bagid);			
		}
	}
	
	$self->render(json => $res, status => $res->{status});
}

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

sub load {
	
	my $self = shift;  	
	my $bagid = $self->stash('bagid');
	
	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};	
	
	$self->app->log->info("[".$self->current_user->{username}."] Loading bag $bagid");	
	
	my $bag = $self->mango->db->collection('bags')->find_one({bagid => $bagid, owner => $owner});
	
	if(defined($bag)){
		
		$self->app->log->info("[".$self->current_user->{username}."] Loaded bag $bagid: ".$self->app->dumper($bag));				    
		my $metadata_exists = 0;
		if($bag->{metadata}){
			if($bag->{metadata}->{uwmetadata}){
				$metadata_exists = 1;
			}
		}
	
		unless($metadata_exists){
		    if($self->current_user->{project} eq 'DiFaB'){		
					    				    						    				    		
				my $rs = $self->get_uwmetadata_tree();				    		
								    		
			   	$self->difab_filter($rs->{tree}, 0, 1);
					
				unless($bag->{metadata}){
					$bag->{metadata} = undef;
				}
								    						    		
			  	if($rs->{status} eq 200){
			   		$bag->{metadata}->{uwmetadata} = $rs->{tree};
			   		$bag->{metadata}->{languages} = $rs->{languages};
			   	}	
			}
			
		}
				    
		$self->app->log->info("[".$self->current_user->{username}."] Loaded bag $bagid");
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

sub save_uwmetadata {
	
	my $self = shift;  	
	my $bagid = $self->stash('bagid');
	
	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};
	
	$self->app->log->info("[".$self->current_user->{username}."] Saving bag $bagid");
	
	my $reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => bson_time, 'metadata.uwmetadata' => $self->req->json->{uwmetadata}} } );
	
	$self->render(json => { alerts => [{ type => 'success', msg => "$bagid saved" }] }, status => 200);

}

sub delete {
	
	my $self = shift;  	
	my $bagid = $self->stash('bagid');
	
	my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};
	
	$self->app->log->info("[".$self->current_user->{username}."] Removing bag $bagid");
	
	my $reply = $self->mango->db->collection('bags')->remove({bagid => $bagid, owner => $owner});
		
	$self->render(json => { alerts => [] }, status => 200);
}

sub edit {
    my $self = shift;
    
    my $project_config = $self->config->{projects}->{$self->current_user->{project}};  	 
	my $thumb_path = $project_config->{thumbnails}->{url_path};
	my $redmine_baseurl = $project_config->{redmine_baseurl};
    
    my $templates = $self->mango->db->collection('templates.uwmetadata')
		->find({ project => $self->current_user->{project}})
		->sort({created => 1})
		->fields({ title => 1, created => 1, updated => 1, created_by => 1 })->all();
		
    my $init_data = { bagid => $self->stash('bagid'), templates => $templates, current_user => $self->current_user, thumb_path => $thumb_path, redmine_baseurl => $redmine_baseurl};
    $self->stash(init_data => encode_json($init_data));
    
	$self->render('bag/'.$self->current_user->{project}.'_edit');
}

sub my {
    my $self = shift;  	 
    
    $self->render_later;
    
    my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	$self->mango->db->collection('bags')
		->find({ owner => $owner })
		->sort({updated => -1})
		->fields({ bagid => 1, path => 1, created => 1, updated => 1, owner => 1 })
		->all(
			sub {
			    my ($reply, $error, $coll) = @_;

			    if ( $error ){
			    	$self->app->log->info("[".$self->current_user->{username}."] Error searching bags: ".$self->app->dumper($error));
			    	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching bags" }] }, status => 500);	
			    }
			    
			    my $collsize = scalar @{$coll};
			    $self->render(json => { bags => $coll, alerts => [{ type => 'success', msg => "Found $collsize bags" }] , status => 200 });
			}
	);

}

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

sub folder_bags {
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
    	init_data => encode_json($init_data), 
    	navtitle => $folder->{name}, 
    	navtitlelink => 'bags/folder/'.$folderid
    );
      
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
    my $status = $filter->{status};
    
    my %find;
    
    my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};
    
    $find{owner} = $owner;
    $find{folderid} = $folderid;
    if($assignee){
    	$find{assignee} = $assignee;	
    }
    if($status){
    	$find{status} = $status;	
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
        
    $self->render_later;

	#$self->app->log->info("Find:".$self->app->dumper(\%find));

	my $cursor = $self->mango->db->collection('bags')->find(\%find);

	# bug? count needs to be executed before the additional sorts, limits etc although in mongo it does not matter!
	my $hits = $cursor->count;
	
	$cursor
		->sort({$sortfield => $sortvalue})
		->fields({ bagid => 1, status => 1, label => 1, created => 1, updated => 1, owner => 1, tags => 1, assignee => 1 })
		->skip($from)
		->limit($limit);
					
	my $coll = $cursor->all();	
	
	#$self->app->log->info("coll:".$self->app->dumper($coll));
	
	$self->render(json => { items => $coll, hits => $hits, alerts => [] , status => 200 });

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
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => bson_time}, '$addToSet' =>	{ tags => $value }} );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute of bag $bagid to $value");		
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => bson_time, $attribute => $value }} );
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
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => bson_time}, '$pullAll' =>	{ tags => $value }} );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute of bag $bagid to ''");		
		$reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => bson_time, $attribute => '' }} );
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
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => bson_time }, '$addToSet' =>	{ tags => $value }}, { multi => 1 } );
	}else{		
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute to $value for bags:".$self->app->dumper($selection));
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => bson_time, $attribute => $value }}, { multi => 1 } );
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
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => bson_time}, '$pullAll' => { tags => [$value] }}, { multi => 1 }  );
	}else{
		$self->app->log->info("[".$self->current_user->{username}."] Changing $attribute to '' for bags:".$self->app->dumper($selection));		
		$reply = $self->mango->db->collection('bags')->update({bagid => {'$in' => $selection}, owner => $owner},{ '$set' => {updated => bson_time, $attribute => '' }}, { multi => 1 }  );
	}
	
	$self->render(json => { alerts => [] }, status => 200);
}

my %filter = (
	
	# mandatory
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#general" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#identifier" => { default => undef, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#title" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#language" => { default => "xx", included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#description" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#lifecycle" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#upload_date" => { default => undef, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#status" => { default => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_2/44", included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#contribute" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#role" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#entity" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity#firstname" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity#lastname" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity#institution" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#rights" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#cost" => { default => 0, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#copyright" => { default => 1, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#license" => { default => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_21/12"},
	
	# difab wanted
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#alt_title" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#keyword" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#histkult" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#dimensions" => { default => undef, included_children => 1 },
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#reference_number" => { default => undef, included_children => 1 },
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#inscription" => { default => undef, value_lang => 'bg'},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#note" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#gps" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/provenience/V1.0#provenience" => { default => undef, included_children => 1},
	"http://phaidra.univie.ac.at/XML/metadata/provenience/V1.0#location" => { default => undef},
	
);


sub difab_filter(){

	my $self = shift;
	my $children = shift;
	my $included_children = shift;
	my $set_default = shift;					

	foreach my $child (@{$children}){

		my $children_size = defined($child->{children}) ? scalar (@{$child->{children}}) : 0;
			
		my $chid = $child->{xmlns}."#".$child->{xmlname};
		
		#$self->app->log->debug("checking $chid");
		
		my $def = $filter{$chid};
		if(defined($def)){
			
			#$self->app->log->debug("def found ".$self->app->dumper($def));
						
			# included
			if(defined($def->{included})){
				$child->{included} = $def->{included};
			}else{
				$child->{included} = 1;
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
				$child->{included} = 0;	
			}
			
			$child->{included} = $included_children ? 1 : 0;
		}

		if($children_size > 0){
			if(defined($def)){
				if(defined($def->{included_children})){
					$self->difab_filter($child->{children}, $def->{included_children}, $set_default);
					return;
				}
			}
			$self->difab_filter($child->{children}, $included_children, $set_default);
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

1;
