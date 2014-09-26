package PhaidraBagger::Controller::Job;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mango::BSON::Time;
use Mango::BSON::Document;
use Time::Local;
use Date::Parse qw(str2time);
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

sub view {
    my $self = shift;
    my $init_data = { jobid => $self->stash('jobid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));  	 
    $self->render('job/view');	
}

sub load {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Loading job $jobid");
	
	my $oid = Mango::BSON::ObjectID->new($jobid);
	
	my $job = $self->mango->db->collection('jobs')->find_one({_id => $oid});
	unless(defined($job)){
		$self->app->log->error("[".$self->current_user->{username}."] Error loading job ".$jobid);
		$self->render(json => {alerts => [{ type => 'danger', msg => "Job with id ".$jobid." was not found" }]},status => 500);
		return;
	}
							    
	$self->app->log->info("[".$self->current_user->{username}."] Loaded job ".$job->{name}." [$jobid]");
	$self->render(json => {job => $job}, status => 200);		
		
}

sub save {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	my $jobdata = $self->req->json->{jobdata};
	
	$self->app->log->info("[".$self->current_user->{username}."] Saving job $jobid");
	
	my $oid = Mango::BSON::ObjectID->new($jobid);
	
	my $reply = $self->mango->db->collection('jobs')->update({_id => $oid},{ '$set' => { name => $jobdata->{name}, created => bson_time, updated => bson_time, status => 'scheduled', start_at => $jobdata->{start_at}, ingest_instance => $jobdata->{ingest_instance}} } );	

	$self->render(json => { alerts => [] }, status => 200);

}

sub toggle_run {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Toggle run for job $jobid");
	
	my $oid = Mango::BSON::ObjectID->new($jobid);
	
	# this does not work as an atomic transaction, 
	# but that should not cause too much trouble in this case
	# 1) get current status
	my $job = $self->mango->db->collection('jobs')->find_one({_id => $oid});
	unless(defined($job)){
		$self->app->log->error("[".$self->current_user->{username}."] Error loading job ".$jobid);
		$self->render(json => {alerts => [{ type => 'danger', msg => "Job with id ".$jobid." was not found" }]},status => 500);
		return;
	}
	
	# 2) set new status
	my $current_status = $job->{status};
	my $new_status;
	if($current_status eq 'running'){
		$new_status = 'suspended';
	}
	if($current_status eq 'suspended'){
		$new_status = 'running';
	}
	
	$self->mango->db->collection('jobs')->update({_id => $oid},{ '$set' => {updated => bson_time, status => $new_status} } );
	
	$self->render(json => { alerts => [{ type => 'success', msg => "Job status changed from $current_status to $new_status" }] }, status => 200);

}

sub delete {
	
	my $self = shift;  	
	my $jobid = $self->stash('jobid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Removing job $jobid");
	
	my $oid = Mango::BSON::ObjectID->new($jobid);
	
	my $reply = $self->mango->db->collection('jobs')->remove({_id => $oid});
		
	$self->render(json => { alerts => [] }, status => 200);
}


sub create {
	my $self = shift;  
	
	my $res = { alerts => [], status => 200 };
	
	my $selection = $self->req->json->{selection};
	my $jobdata = $self->req->json->{jobdata};

	my @jobitems;
	foreach my $item (@{$selection}){
		push @jobitems, { bagid => $item, status => 'new', error_msg => '', pid => ''};
	}

    my $start_at = Mango::BSON::Time->new(str2time($jobdata->{start_at})*1000);

	$self->app->log->info("[".$self->current_user->{username}."] Creating job ".$jobdata->{name});
	
	my $reply = $self->mango->db->collection('jobs')->insert({ name => $jobdata->{name}, created => bson_time, updated => bson_time, project => $self->current_user->{project}, created_by => $self->current_user->{username}, status => 'scheduled', start_at => $start_at, finished_at => '', ingest_instance => $jobdata->{ingest_instance}, bags => \@jobitems } );
	
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

	my $init_data = { 
		members => $self->config->{projects}->{$self->current_user->{project}}->{members},
		current_user => $self->current_user,
		ingest_instances => $self->config->{ingest_instances} 
	};
    $self->stash(init_data => encode_json($init_data));
      
	$self->render('jobs/list');
}

sub my {
    my $self = shift;  	 
    
    $self->render_later;

	my $coll = $self->mango->db->collection('jobs')
		->find({ created_by => $self->current_user->{username}})
		->sort({created => 1})
		->fields({ _id => 1, name => 1, created => 1, updated => 1, created_by => 1, status => 1, start_at => 1, finished_at => 1, ingest_instance => 1  })
		->all();

	unless(defined($coll)){
		my $err = $self->mango->db->command(bson_doc(getLastError => 1, w => 2));
	   	$self->app->log->info("[".$self->current_user->{username}."] Error searching jobs: ".$self->app->dumper($err));
	   	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching jobs" }] }, status => 500);	
	}
			    
	my $collsize = scalar @{$coll};
	$self->render(json => { jobs => $coll, alerts => [] , status => 200 });

}


1;
