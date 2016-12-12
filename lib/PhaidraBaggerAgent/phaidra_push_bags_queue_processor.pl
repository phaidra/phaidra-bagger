#!/usr/bin/env perl

=head1 NAME

push_queue_processor.pl


=head1 DESCRIPTION

Running phaidra-push Jobs agent in given intervals

=cut

use strict;
use warnings;
use Data::Dumper;

use MongoDB;

use Cwd 'abs_path';
use Path::Class::File;
use File::Spec;
use JSON;

use MongoDB;
use MongoDB::Connection;

use PhaidraBaggerAgent;


# perl phaidra_bagger_agent.pl -j '582c522906b2af62f6010000' -c /home/michal/Documents/code/area42/user/mf/angularjs/bagger/bagger/lib/PhaidraBaggerAgent/PhaidraBaggerAgent.json



###while (defined (my $arg= shift (@ARGV))){
###     if ($arg =~ /^-/){
###           if ($arg eq '-c') { $configPath = shift (@ARGV); }
###           else { system ("perldoc '$0'"); exit (0); }
###     }
###}

#my $filename = 'test.txt';
#open(my $fh, '>', $filename) or die "Could not open file '$filename' $!";
#print $fh "$configPath  three.!!!\n";
#close $fh;
#print "done\n";

#$configPath = '/home/michal/Documents/code/area42/user/mf/phaidra-push/PhaidraPush.json';

my $sleepIntervalSeconds = 5;

my $configPath ;
my $currentDir             = Path::Class::File->new(abs_path($0))->dir();
my $configPushJobsAgent    = File::Spec->catfile( @{$currentDir->{dirs}}, 'PhaidraBaggerAgent.json' );
#my $last_one               = pop @{$currentDir->{dirs}};
#$last_one                  = pop @{$currentDir->{dirs}};
#my $configPath      = File::Spec->catfile( @{$currentDir->{dirs}}, 'PhaidraBaggerAgent.json' );



my $configPhaidraPush = '/home/michal/Documents/code/area42/user/mf/phaidra-push/PhaidraPush.json';

my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $configPhaidraPush )
      or die("Can't open \$configPhaidraPush\": $!\n");
   local $/;
   <$json_fh>
};
my $json   = JSON->new;
my $config = $json->decode($json_text);


my $client = MongoDB::Connection->new( 
    host     =>     $config->{phaidra}->{mongodb}->{host},
    port     =>     $config->{phaidra}->{mongodb}->{port},
    username =>     $config->{phaidra}->{mongodb}->{username},
    password =>     $config->{phaidra}->{mongodb}->{password},
    db_name  =>     $config->{phaidra}->{mongodb}->{database}
);

my $collectionJobs = $client->ns( $config->{phaidra}->{mongodb}->{database}.'.'.'jobs' );

#-----
#my $configPath = '/home/michal/Documents/code/area42/user/mf/angularjs/bagger/bagger/lib/PhaidraBaggerAgent/PhaidraBaggerAgent.json';

print "$configPushJobsAgent \n";


                         my $filename = '/home/michal/Documents/code/area42/user/mf/phaidra-push/lib/PhaidraPushAgent/test11.txt';
                         open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
                         print $fh "Agent is working111234!!!\n";
                         close $fh;
                         print "done\n";




while (1) {
     my $agent = PhaidraBaggerAgent->new( $configPushJobsAgent );
     my $dataSet = $collectionJobs->find({'status' => 'scheduled', 'agent' => 'push_agent'});
     my $exists = $dataSet->count();
     if($exists){
           while (my $bag = $dataSet->next){
                 unless(defined($bag->{_id}->{value})){
                         print "undefined jobid\n"; system ("perldoc '$0'"); exit(0);
                         my $filename = '/home/michal/Documents/code/area42/user/mf/phaidra-push/lib/PhaidraPushAgent/test11.txt';
                         open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
                         print $fh "Agent is working1199!!!\n";
                         close $fh;
                 }
                         $agent->run_job($bag->{_id}->{value});
                 
                         my $filename = '/home/michal/Documents/code/area42/user/mf/phaidra-push/lib/PhaidraPushAgent/test11.txt';
                         open(my $fh, '>>', $filename) or die "Could not open file '$filename' $!";
                         print $fh "Agent is working1177!!!\n";
                         close $fh;
                         print "done\n";
                 print "Runing phaidra bagger jobs agent.  \n";
           }
           sleep($sleepIntervalSeconds);
     }else{
           print "sleeping... \n";           
           sleep($sleepIntervalSeconds);
     }
}

1;