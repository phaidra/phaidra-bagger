#!/usr/bin/perl -w

package PhaidraBagMan;

use strict;
use warnings;
use Data::Dumper;
use File::Find;

our @ISA = ('Exporter');
our @EXPORT = ();
our @EXPORT_OK = qw(list_bags print_bags);

my %bags;

sub list_bags {
	my $path = shift;
	
	%bags = %{hashdir($path)};
	
	my @filter;

	# filter only bags
	foreach my $name (keys %bags){
		if($name eq '.'){
			push @filter, $name;
			print "'$name' is not a bag\n";
			next;
		}
		
		unless(defined($bags{$name}->{'.'})){
			push @filter, $name;
			print "'$name' is not a bag, missing bagit.txt\n";
			next;	
		}
		
		unless($bags{$name}->{'.'}[0] eq 'bagit.txt'){
			push @filter, $name;
			print "'$name' is not a bag, missing bagit.txt\n";
			next;	
		}
		
		unless(defined($bags{$name}->{'data'})){
			push @filter, $name;
			print "'$name' is not a bag, missing data\n";
			next;	
		}		
		
		unless(defined($bags{$name}->{'data'}->{'.'})){
			push @filter, $name;
			print "'$name' is not a bag, missing metadata.json\n";
			next;	
		}
		
		unless($bags{$name}->{'data'}->{'.'}[0] eq 'metadata.json'){
			push @filter, $name;
			print "'$name' is not a bag, missing metadata.json\n";
			next;	
		}
				
	}
	
	delete @bags{@filter};
	
	return \%bags;	
}

sub print_bags {
	my $path = shift;
	my $bags = list_bags($path);
	print Dumper($bags);
}

sub hashdir {
    my $dir = shift;
    opendir my $dh, $dir or die $!;
    my $tree = {}->{$dir} = {};
    while( my $file = readdir($dh) ) {
        next if $file =~ m[^\.{1,2}$];
        my $path = $dir .'/' . $file;
        $tree->{$file} = hashdir($path), next if -d $path;
        push @{$tree->{'.'}}, $file;
    }
    return $tree;
}

1;