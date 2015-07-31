#!/usr/bin/env perl

=pod

=head1 phaidra_bagger_agent.pl (-j jobid | -rck ingest_instance) [-c config_path]

  -j jobid - run a specific ingest job
  -rck ingest_instance - check for ingest requests
  -c config_path - config path

=cut

use strict;
use warnings;
use Data::Dumper;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use FindBin;
use lib $FindBin::Bin;
use PhaidraBaggerAgent;
use Switch;

$ENV{MOJO_MAX_MESSAGE_SIZE} = 1073741824;
$ENV{MOJO_INACTIVITY_TIMEOUT} = 600;
$ENV{MOJO_HEARTBEAT_TIMEOUT} = 600;

my $jobid;
my $configpath;
my $action;
my $ingest_instance;

while (defined (my $arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
  	   if ($arg eq '-c') { $configpath = shift (@ARGV); }
  	elsif ($arg eq '-j') { $jobid = shift (@ARGV); $action = 'run_job' }
    elsif ($arg eq '-rck') { $ingest_instance = shift (@ARGV); $action = 'check_requests'; }
    else { system ("perldoc '$0'"); exit (0); }
  }
}

unless(defined($action)){
	print "undefined action\n"; system ("perldoc '$0'"); exit(0);
}

switch ($action) {
	case 'run_job'	{
		unless(defined($jobid)){
			print "undefined jobid\n"; system ("perldoc '$0'"); exit(0);
		}

		my $agent = PhaidraBaggerAgent->new($configpath);
		$agent->run_job($jobid);
	}
	case 'check_requests' {
		unless(defined($ingest_instance)){
			print "undefined ingest instance\n"; system ("perldoc '$0'"); exit(0);
		}

		my $agent = PhaidraBaggerAgent->new($configpath);
		$agent->check_requests($ingest_instance);
	}
	else { print "unknown action\n"; system ("perldoc '$0'"); exit(0); }
}

exit(1);
