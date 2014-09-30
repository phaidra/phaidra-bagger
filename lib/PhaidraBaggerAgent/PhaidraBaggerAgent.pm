#!/usr/bin/perl -w

package PhaidraBaggerAgent;

use v5.10;
use strict;
use warnings;
use Data::Dumper;
use File::Find;
use Mojo::Util qw(slurp);
use Mojo::JSON;
use Mojo::Log;
use Mojo::UserAgent;
use Mojo::URL;
use MongoDB;
use Carp;
use MongoDB::MongoClient;
use Sys::Hostname;

my $folders;

sub new {
	my $class = shift;	 
	my $configpath = shift;	
	
	my $log;
	my $config;
	my $mongo;
	
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
	
	my %h = (
		ts_iso => $self->ts_iso(),	  	
		agent =>  $self->{config}->{"agent_id"},
		host => hostname,
		status => $status,
		activity => $activity, 
		PID => $$	
	);
	
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
	
	my $ingest_instance = $job->{ingest_instance};	
	
	$self->_init_pafdb($ingest_instance);
	
	# update activity - running jobid		
	$self->_update_activity("running", "ingesting job $jobid");
	
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
	
	while (my $bag = $bags->next) {
	
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
			$self->{'log'}->error("Bag ".$bag->{bagid}.": File $filepath does not exist");
			my @alerts = [{ type => 'danger', msg => "File $filepath does not exist"}];
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;				
		}
		
		# check if file is readable
		unless(-r $filepath){
			$self->{'log'}->error("Bag ".$bag->{bagid}.": File $filepath is not readable");
			my @alerts = [{ type => 'danger', msg => "File $filepath is not readable"}];
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;				
		}
		
		# check if we have owner's credentials
		
		my $credentials = $self->{config}->{accounts}->{$bag->{owner}};
		unless($credentials){
			$self->{'log'}->error("Bag ".$bag->{bagid}.": Bag owner: ".$bag->{owner}." not found in config.");
			my @alerts = [{ type => 'danger', msg => "Bag owner: ".$bag->{owner}." not found in config."}];
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;	
		}
		my $username = $credentials->{username};
		my $password = $credentials->{password};
		unless(defined($username) && defined($password)){
			$self->{'log'}->error("Bag ".$bag->{bagid}.": Credentials missing for bag owner: ".$bag->{owner});
			my @alerts = [{ type => 'danger', msg => "Credentials missing for bag owner: ".$bag->{owner}}];
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;	
		}
				
		# update job status
		$self->{jobs_coll}->update({'_id' => MongoDB::OID->new(value => $jobid)},{'$set' => {"updated" => time, status => 'running'}});
		# update activity - running jobid and bagid	
		$self->_update_activity("running", "ingesting job $jobid bag ".$bag->{bagid});		
		# update bag-job start_at and clean alerst
		my @alerts = ();
		$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid },{'$set' => {'jobs.$.started_at' => time, 'jobs.$.alerts' => \@alerts}});

		# ingest bag
		my ($pid, $alerts) = $self->_ingest_bag($filepath, $bag, $ingest_instance, $username, $password);

		# update bag-job pid, alerts and ts
		$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.pid' => $pid, 'jobs.$.finished_at' => time}});		
		if(defined($alerts)){
			my $alerts_size = scalar @{$alerts};
			if($alerts_size > 0){
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid},{'$set' => {'jobs.$.alerts' => $alerts}});			
			}	
		}
		# update job status 
		$self->{jobs_coll}->update({'_id' => MongoDB::OID->new(value => $jobid)},{'$set' => {"updated" => time, "finished_at" => time, status => 'finished'}});
						
		# insert event 
		$self->{events_coll}->insert({ts_iso => $self->ts_iso(),event => 'bag_ingest_finished',e => time,pid => $pid});		
	}
	
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
	
	$self->{'log'}->info(Dumper($bag->{'metadata'}));
	
	my $tx = $self->{ua}->post($url => form => { 
		
		# fixme
		metadata => { json => { metadata => $bag->{'metadata'}}},
		# fixme
		mimetype => 'image/tiff',
		file => { file => $filepath } 
			
	});
	
  	if (my $res = $tx->success) { 
  	  $pid = $res->json->{pid};
	}else{
	  my $err = $tx->error;
	  if ($err->{code}){
	  	push(@alerts, { type => 'danger', msg => "$err->{code} response: $err->{message}" });
	  }else{
	  	push(@alerts, { type => 'danger', "Connection error: $err->{message}" });
	  }
	}
	
	#push @alerts, {type => 'danger', msg => 'neiiiiiiiiin!'};
	
	return ($pid, \@alerts);
}

sub check_requests {
	my $self = shift;
	
	$self->{'log'}->info("Check requests");
	
	# update activity
	my $ts_iso = ts(); 	
	my $agent = $self->{"agent_id"};
	my $host = hostname;
	my $status = 'running';
	my $activity = 'checking requests';
	my $PID = $$;
	
	#last_request_time - if request found
	
	
	# update activity
	$ts_iso = ts(); 	
	$agent = $self->{"agent_id"};
	$host = hostname;
	$status = 'running';
	$activity = 'sleep';
	$PID = $$;
}

1;