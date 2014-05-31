package PhaidraBagger::Controller::Bag;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(encode_json decode_json);
use lib "lib";
use PhaidraBagMan qw(list_bags print_bags);
use base 'Mojolicious::Controller';

sub bag_editor {
    my $self = shift;
    my $thumb_path = $self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path};
    my $redmine_baseurl = $self->config->{projects}->{$self->current_user->{project}}->{redmine_baseurl};
    my $init_data = { bagid => $self->stash('bagid'), current_user => $self->current_user, thumb_path => $thumb_path, redmine_baseurl => $redmine_baseurl};
    $self->stash(init_data => encode_json($init_data));  	 
    $self->render('bageditor');	
}

sub import {
	my $self = shift;
	
	my $res = { alerts => [], status => 200 };
	
	my $projectconfig = $self->config->{projects}->{$self->current_user->{project}};
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
		
		my $reply  = $self->mango->db->collection('bags')->insert({ bagid => $bagid, owner => $owner, path => $bagpath, metadata => $metadata, created => bson_time, updated => bson_time } );
		
		my $oid = $reply->{oid};
		if($oid){
			push @{$res->{alerts}}, "Imported bag ".$bagid." [oid: $oid]";			
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
	
	my $owner = $self->app->config->projects->{$self->current_user->{project}}->{owner};	
	
	$self->app->log->info("[".$self->current_user->{username}."] Loading bag $bagid");
	
	$self->render_later;
	my $reply = $self->mango->db->collection('bags')->find_one(
		{bagid => $bagid, owner => $owner} => 	
			sub {
				    my ($reply, $error, $bag) = @_;
	
				    if ( $error ){
				    	$self->app->log->error("[".$self->current_user->{username}."] Error loading bag ".$bagid.":".$self->app->dumper($error));
						$self->render(
								json => { 
									metadata => '', 
									created => '',
									updated => '',
									alerts => [{ type => 'danger', msg => "Bag with id ".$bagid." was not found" }] 
								}, 
						status => 500);	
				    }
				    
				    $self->app->log->info("[".$self->current_user->{username}."] Loaded bag $bagid");
					$self->render(
							json => { 
								metadata => $bag->{metadata}, 
								created => $bag->{created},
								updated => $bag->{updated}, 
							}, 
					status => 200);
				   
				}
	);
		
}

sub save {
	
	my $self = shift;  	
	my $bagid = $self->stash('bagid');
	
	my $owner = $self->app->config->projects->{$self->current_user->{project}}->{owner};
	
	$self->app->log->info("[".$self->current_user->{username}."] Saving bag $bagid");
	
	my $reply = $self->mango->db->collection('bags')->update({bagid => $bagid, owner => $owner},{ '$set' => {updated => bson_time, metadata => $self->req->json->{metadata}} } );
	
	$self->render(json => { alerts => [{ type => 'success', msg => "$bagid saved" }] }, status => 200);

}

sub delete {
	
	my $self = shift;  	
	my $bagid = $self->stash('bagid');
	
	my $owner = $self->app->config->projects->{$self->current_user->{project}}->{owner};
	
	$self->app->log->info("[".$self->current_user->{username}."] Removing bag $bagid");
	
	my $reply = $self->mango->db->collection('bags')->remove({bagid => $bagid, owner => $owner});
		
	$self->render(json => { alerts => [] }, status => 200);
}


sub bags {
    my $self = shift;  	 
	my $thumb_path = $self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path};
	my $redmine_baseurl = $self->config->{projects}->{$self->current_user->{project}}->{redmine_baseurl};
    my $init_data = { bagid => $self->stash('bagid'), current_user => $self->current_user, thumb_path => $thumb_path, redmine_baseurl => $redmine_baseurl};
    $self->stash(init_data => encode_json($init_data));
      
	$self->render('bags/list');
}

sub my {
    my $self = shift;  	 
    
    $self->render_later;
    
    my $owner = $self->app->config->{projects}->{$self->current_user->{project}}->{account};

	$self->mango->db->collection('bags')
		->find({ owner => $owner })
		->sort({created => 1})
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

1;
