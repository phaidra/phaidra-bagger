#!/usr/bin/perl -w

package PhaidraBaggerAgent;

use v5.10;
use strict;
use warnings;
use Data::Dumper;
use File::Find;
use Mojo::Util qw(slurp);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::Log;
use Mojo::UserAgent;
use Mojo::URL;
use MongoDB;
use Carp;
use FindBin;
use lib $FindBin::Bin;
use MongoDB::MongoClient;
use Sys::Hostname;

my $folders;

sub new {
	my $class = shift;
	my $configpath = shift;

	my $log;
	my $config;
	my $mongo;

	unless(defined($configpath)){
		$configpath = $FindBin::Bin.'/PhaidraBaggerAgent.json'
	}

	unless(-f $configpath){
		say "Error: config path $configpath is not a file";
		return undef;
	}

	unless(-r $configpath){
		say "Error: cannot access config: $configpath";
		return undef;
	}

	my $bytes = slurp $configpath;
	my $json = Mojo::JSON->new;
	$config = $json->decode($bytes);
	my $err  = $json->error;

	if($err){
		say "Error: $err";
		return undef;
	}

	$log = Mojo::Log->new(path => $config->{'log'}->{path}, level => $config->{'log'}->{level});

	$mongo = MongoDB::MongoClient->new(host => $config->{bagger_mongodb}->{host}, username => $config->{bagger_mongodb}->{username}, password => $config->{bagger_mongodb}->{password}, db_name => $config->{bagger_mongodb}->{database});

	my $self = {};
	$self->{'log'} = $log;
	$self->{config} = $config;
	$self->{mongo} = $mongo;
	$self->{baggerdb} = $mongo->get_database($self->{config}->{bagger_mongodb}->{database});
	$self->{jobs_coll} = $self->{baggerdb}->get_collection('jobs');
	$self->{bags_coll} = $self->{baggerdb}->get_collection('bags');
	$self->{ua} = Mojo::UserAgent->new;

	bless($self, $class);
	return $self;
}

sub ts_iso {
	my @ts = localtime (time());
	sprintf ("%04d%02d%02dT%02d%02d%02d", $ts[5]+1900, $ts[4]+1, $ts[3], $ts[2], $ts[1], $ts[0]);
}

sub _update_activity {
	my $self = shift;
	my $status = shift;
	my $activity = shift;
	my $last_reguest_time = shift;

	my %h = (
		ts_iso => $self->ts_iso(),
		agent =>  $self->{config}->{"agent_id"},
		host => hostname,
		status => $status,
		activity => $activity,
		PID => $$
	);

	if(defined($last_reguest_time)){
		$h{last_request_time} = $last_reguest_time;
	}

	#$self->{'log'}->debug("Updating activity ".Dumper(\%h));

	$self->{activity_coll}->update({agent => $self->{config}->{"agent_id"}}, \%h, {upsert => 1});

	return \%h;
}

sub _init_pafdb {
	my $self = shift;
	my $ingest_instance = shift;

	$self->{pafdb} = $self->{mongo}->get_database($self->{config}->{ingest_instances}->{$ingest_instance}->{paf_mongodb}->{database});
	$self->{activity_coll} = $self->{pafdb}->get_collection('activity');
	$self->{events_coll} = $self->{pafdb}->get_collection('events');
}

sub run_job {
	my $self = shift;
	my $jobid = shift;

	my $folders;

	$self->{'log'}->info("Run job $jobid");

	# find the job
	my $job = $self->{jobs_coll}->find_one({'_id' => MongoDB::OID->new(value => $jobid)});
	unless($job){
		$self->{'log'}->info("Job $jobid not found");
		return;
	}

	# check job status
	if($job->{status} ne 'scheduled'){
		my @alerts = [{ type => 'danger', msg => "Job $jobid not in 'scheduled' status"}];
		$self->{'log'}->error(Dumper(\@alerts));
		return;
	}

	my $ingest_instance = $job->{ingest_instance};

	$self->_init_pafdb($ingest_instance);

	# update activity - running jobid
	$self->_update_activity("running", "ingesting job $jobid");

	# update job status
	$self->{jobs_coll}->update({'_id' => MongoDB::OID->new(value => $jobid)},{'$set' => {"updated" => time, "status" => 'running', "started_at" => time}});

	my $count = $self->{bags_coll}->count({'jobs.jobid' => $jobid});

	# get job bags
	my $bags = $self->{bags_coll}->find(
		{'jobs.jobid' => $jobid},
		{
			bagid => 1,
			status => 1,
			path => 1,
			metadata => 1,
			owner => 1
		}
	);

	my $i = 0;
	while (my $bag = $bags->next) {
		$i++;

		$self->{'log'}->info("[$i/$count] Processing ".$bag->{bagid});

		# check if we were not suspended
		my $stat = $self->{bags_coll}->find_one({'jobs.jobid' => $jobid},{status => 1});
		if($stat->{'status'} eq 'suspended'){
				my @alerts = [{ type => 'danger', msg => "Job found suspended at bag ".$bag->{bagid}." [$i/$count]"}];
				$self->{'log'}->error(Dumper(\@alerts));
				# save error to bag
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
				last;
		}

		my $folderid = $bag->{folderid};

		# cache folders in a hash
		unless(exists($folders->{$folderid})){
			my $folders_coll = $self->{baggerdb}->get_collection('folders');
			my $folder = $folders_coll->find_one({'folderid' => $folderid});
			$folders->{$folderid} = $folder;
		}

		my $path = $folders->{$folderid}->{path};
		my $file = $bag->{file};
		my $filepath = $path;
		$filepath .= '/' unless substr($path, -1) eq '/';
		$filepath .= $file;

		# check if file exist
		unless(-f $filepath){
			my @alerts = [{ type => 'danger', msg => "Bag ".$bag->{bagid}.":File $filepath does not exist"}];
			$self->{'log'}->error(Dumper(\@alerts));
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;
		}

		# check if file is readable
		unless(-r $filepath){
			my @alerts = [{ type => 'danger', msg => "Bag ".$bag->{bagid}.": File $filepath is not readable"}];
			$self->{'log'}->error(Dumper(\@alerts));
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;
		}

		# check if we have owner's credentials
		my $credentials = $self->{config}->{accounts}->{$bag->{owner}};
		unless($credentials){
			my @alerts = [{ type => 'danger', msg => "Bag ".$bag->{bagid}.": Bag owner: ".$bag->{owner}." not found in config."}];
			$self->{'log'}->error(Dumper(\@alerts));
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;
		}
		my $username = $credentials->{username};
		my $password = $credentials->{password};
		unless(defined($username) && defined($password)){
			my @alerts = [{ type => 'danger', msg => "Bag ".$bag->{bagid}.": Credentials missing for bag owner: ".$bag->{owner}}];
			$self->{'log'}->error(Dumper(\@alerts));
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;
		}

		# check if there are metadata
		unless($bag->{metadata}->{uwmetadata}){ # or mods later
			my @alerts = [{ type => 'danger', msg => "Bag ".$bag->{bagid}." has no bibliographical metadata"}];
			$self->{'log'}->error(Dumper(\@alerts));
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;
		}

		# update activity - running jobid and bagid
		$self->_update_activity("running", "ingesting job $jobid bag ".$bag->{bagid});
		# update bag-job start_at and clean alerst
		my @alerts = ();
		$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid },{'$set' => {'jobs.$.started_at' => time, 'jobs.$.alerts' => \@alerts}});

		my $b = $self->{bags_coll}->find_one({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid}, {'jobs.$.pid' => 1});
		my $current_job = @{$b->{jobs}}[0];
		if($current_job->{pid}){
				my @alerts = [{ type => 'info', msg => "Bag ".$bag->{bagid}." already imported in this job, skipping"}];
				$self->{'log'}->info(Dumper(\@alerts));
				# save error to bag
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
				next;
		}

		# ingest bag
		my ($pid, $alerts) = $self->_ingest_bag($filepath, $bag, $ingest_instance, $username, $password);

		# update bag-job pid, alerts and ts
		$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.pid' => $pid, 'jobs.$.finished_at' => time}});
		if(defined($alerts)){
			my $alerts_size = scalar @{$alerts};
			$self->{'log'}->info('Alerts: '.Dumper($alerts));
			if($alerts_size > 0){
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => $alerts}});
			}
		}

		# insert event
		$self->{events_coll}->insert({ts_iso => $self->ts_iso(),event => 'bag_ingest_finished',e => time,pid => $pid});

		$self->{'log'}->info("[$i/$count] Done ".$bag->{bagid});
	}

	$self->{'log'}->info("Finished job ".$jobid);

	# update job status
	$self->{jobs_coll}->update({'_id' => MongoDB::OID->new(value => $jobid)},{'$set' => {"updated" => time, "finished_at" => time, "status" => 'finished'}});

	# update activity - finished
	$self->_update_activity("finished", "ingesting job $jobid");
}

sub _ingest_bag {

	my $self = shift;
	my $filepath = shift;
	my $bag = shift;
	my $ingest_instance = shift;
	my $username = shift;
	my $password = shift;

	my $pid;
	my @alerts = ();

	$self->{'log'}->info("Ingest bag=".$bag->{bagid}.", data path=$filepath, to instance=$ingest_instance");

	my $url = Mojo::URL->new;
	$url->scheme('https');
	$url->userinfo("$username:$password");
	my @base = split('/',$self->{config}->{ingest_instances}->{$ingest_instance}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/picture/create");
	}else{
		$url->path("/picture/create");
	}

	my $json = encode_json({metadata => $bag->{'metadata'}});

	#$self->{'log'}->info($json);

	my $tx = $self->{ua}->post($url => form => {
		metadata => $json,
		file => { file => $filepath },
		# we won't send the mimetype, currently we will rely on the magic in api
	});

  if (my $res = $tx->success) {
    $pid = $res->json->{pid};
	}else{

		if($tx->res->json){
			if($tx->res->json->{alerts}){
					return ($pid, $tx->res->json->{alerts});
			}
		}

		my $err = $tx->error;
		if ($err->{code}){
			push(@alerts, { type => 'danger', msg => $err->{code}." response: ".$err->{message} });
		}else{
			push(@alerts, { type => 'danger', msg => "Connection error: ".$err->{message} });
		}

	}

	return ($pid, \@alerts);
}

sub check_requests {
	my $self = shift;
	my $ingest_instance = shift;

	$self->{'log'}->info("Check requests");

	$self->_init_pafdb($ingest_instance);

	# update activity
	$self->_update_activity("running", "checking request");

	# find jobs & run them
	my $jobs = $self->{jobs_coll}->find({'start_at' => { '$lte' => time}, 'status' => 'scheduled'});
	while (my $job = $jobs->next) {
    	$self->run_job($job->{_id}->to_string);
	}

	# update activity
	$self->_update_activity("sleeping", "checking request", time);
}

1;
