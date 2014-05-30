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
    my $init_data = { bagid => $self->stash('bagid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));  	 
    $self->render('bageditor');	
}

sub import {
	my $self = shift;
	
	my $res = { alerts => [], status => 200 };
	
	my $bagdirpath = $self->config->{bag_dir_path}->{$self->current_user->{project}};
	my $bags = list_bags($bagdirpath);
	
	foreach my $bag (keys %{$bags}){
		$self->app->log->info("Importing bag ".$bag);		

		my $path = $bagdirpath;
		
		$path .= '/' unless substr($path, -1) eq '/';
		$path .= $bag;
		
		# read bag metadata
		my $content;
		my $metadatapath = "$path/data/metadata.json";
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
		
		my $reply  = $self->mango->db->collection('bags')->insert({ bagid => $bagid, path => $path, metadata => $metadata, created => bson_time, updated => bson_time, owner => $owner } );
		
		my $oid = $reply->{oid};
		if($oid){
			push @{$res->{alerts}}, "Imported bag ".$bagid." [oid: $oid]";			
		}else{
			push @{$res->{alerts}}, "Importing bag $bagid failed";
		}
	}
	
	$self->render(json => $res, status => $res->{status});
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

	my $init_data = { current_user => $self->current_user };
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
