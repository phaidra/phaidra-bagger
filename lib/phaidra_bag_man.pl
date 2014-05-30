#!/usr/bin/perl -w

=pod

=head1 phaidra_bag_man.pl -p bags_dir_path -l

  -p bags_dir_path
  -l - lists bags in the bag dirctory

=cut

use strict;
use warnings;
use Data::Dumper;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use PhaidraBagMan qw(list_bags print_bags);
use Switch;

my $bags_dir_path;
my $action;
my @bags;

while (defined (my $arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
  	   if ($arg eq '-p') { $bags_dir_path = shift (@ARGV); }
    elsif ($arg eq '-l') { $action = 'list' }
    else { system ("perldoc '$0'"); exit (0); }
  }
  else { push (@bags, $arg); }
}

unless(defined($bags_dir_path)){
	print "undefined bags_dir_path\n"; system ("perldoc '$0'"); exit(0);
}

switch ($action) {
	case 'list'	{ list_bags_dir(); }	
	else { print "undefined action\n"; system ("perldoc '$0'"); exit(0); }
}	

exit(1);

sub list_bags_dir {
	
	print_bags($bags_dir_path);
}
