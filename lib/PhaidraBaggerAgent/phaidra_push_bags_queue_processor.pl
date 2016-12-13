#!/usr/bin/env perl

=head1 NAME

phaidra_push_bags_queue_processor.pl


=head1 DESCRIPTION

use: perl phaidra_push_bags_queue_processor.pl -c /path/to/phaidra-push/PhaidraPush.json

Running PhaidraBaggerAgent->run_job(bagId) in given intervals, process bags, copy object 
to new phaidra instance (status => scheduled  in 'jobs' MongoDb)

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



my $sleepIntervalSeconds = 5;

###my $configPhaidraPush;
# $configPhaidraPush = '/home/michal/Documents/code/area42/user/mf/phaidra-push/PhaidraPush.json';
# TODO fix this in deamon too!!!!!
###while (defined (my $arg= shift (@ARGV))){
###     if ($arg =~ /^-/){
###           if ($arg eq '-c') { $configPhaidraPush = shift (@ARGV); }
###           else { system ("perldoc '$0'"); exit (0); }
###     }
###}


my $currentDir             = Path::Class::File->new(abs_path($0))->dir();
my $configPushJobsAgent    = File::Spec->catfile( @{$currentDir->{dirs}}, 'PhaidraBaggerAgent.json' );

my $last_one               = pop @{$currentDir->{dirs}};
$last_one                  = pop @{$currentDir->{dirs}};
my $configPathBagger             = File::Spec->catfile( @{$currentDir->{dirs}}, 'PhaidraBagger.json' );


my $json_text = do {
   open(my $json_fh, "<:encoding(UTF-8)", $configPathBagger )
      or die("Can't open \$configPathBagger\": $!\n");
   local $/;
   <$json_fh>
};
my $json   = JSON->new;
my $config = $json->decode($json_text);


my $client = MongoDB::Connection->new( 
    host     =>     $config->{mongodb}->{host},
    port     =>     $config->{mongodb}->{port},
    username =>     $config->{mongodb}->{username},
    password =>     $config->{mongodb}->{password},
    db_name  =>     $config->{mongodb}->{database}
);

my $collectionJobs = $client->ns( $config->{mongodb}->{database}.'.'.'jobs' );

while (1) {
     my $agent = PhaidraBaggerAgent->new( $configPushJobsAgent );
     my $dataSet = $collectionJobs->find({'status' => 'scheduled', 'agent' => 'push_agent'});
     my $exists = $dataSet->count();
     if($exists){
           while (my $bag = $dataSet->next){
                 unless(defined($bag->{_id}->{value})){
                         print "undefined jobid\n"; system ("perldoc '$0'"); exit(0);
                 }
                 $agent->run_job($bag->{_id}->{value});
                 print "Runing phaidra bagger jobs agent.  \n";
           }
           sleep($sleepIntervalSeconds);
     }else{
           print "sleeping... \n";           
           sleep($sleepIntervalSeconds);
     }
}

1;