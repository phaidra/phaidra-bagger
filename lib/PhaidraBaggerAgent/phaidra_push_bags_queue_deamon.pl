#!/usr/bin/env perl
use warnings;
use strict;
use Daemon::Control;
use Data::Dumper;

 
use Cwd 'abs_path';
use Path::Class::File;
use File::Spec;
 
my $currentDir =  Path::Class::File->new(abs_path($0))->dir();
my $processorScriptPath = File::Spec->catfile( @{$currentDir->{dirs}}, 'phaidra_push_bags_queue_processor.pl' );

print $processorScriptPath, "\n";


# /home/michal/Documents/code/area42/user/mf/angularjs/bagger/bagger/lib/PhaidraBaggerAgent/phaidra_push_bags_queue_processor.pl
# /home/michal/Documents/code/area42/user/mf/angularjs/bagger/bagger/lib/PhaidraBaggerAgent/phaidra_push_bags_queue_processor.pl

#$processorScriptPath = '/home/michal/Documents/code/area42/user/mf/phaidra-push/lib/PhaidraPushAgent/test3.pl';

exit Daemon::Control->new(
    name        => "Phaidra-push Jobs Agent",
    lsb_start   => '$syslog $remote_fs',
    lsb_stop    => '$syslog',
    lsb_sdesc   => 'Phaidra-push Jobs Agent',
    lsb_desc    => 'Phaidra-push Jobs Agent. Process Bags from  Bags MongoDb collection and creates the new objects',
    #path       => '/etc/init.d/apim-harvester',
    program     => "$processorScriptPath",
    #program_args => [ '--debug' ], for debugging the harvester
    pid_file    => '/tmp/phaidraPushJobAgent.pid',
    stderr_file => '/tmp/phaidraPushJobAgent.out',
    stdout_file => '/tmp/phaidraPushJobAgent.out',

    fork        => 2,
 
)->run;