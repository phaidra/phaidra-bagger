#!/usr/bin/perl

use v5.10;
use strict;
use warnings;
use Data::Dumper;

use Encode::DoubleEncodedUTF8;
use Encode qw(decode encode encode_utf8);

use FileHandle;
use Mojo::Util qw(slurp);
use Mojo::JSON qw(encode_json decode_json);
use MongoDB::MongoClient;


=head1

    Usage example:

    perl mongodbFoldersUmlautsConversion.pl 5671244606b2af0d90020000  /your/path/to/PhaidraBagger.json

=cut

my $configpath;
my $objectId;

if( not defined $ARGV[0]){
         print "Please enter malformated objectId as first parameter"; 
         return undef;
}else{
      $objectId = $ARGV[0];
}

if( not defined $ARGV[1]){
        $configpath = '/home/michal/Documents/code/area42/user/mf/angularjs/bagger/bagger/PhaidraBagger.json'; 
}else{
        $configpath = $ARGV[1];
}

unless(-r $configpath){
        say "Error: cannot access config: $configpath";
        return undef;
}

my $bytes = slurp $configpath;  
my $config = decode_json($bytes);

my $client     = MongoDB::MongoClient->new(
                                            host => $config->{mongodb}->{host}, 
                                            port => $config->{mongodb}->{port},
                                            password => $config->{mongodb}->{password},
                                            username => $config->{mongodb}->{username}
                                          );
my $database   = $client->get_database( $config->{mongodb}->{database} );
my $collection = $database->get_collection( 'folders' );

   
my $id = MongoDB::OID->new(value => $objectId);
my $dataset = $collection->find({ '_id' => $id });
    
while (my $doc = $dataset->next) {

        my $fixedName = decode("utf-8-de", $doc->{name}); 
        utf8::upgrade($fixedName);

        my $fixedPath = decode("utf-8-de", $doc->{path});
        utf8::upgrade($fixedPath);

        $collection->update({"_id" => $doc->{'_id'}}, {'$set' => {
                                                                  'name'     => $fixedName, 
                                                                  'path'      => $fixedPath
                                                                 }});
}

1;