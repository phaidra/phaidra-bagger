#!/usr/bin/perl -w

package PhaidraBaggerAgent;

use v5.10;
use strict;
use warnings;
use Data::Dumper;
use File::Find;
use FileHandle; #https://groups.google.com/forum/#!msg/mojolicious/y9J88fboW50/Qu-LEpCjtWwJ
use Mojo::Util qw(slurp);
use Mojo::ByteStream qw(b);
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
	$config = decode_json($bytes);	

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
	if($job->{status} ne 'suspended' && $job->{status} ne 'scheduled' && $job->{status} ne 'finished'){
		my @alerts = [{ type => 'danger', msg => "Job $jobid not in suspended, scheduled or finished status"}];
		$self->{'log'}->error(Dumper(\@alerts));
		return;
	}


	# check if we have projects's credentials
	my $credentials = $self->{config}->{accounts}->{$job->{project}};
	unless($credentials){
		my @alerts = [{ type => 'danger', msg => "Bag ".$job->{bagid}.": Bag project: ".$job->{project}." not found in config."}];
		$self->{'log'}->error(Dumper(\@alerts));
		return;
	}
	my $username = $credentials->{username};
	my $password = $credentials->{password};
	unless(defined($username) && defined($password)){
		my @alerts = [{ type => 'danger', msg => "Bag ".$job->{bagid}.": Credentials missing for bag project: ".$job->{project}}];
		$self->{'log'}->error(Dumper(\@alerts));
		return;
	}

	my $ingest_instance;
	my $type = $job->{type};
	my $current_run = $job->{current_run};
	
	# update activity - running jobid
	unless($type eq 'metadata_update'){		
		$ingest_instance = $job->{ingest_instance};
		$self->_init_pafdb($ingest_instance);
		$self->_update_activity("running", "ingesting job $jobid");
	}

	# update job status
	$self->{jobs_coll}->update({'_id' => MongoDB::OID->new(value => $jobid)},{'$set' => {"updated" => time, "status" => 'running', "started_at" => time}});

	my $count = $self->{bags_coll}->count({'jobs.jobid' => $jobid});

	# get job bags
	my $bags = $self->{bags_coll}->find(
		{'jobs.jobid' => $jobid, project => $job->{project}},
		{
			bagid => 1,
			status => 1,
			path => 1,
			metadata => 1,
			project => 1,
			jobs => 1	
		}
	);


	my $i = 0;
	my @pids;
	while (my $bag = $bags->next) {
		$i++;

		$self->{'log'}->info("[$i/$count] Processing ".$bag->{bagid});

		# check if we were not suspended
		my $stat = $self->{jobs_coll}->find_one({'_id' => MongoDB::OID->new(value => $jobid)},{status => 1});
		#my $stat = $self->{bags_coll}->find_one({'jobs.jobid' => $jobid},{status => 1});
		if($stat->{'status'} eq 'suspended'){
				my @alerts = [{ type => 'danger', msg => "Job found suspended at bag ".$bag->{bagid}." [$i/$count]"}];
				$self->{'log'}->error(Dumper(\@alerts));
				# save error to bag
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => \@alerts}});
				last;
		}

		my $path;
		my $file;
		my $filepath;
		unless($type eq 'metadata_update'){
			my $folderid = $bag->{folderid};

			# cache folders in a hash
			unless(exists($folders->{$folderid})){
				my $folders_coll = $self->{baggerdb}->get_collection('folders');
				my $folder = $folders_coll->find_one({'folderid' => $folderid});
				$folders->{$folderid} = $folder;
			}

			$path = $folders->{$folderid}->{path};
			$file = $bag->{file};
			$filepath = $path;
			$filepath .= '/' unless substr($path, -1) eq '/';
			$filepath .= $file;

			# check if file exist
			unless(-f $filepath){
				my @alerts = [{ type => 'danger', msg => "Bag [".$bag->{bagid}."]: File $filepath does not exist"}];
				$self->{'log'}->error(Dumper(\@alerts));
				# save error to bag
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => \@alerts}});
				next;
			}

			# check if file is readable
			unless(-r $filepath){
				my @alerts = [{ type => 'danger', msg => "Bag [".$bag->{bagid}."]: File $filepath is not readable"}];
				$self->{'log'}->error(Dumper(\@alerts));
				# save error to bag
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => \@alerts}});
				next;
			}
		}

		# check if there are metadata
		unless($bag->{metadata}->{uwmetadata} || $bag->{metadata}->{mods}){
			my @alerts = [{ type => 'danger', msg => "Bag [".$bag->{bagid}."] has no bibliographical metadata"}];
			$self->{'log'}->error(Dumper(\@alerts));
			# save error to bag
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => \@alerts}});
			next;
		}

		my $update_pid;
		my $update_instance;
		if($type eq 'metadata_update'){
			# check if there is pid			
			for my $bagjob (@{$bag->{jobs}}){
				if($bagjob->{jobid} eq $job->{ingest_job}){
					$update_pid = $bagjob->{pid};
					last;
				}
			}
			unless($update_pid){
				my @alerts = [{ type => 'danger', msg => "Bag [".$bag->{bagid}."] has no pid to update in the specified ingest job (".$job->{ingest_job}.")"}];
				$self->{'log'}->error(Dumper(\@alerts));
				# save error to bag
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => \@alerts}});
				next;
			}

			# get instance
			my $ingest_job = $self->{jobs_coll}->find_one({'_id' => $job->{ingest_job}});
			$update_instance = $ingest_job->{ingest_instance};
			$self->_init_pafdb($update_instance);
		}

		# update activity - running jobid and bagid
		if($type eq 'metadata_update'){
			$self->_update_activity("running", "update metadata job $jobid bag ".$bag->{bagid});
		}else{
			$self->_update_activity("running", "ingesting job $jobid bag ".$bag->{bagid});
		}

		# update bag-job start_at and clean alerts
		my @alerts = ();
		$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project} },{'$set' => {'jobs.$.started_at' => time, 'jobs.$.alerts' => \@alerts}});

		my $current_job;
		for my $bagjob (@{$bag->{jobs}}){
			if($bagjob->{jobid} eq $jobid){
				$current_job = $bagjob;
				last;
			}
		}
		#my $b = $self->{bags_coll}->find_one({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}}, {'jobs.$.pid' => 1});
		#my $current_job = @{$b->{jobs}}[0];

		if($type eq 'metadata_update'){	

			if($current_job->{last_finished_run} >= $current_run){
				my @alerts = [{ type => 'info', msg => "Pid [$update_pid] already updated in this job, skipping"}];
				$self->{'log'}->info(Dumper(\@alerts));
				next;
			}

			my ($success, $alerts) = $self->_update_metadata($bag, $update_pid, $update_instance, $username, $password);
			# update alerts
			if(defined($alerts)){
				if(scalar @{$alerts} > 0){
					$self->{'log'}->info(Dumper(\@alerts));
					$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => $alerts}});
				}
			}

			if($success){
				$self->{'log'}->info("Updated metadata bagid[".$bag->{bagid}."] pid[$update_pid]");
				$self->{events_coll}->insert({ts_iso => $self->ts_iso(),event => 'metadata_update_finished',e => time,pid => $update_pid});
			}
			# update bag-job last_finished_run and ts
			$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.last_finished_run' => $current_run, 'jobs.$.finished_at' => time}});			

			
		}else{

			if($current_job->{pid}){
				my @alerts = [{ type => 'info', msg => "Bag [".$bag->{bagid}."] already imported in this job, skipping"}];
				$self->{'log'}->info(Dumper(\@alerts));
				next;
			}

			# ingest bag
			my ($pid, $alerts) = $self->_ingest_bag($filepath, $bag, $ingest_instance, $username, $password);
			# update alerts
			if(defined($alerts)){
				if(scalar @{$alerts} > 0){
					$self->{'log'}->info(Dumper(\@alerts));
					$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.alerts' => $alerts}});
				}
			}
			$self->{'log'}->info("Ingested bagid[".$bag->{bagid}."] pid[$pid]") if(defined($pid));

			if($pid){
				push @pids, $pid;	

				# update bag-job pid and ts
				$self->{bags_coll}->update({bagid => $bag->{bagid}, 'jobs.jobid' => $jobid, project => $job->{project}},{'$set' => {'jobs.$.pid' => $pid, 'jobs.$.finished_at' => time}});

				# add to collection?
				if($job->{add_to_collection}){
					$self->{'log'}->info("Adding ".$bag->{bagid}."/$pid to collection ".$job->{add_to_collection});
					my $add_coll_alerts = $self->_add_to_collection($job->{add_to_collection}, $pid,  $ingest_instance, $username, $password);
					if($add_coll_alerts){
						foreach my $a (@{$add_coll_alerts}){
							push @{$alerts}, $a;
						}
					}
				}
			}
			# insert event
			$self->{events_coll}->insert({ts_iso => $self->ts_iso(),event => 'bag_ingest_finished',e => time,pid => $pid});
		}

		$self->{'log'}->info("[$i/$count] Done ".$bag->{bagid});
	}

	my %jobdata = (
		"updated" => time,
		"finished_at" => time,
		"status" => 'finished',
		"alerts" => []
	);

	unless($type eq 'metadata_update'){	
		my $coll_pid;
		my $coll_alerts;
		# create collection?
		if($job->{create_collection}){
			if(scalar @pids > 0){
				($coll_pid, $coll_alerts) = $self->_create_collection(\@pids, $job, $ingest_instance, $username, $password);
			}else{
				push @{$jobdata{alerts}}, { type => 'danger', msg => "Job collection not created - no objects created by the last run"};
			}
		}

		if($coll_pid){
			$jobdata{created_collection} = $coll_pid;
		}

		if($coll_alerts){
			push @{$jobdata{alerts}}, { type => 'danger', msg => "Could not create job collection"};
			foreach my $a (@{$coll_alerts}){
				push @{$jobdata{alerts}}, $a;
			}
		}
	}

	# update job status
	$self->{'log'}->info('Alerts: '.Dumper($jobdata{alerts})) if scalar @{$jobdata{alerts}} > 0;
	$self->{jobs_coll}->update({'_id' => MongoDB::OID->new(value => $jobid)},{'$set' => \%jobdata});

	$self->{'log'}->info("Finished job ".$jobid);

	# update activity - finished
	if($type eq 'metadata_update'){	
		$self->_update_activity("finished", "update metadata job $jobid");
	}else{
		$self->_update_activity("finished", "ingesting job $jobid");
	}
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

		$self->{'log'}->error(Dumper(\@alerts));

	}

	return ($pid, \@alerts);
}

sub _update_metadata {

	my $self = shift;	
	my $bag = shift;
	my $update_pid = shift;
	my $update_instance = shift;
	my $username = shift;
	my $password = shift;

	my $pid;
	my @alerts = ();

	$self->{'log'}->info("Update pid[$update_pid] bag[".$bag->{bagid}."] instance[$update_instance]");

	my $url = Mojo::URL->new;
	$url->scheme('https');
	$url->userinfo("$username:$password");
	my @base = split('/',$self->{config}->{ingest_instances}->{$update_instance}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/object/$update_pid/metadata");
	}else{
		$url->path("/object/$update_pid/metadata");
	}

	my $json = encode_json({metadata => $bag->{'metadata'}});

	$self->{'log'}->info("pre decode:\n".$json);

	$json = b($json)->decode('UTF-8');

	$self->{'log'}->info("post decode:\n".$json);

	my $tx = $self->{ua}->post($url => form => { metadata => $json });

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

		$self->{'log'}->error(Dumper(\@alerts));

	}

	return ($pid, \@alerts);
}

sub _create_collection {

	my $self = shift;
	my $pids = shift;
	my $job = shift;
	my $ingest_instance = shift;
	my $username = shift;
	my $password = shift;

	my $col_pid;
	my @alerts = ();

	my $data = { };	
	$data->{metadata} = $self->_get_collection_uwmetadata($job, $ingest_instance, $username, $password);
	unless($data->{metadata}){
		push(@alerts, { type => 'danger', msg => "Could not create collection metadata" });
	}else{

		foreach my $pid (@{$pids}){
			push @{$data->{metadata}->{members}}, { pid => $pid };
		}

		my $json = encode_json($data);

		my $url = Mojo::URL->new;
		$url->scheme('https');
		$url->userinfo("$username:$password");
		my @base = split('/',$self->{config}->{ingest_instances}->{$ingest_instance}->{apibaseurl});
		$url->host($base[0]);
		if(exists($base[1])){
			$url->path($base[1]."/collection/create");
		}else{
			$url->path("/collection/create");
		}

	  	my $tx = $self->{ua}->post($url => form => { metadata => $json });

		if (my $res = $tx->success) {
			return $res->json->{pid};
		}else {
			if($tx->res->json){
				if($tx->res->json->{alerts}){
					return ($col_pid, $tx->res->json->{alerts});
				}
			}
			my $err = $tx->error;
		 	if ($err->{code}){
				push(@alerts, { type => 'danger', msg => $err->{code}." response: ".$err->{message} });
			}else{
				push(@alerts, { type => 'danger', msg => "Connection error: ".$err->{message} });
			}
		}
	}

	return ($col_pid, \@alerts);
}

sub _get_collection_uwmetadata {
	my $self = shift;
	my $job = shift;
	my $ingest_instance = shift;
	my $username = shift;
	my $password = shift;


	my ($firstname, $lastname) = $self->_get_owner_data($ingest_instance, $username, $password);
	unless($firstname && $lastname){
		return;
	}

	return
	{
    		"uwmetadata" => [
      			{
			        "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
			        "xmlname" => "general",
			        "children" => [
	    			  {
			            "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
			            "xmlname"=> "title",
			            "ui_value" => $job->{name},
			            "value_lang" => "en",
			            "datatype" => "LangString"
			          },
			          {
			            "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
			            "xmlname" => "language",
			            "ui_value" => "xx",
			            "datatype" => "Language"
			          },
			          {
			            "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
			            "xmlname" => "description",
			            "ui_value" => "Collection of uploaded objects", # emmm, no better idea
			            "value_lang" => "en",
			            "datatype" => "LangString"
			          }
			        ]
      			},
  		        {
		        "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
		        "xmlname" => "lifecycle",
		        "children" => [
		          {
		            "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
		            "xmlname" => "contribute",
		            "data_order" => "0",
		            "ordered" => 1,
		            "children" => [
		              {
		                "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
		                "xmlname" => "role",
		                "ui_value" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_3/46",
		                "datatype" => "Vocabulary"
		              },
		              {
		                "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
		                "xmlname" => "entity",
		                "data_order" => "0",
		                "ordered" => 1,
		                "children" => [
		                  {
		                    "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity",
		                    "xmlname" => "firstname",
		                    "ui_value" => $firstname,
		                    "datatype" => "CharacterString"
		                  },
		                  {
		                    "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity",
		                    "xmlname" => "lastname",
		                    "ui_value" => $lastname,
		                    "datatype" => "CharacterString"
		                  }
		                ]
		              }
		            ]
		          }
		        ]
		      },
		      {
		        "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
		        "xmlname" => "rights",
		        "children" => [
		          {
		            "xmlns" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0",
		            "xmlname" => "license",
		            "ui_value" => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_21/1",
		            "datatype" => "License"
		          }
		        ]
		      }
    		]
  		}

}

sub _get_owner_data {
	my $self = shift;
	my $ingest_instance = shift;
	my $username = shift;
	my $password = shift;

	my @alerts;

	my $url = Mojo::URL->new;
	$url->scheme('https');
	$url->userinfo("$username:$password");
	my @base = split('/',$self->{config}->{ingest_instances}->{$ingest_instance}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/directory/user/$username/data");
	}else{
		$url->path("/directory/user/$username/data");
	}

  	my $tx = $self->{ua}->get($url);
  	if (my $res = $tx->success) {
		return ($res->json->{user_data}->{firstname}, $res->json->{user_data}->{lastname});
	}else {
		if($tx->res->json){
			if($tx->res->json->{alerts}){
				$self->{'log'}->error(Dumper($tx->res->json->{alerts}));
			}
		}
		my $err = $tx->error;
	 	if ($err->{code}){
			push(@alerts, { type => 'danger', msg => $err->{code}." response: ".$err->{message} });
		}else{
			push(@alerts, { type => 'danger', msg => "Connection error: ".$err->{message} });
		}
	}

	if(scalar @alerts > 0){
		$self->{'log'}->error("Error getting owner data :".Dumper(\@alerts));
	}
}

sub _add_to_collection {

	my $self = shift;
	my $coll_pid = shift;
	my $pid = shift;
	my $ingest_instance = shift;
	my $username = shift;
	my $password = shift;

	my @alerts = ();

	my $url = Mojo::URL->new;
	$url->scheme('https');
	$url->userinfo("$username:$password");
	my @base = split('/',$self->{config}->{ingest_instances}->{$ingest_instance}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/collection/$coll_pid/members");
	}else{
		$url->path("/collection/$coll_pid/members");
	}

  	my $tx = $self->{ua}->post($url => json => { members => [{ pid => $pid}]});

	if (my $res = $tx->success) {
		return;
	}else {
		if($tx->res->json){
			if($tx->res->json->{alerts}){
				return $tx->res->json->{alerts};
			}
		}
		my $err = $tx->error;
	 	if ($err->{code}){
			push(@alerts, { type => 'danger', msg => $err->{code}." response: ".$err->{message} });
		}else{
			push(@alerts, { type => 'danger', msg => "Connection error: ".$err->{message} });
		}
	}

	return \@alerts;
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
