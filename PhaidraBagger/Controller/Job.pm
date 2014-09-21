package PhaidraBagger::Controller::Job;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mango::BSON::Time;
use Time::Local;
use Date::Parse qw(str2time);
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

sub uwmetadata_job_editor {
    my $self = shift;
    my $init_data = { jobid => $self->stash('jobid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));  	 
    $self->render('jobeditor');	
}

sub load {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Loading job $jobid");
	
	my $oid = Mango::BSON::Objecjobid->new($jobid);
	
	$self->render_later;
	my $reply = $self->mango->db->collection('jobs.uwmetadata')->find_one(
		{_id => $oid} => 	
			sub {
				    my ($reply, $error, $doc) = @_;
	
				    if ( $error ){
				    	$self->app->log->error("[".$self->current_user->{username}."] Error loading job ".$jobid.":".$self->app->dumper($error));
						$self->render(
								json => { 
									uwmetadata => '', 
									title => '',
									alerts => [{ type => 'danger', msg => "Job with id ".$jobid." was not found" }] 
								}, 
						status => 500);	
				    }
				    
				    $self->app->log->info("[".$self->current_user->{username}."] Loaded job ".$doc->{title}." [$jobid]");
					$self->render(
							json => { 
								uwmetadata => $doc->{uwmetadata}, 
								title => $doc->{title},
								#alerts => [{ type => 'success', msg => "Job ".$doc->{title}." loaded" }] 
							}, 
					status => 200);
				   
				}
	);
		
}

sub save {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Saving job $jobid");
	
	my $oid = Mango::BSON::Objecjobid->new($jobid);
	
	my $reply = $self->mango->db->collection('jobs.uwmetadata')->update({_id => $oid},{ '$set' => {updated => bson_time, uwmetadata => $self->req->json->{uwmetadata}} } );
	
	my ( $sec, $min, $hour, $day, $mon, $year ) = localtime();
	my $now = sprintf("%02d.%02d.%04d %02d:%02d:%02d",$day, $mon + 1, $year + 1900, $hour, $min, $sec);
	$self->render(json => { alerts => [{ type => 'success', msg => "Saved at $now" }] }, status => 200);

}

sub delete {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Removing job $jobid");
	
	my $oid = Mango::BSON::Objecjobid->new($jobid);
	
	my $reply = $self->mango->db->collection('jobs.uwmetadata')->remove({_id => $oid});
		
	$self->render(json => { alerts => [] }, status => 200);
}


sub create {
	my $self = shift;  
	
	my $res = { alerts => [], status => 200 };
	
	my $selection = $self->req->json->{selection};
	my $jobdata = $self->req->json->{jobdata};

    my $startat = Mango::BSON::Time->new(str2time($jobdata->{startat})*1000);

	$self->app->log->info("[".$self->current_user->{username}."] Creating job ".$jobdata->{name});
	
	my $reply = $self->mango->db->collection('jobs')->insert({ name => $jobdata->{name}, created => bson_time, updated => bson_time, project => $self->current_user->{project}, created_by => $self->current_user->{username}, status => 'new', startat => $startat, ingest_instance => $jobdata->{ingest_instance}, bags => $selection } );
	
	my $oid = $reply->{oid};
	if($oid){
		$self->app->log->info("[".$self->current_user->{username}."] Created job ".$jobdata->{name}." [$oid]");
		$self->render(json => { jobid => "$oid", alerts => [{ type => 'success', msg => "Job ".$jobdata->{name}." created" }] }, status => 200);
	}else{
		$self->render(json => { alerts => [{ type => 'danger', msg => "Saving job ".$jobdata->{name}." failed" }] }, status => 500);
	}
}

sub jobs {
    my $self = shift;  	 

	my $init_data = { current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));
      
	$self->render('jobs/list');
}

sub my {
    my $self = shift;  	 
    
    $self->render_later;

	$self->mango->db->collection('jobs')
		->find({ created_by => $self->current_user->{username}})
		->sort({created => 1})
		->fields({ name => 1, created => 1, updated => 1, created_by => 1, status => 1, startat => 1, ingest_instance => 1  })
		->all(
			sub {
			    my ($reply, $error, $coll) = @_;

			    if ( $error ){
			    	$self->app->log->info("[".$self->current_user->{username}."] Error searching jobs: ".$self->app->dumper($error));
			    	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching jobs" }] }, status => 500);	
			    }
			    
			    my $collsize = scalar @{$coll};
			    $self->render(json => { jobs => $coll, alerts => [{ type => 'success', msg => "Found $collsize jobs" }] , status => 200 });
			}
	);

}


1;
