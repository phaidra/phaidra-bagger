#!/usr/bin/perl -w

=pod

=head1 phaidra_bagger_agent.pl (-j jobid | -rck) [-c config_path]

  -j jobid - run a specific ingest job
  -rck - check for ingest requests
  -c config_path - config path

=cut

use strict;
use warnings;
use Data::Dumper;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use PhaidraBaggerAgent;
use Switch;

my $jobid;
my $configpath;
my $action;

while (defined (my $arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
  	   if ($arg eq '-c') { $configpath = shift (@ARGV); }
  	elsif ($arg eq '-j') { $jobid = shift (@ARGV); $action = 'run_job' }
    elsif ($arg eq '-rck') {  $action = 'check_requests'; }
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
		my $agent = PhaidraBaggerAgent->new($configpath);
		$agent->check_requests(); 	
	}
	else { print "unknown action\n"; system ("perldoc '$0'"); exit(0); }
}	

exit(1);
