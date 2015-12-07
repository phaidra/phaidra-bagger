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
use Mojo::IOLoop::ProcBackground;
use Proc::Background;
use base 'Mojolicious::Controller';

sub view {
    my $self = shift;
    my $jobid = $self->stash('jobid');

	my $job = $self->mango->db->collection('jobs')->find_one({_id => Mango::BSON::ObjectID->new($jobid), project => $self->current_user->{project}},{ name => 1, alerts => 1, ingest_instance => 1 });

    my $init_data = {
    	jobid => $jobid,
    	navtitlelink => "job/$jobid/view",
    	navtitle => $job->{name},
    	ingest_instance => $self->config->{ingest_instances}->{$job->{ingest_instance}},
    	current_user => $self->current_user,
    	thumb_path => $self->url_for($self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path}),
    	members => $self->config->{projects}->{$self->current_user->{project}}->{members},
    	statuses => $self->config->{projects}->{$self->current_user->{project}}->{statuses},
    };

    $self->stash(
    	init_data => encode_json($init_data),
    	navtitle => $job->{name},
    	navtitlelink => "job/$jobid/view",
    	alerts => $job->{alerts}
    );

    $self->render('job/view');
}

sub bags {
    my $self = shift;

    my $jobid = $self->stash('jobid');

    my $payload = $self->req->json;
	my $query = $payload->{query};

    my $from = $query->{'from'};
    my $limit = $query->{'limit'};
    my $sortfield = $query->{'sortfield'};
    my $sortvalue = $query->{'sortvalue'};

    unless($sortfield){
    	$sortfield = 'status';
    }

    unless($sortvalue){
    	$sortvalue = -1;
    }

    #$self->app->log->info("Filter:".$self->app->dumper($query));

    my %find;

    $find{project} = $self->current_user->{project};
    $find{'jobs.jobid'} = $jobid;

    $self->render_later;

	#$self->app->log->info("Find:".$self->app->dumper(\%find));

	my $cursor = $self->mango->db->collection('bags')->find(\%find);

	# bug? count needs to be executed before the additional sorts, limits etc although in mongo it does not matter!
	my $hits = $cursor->count;

	$cursor
		->sort({$sortfield => $sortvalue})
		->fields({ bagid => 1, status => 1, label => 1, 'jobs.$' => 1 })
		->skip($from)
		->limit($limit);

	my $coll = $cursor->all();

	#$self->app->log->info("coll:".$self->app->dumper($coll));

	$self->render(json => { items => $coll, hits => $hits, alerts => [] , status => 200 });
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
	$self->render(json => {job => $job, alerts => $job->{alerts}}, status => 200);
}

sub save {

	my $self = shift;
	my $jobid = $self->stash('jobid');
	my $jobdata = $self->req->json->{jobdata};
	my $start_at = $jobdata->{start_at};
	if($start_at =~ /^[0-9]+$/g){
		$start_at = int $start_at;
		$start_at = int ($start_at/1000);
	}else{
  		$start_at = str2time($jobdata->{start_at});
	}
	$self->app->log->info("[".$self->current_user->{username}."] Saving job $jobid");

	my $oid = Mango::BSON::ObjectID->new($jobid);

	my $reply = $self->mango->db->collection('jobs')->update({_id => $oid},{ '$set' => { name => $jobdata->{name}, add_to_collection => $jobdata->{add_to_collection}, create_collection => $jobdata->{create_collection}, updated => time, status => 'scheduled', start_at => $start_at, ingest_instance => $jobdata->{ingest_instance}} } );

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
    	$self->mango->db->collection('jobs')->update({_id => $oid},{ '$set' => {updated => time, status => $new_status} } );
	}
	if($current_status eq 'suspended' || $current_status eq 'scheduled' || $current_status eq 'finished'){
    $self->app->log->info("[".$self->current_user->{username}."] Running job $jobid: ".$self->app->config->{bagger_agent_path}." -j $jobid");

    my $proc = Mojo::IOLoop::ProcBackground->new;

    $proc->on(alive => sub {
      my ($proc) = @_;
      my $pid = $proc->proc->pid;
      unless($self->stash->{'_proc_'.$pid}){
        $self->stash->{'_proc_'.$pid} = 0;
      }
      $self->stash->{'_proc_'.$pid}++;
      if($self->stash->{'_proc_'.$pid} == 1 || $self->stash->{'_proc_'.$pid} % 100 == 0){
        $self->app->log->info("[".$self->current_user->{username}."] Ingest job $pid still running");
      }
    });

    $proc->on(dead => sub {
      my ($proc) = @_;
      my $pid = $proc->proc->pid;
      $self->app->log->info("[".$self->current_user->{username}."] Ingest job $pid terminated");
      undef $self->stash->{'_proc_'.$pid};
    });

    $proc->run($self->app->config->{bagger_agent_path}." -j $jobid");
	}

  # { type => 'success', msg => "Job status changed from $current_status to $new_status" }
	$self->render(json => { alerts => [] }, status => 200);

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

    my $start_at = str2time($jobdata->{start_at});

	$self->app->log->info("[".$self->current_user->{username}."] Creating job ".$self->app->dumper($jobdata));

	my $reply = $self->mango->db->collection('jobs')->insert({ name => $jobdata->{name}, add_to_collection => $jobdata->{add_to_collection}, create_collection => $jobdata->{create_collection}, created => time, updated => time, project => $self->current_user->{project}, created_by => $self->current_user->{username}, status => 'scheduled', start_at => $start_at, finished_at => '', ingest_instance => $jobdata->{ingest_instance}} );

	my $jobid = $reply->{oid};
	if($jobid){
		$self->app->log->info("[".$self->current_user->{username}."] Created job ".$jobdata->{name}." [$jobid]");
	}else{
		$self->render(json => { alerts => [{ type => 'danger', msg => "Saving job ".$jobdata->{name}." failed" }] }, status => 500);
		return;
	}

	my $sel_size = scalar @{$selection};
	if($sel_size < 50){
		# save the jobid to bags
		$self->app->log->info("[".$self->current_user->{username}."] Saving job [".$jobdata->{name}." / $jobid] to $sel_size bags:\n".$self->app->dumper($selection));
		my $reply = $self->_create_job_update_bag($jobid, $selection);
	}else{
		# save the jobid to bags in chunks
		$self->app->log->info("[".$self->current_user->{username}."] Selection too big, saving job [".$jobdata->{name}."] to $sel_size bags in chunks");
		my $reply;
		my @subselection;
		my $subsel_size;
		while($sel_size > 0){

			push @subselection, shift @{$selection};

			$sel_size = scalar @{$selection};
			$subsel_size = scalar @subselection;

			if($subsel_size eq 50 || ($sel_size eq 0 && $subsel_size > 0)){
				$self->app->log->info("[".$self->current_user->{username}."] Saving job [".$jobdata->{name}."] to a chunk of $subsel_size bags ($sel_size bags left)");
				$reply = $self->_create_job_update_bag($jobid, \@subselection);
			}
		}

	}

	$self->render(json => { alerts => [] }, status => 200);
}

sub _create_job_update_bag {
	my $self = shift;
	my $jobid = shift;
	my $bags = shift;

	return 	$self->mango->db->collection('bags')->update(
		{ bagid => {'$in' => $bags } },
		{
			'$set'=> {
				updated => time,
			},
			'$push' => {
				jobs => {
		  			jobid => $jobid,
		  			started_at => '',
		  			finished_at => '',
		  			pid => ''
				}
			}
		},
		{ multi => 1 }
	);

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
		->find({ project => $self->current_user->{project}})
		->sort({created => 1})
		->fields({ _id => 1, name => 1, created => 1, updated => 1, created_by => 1, status => 1, start_at => 1, started_at => 1, finished_at => 1, ingest_instance => 1, add_to_collection => 1, create_collection => 1, created_collection => 1 })
		->all();

	unless(defined($coll)){
		my $err = $self->mango->db->command(bson_doc(getLastError => 1, w => 2));
	   	$self->app->log->info("[".$self->current_user->{username}."] Error searching jobs: ".$self->app->dumper($err));
	   	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching jobs" }] }, status => 500);
	}

	#my $collsize = scalar @{$coll};
	$self->render(json => { jobs => $coll, alerts => [] , status => 200 });
}


1;
