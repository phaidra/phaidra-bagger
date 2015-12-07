#!/usr/bin/env perl

=pod

=head1 fix_bag.pl -fix_5638_bag bagid -c config_path

  -fix_5638_bag bagid -c config_path

=cut

use v5.10;
use strict;
use warnings;
use Data::Dumper;
use Mango;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::UserAgent;
use Mojo::Util qw(slurp);
use Mojo::JSON qw(encode_json decode_json);
use Mojo::ByteStream qw(b);
use Scalar::Util 'refaddr';
use Mojo::Log;
use Switch;
use utf8;

my $configpath;
my $action;
my $oid;
my @bags;

while (defined (my $arg= shift (@ARGV)))
{
  if ($arg =~ /^-/)
  {
  	if ($arg eq '-fix_5638_bag') { $oid = shift (@ARGV); $action = 'fix_5638_bag'; }
  	elsif ($arg eq '-fix_5638_template') { $oid = shift (@ARGV); $action = 'fix_5638_template'; }
  	elsif ($arg eq '-resave_uwmetadata') { $oid = shift (@ARGV); $action = 'resave_uwmetadata'; }
  	elsif ($arg eq '-c') { $configpath = shift (@ARGV); }
	else { system ("perldoc '$0'"); exit (0); }
  }
}

unless(defined($configpath)){
	say "undefined config path"; 
	system ("perldoc '$0'"); 
	exit(0);
}

my $bytes = slurp $configpath;
my $config = decode_json($bytes);

my $log = Mojo::Log->new(path => $config->{'log'}->{path}, level => $config->{'log'}->{level});

unless(defined($oid)){
	$log->error("undefined object id"); 
	system ("perldoc '$0'"); 
	exit(0);
}

switch ($action) {
	case 'fix_5638_bag'	{		
		fix_5638('bag');
	}
	
	case 'fix_5638_template'	{
		fix_5638('template');
	}

	case 'resave_uwmetadata'	{
		my $ua = signin();
		resave_uwmetadata($ua);
	}

	else { print "unknown action\n"; system ("perldoc '$0'"); exit(0); }
}

exit(1);

###########

sub signin {

	my $url = Mojo::URL->new;
	$url->scheme('http');  
	$url->userinfo($config->{bagger_username}.":".$config->{bagger_password});
	my @base = split('/',$config->{bagger_baseurl});
	$url->host($base[0]);
	if(exists($base[1])){
	  $url->path($base[1]."/signin");
	}else{
	  $url->path("/signin");
	}

	my $ua = Mojo::UserAgent->new;
	my $tx = $ua->get($url); 

	if (my $res = $tx->success) {    
	  $log->info("[$oid] token ".$tx->res->json->{token});
	  $log->info("[$oid] cookies ".Dumper($ua->cookie_jar));
	  return $ua;
	}else {  
  	  $log->error("[$oid] Auth failed: ".Dumper($tx->error));        	  
	  exit(0);
	}
}

sub resave_uwmetadata {
	my $ua = shift;

	$log->info("[$oid] project: ".$config->{project});

	my $mango = Mango->new('mongodb://'.$config->{bagger_mongodb}->{username}.':'.$config->{bagger_mongodb}->{password}.'@'.$config->{bagger_mongodb}->{host}.'/'.$config->{bagger_mongodb}->{database});

	my $uwm;
	
	my $bag = $mango->db->collection('bags')->find_one({bagid => $oid, project => $config->{project}});

	if(defined($bag)){
		if($bag->{metadata}){
			if($bag->{metadata}->{uwmetadata}){
				$log->info("[$oid] uwmetadata found");
				$uwm = $bag->{metadata}->{uwmetadata};
			}else{
				$log->error("[$oid] no uwmetadata");
				exit(0);
			}
		}else{
			$log->error("[$oid] no metadata");
			exit(0);
		}
	}else{
		$log->error("[$oid] bag not found");
		exit(0);
	}
	
	
	unless($uwm){
		$log->error("[$oid] error loading uwmetadata");
		exit(0);
	}
	
	#$log->info("[$oid] \n ".Dumper($uwm));

	my $url = Mojo::URL->new;
	$url->scheme('http');  
	my @base = split('/',$config->{bagger_baseurl});
	$url->host($base[0]);
	if(exists($base[1])){
	  $url->path($base[1]."/bag/$oid/uwmetadata");
	}else{
	  $url->path("/bag/$oid/uwmetadata");
	}

#	my $json_str = b(encode_json($uwm))->decode('UTF-8');
	#my $ua = Mojo::UserAgent->new;

	my $tx = $ua->post($url, json => { uwmetadata => $uwm }); 
	 
	if (my $res = $tx->success) {    
	  $log->info("[$oid] saved");
	}else {        
	  if(defined($tx->res->json)){
	    if(exists($tx->res->json->{alerts})) {
	      $log->error("Error compressing uwmetadata: alerts: ".Dumper($tx->res->json->{alerts}));        
	    }else{
	      $log->error("Error compressing uwmetadata: json: ".Dumper($tx->res->json));        
	    }
	  }else{
	    $log->error("Error compressing uwmetadata: ".Dumper($tx->error));        
	  }
	  exit(0);
	}

	exit(1);
}

sub fix_5638 {
	my $type = shift;

	$log->info("[$oid] type: $type");
	$log->info("[$oid] project: ".$config->{project});

	my $mango = Mango->new('mongodb://'.$config->{bagger_mongodb}->{username}.':'.$config->{bagger_mongodb}->{password}.'@'.$config->{bagger_mongodb}->{host}.'/'.$config->{bagger_mongodb}->{database});

	my $uwm;
	if($type eq 'bag'){	
		my $bag = $mango->db->collection('bags')->find_one({bagid => $oid, project => $config->{project}});

		if(defined($bag)){
			if($bag->{metadata}){
				if($bag->{metadata}->{uwmetadata}){
					$log->info("[$oid] metadata found");
					$uwm = $bag->{metadata}->{uwmetadata};
				}else{
					$log->error("[$oid] no uwmetadata");
				}
			}else{
				$log->error("[$oid] no metadata");
			}
		}else{
			$log->error("[$oid] bag not found");
		}
	}
	
	if($type eq 'template'){
		
		my $bsonid = Mango::BSON::ObjectID->new($oid);	
		my $templ = $mango->db->collection('templates')->find_one({_id => $bsonid});

		if(defined($templ)){
			if($templ->{uwmetadata}){	
				$uwm = $templ->{uwmetadata};				
			}else{
				$log->error("[$oid] no uwmetadata");
			}
		}else{
			$log->error("[$oid] template not found");
		}
	}
	
	unless($uwm){
		$log->error("[$oid] error loading uwmetadata");
		exit(0);
	}
	
	#$log->info("[$oid] \n ".Dumper($uwm));
	
	#$uwm
	my $error_found = 1;
	my $cnt = 0;
	my $dirty = 0;
	while($error_found){
		$cnt++;
		if($cnt > 200){
			$log->error("[$oid] [$cnt] iteration limit reached");
			exit(0);
		}
		
		$error_found = 0;
		my ($err_opa, $err_parent, $err_parent_idx, $err_child, $err_child_idx);
		($error_found, $err_opa, $err_parent, $err_parent_idx, $err_child, $err_child_idx) = find_node_with_hierarchy_error(undef, 0, undef, $uwm);
		
		if($error_found){
			$dirty = 1;
			
			$log->info("[$oid] [$cnt] found error");
			#$log->info("[$oid] [$cnt] opa \n:".Dumper($err_opa)); 
			$log->info("[$oid] [$cnt] opa: xmlname=".$err_opa->{xmlname}." xmlns=".$err_opa->{xmlns});
			$log->info("[$oid] [$cnt] parent: xmlname=".$err_parent->{xmlname}." xmlns=".$err_parent->{xmlns}." children=".scalar @{$err_parent->{children}});
			$log->info("[$oid] [$cnt] child: xmlname=".$err_child->{xmlname}." xmlns=".$err_child->{xmlns}." children=".scalar @{$err_child->{children}});
			$log->info("[$oid] [$cnt] parent_idx=".$err_parent_idx." child_idx=".$err_child_idx);
							
			# insert the child after the parent in opa array
			splice $err_opa->{children}, $err_parent_idx, 0, $err_child;
			
			# remove the child from the parent children field
			splice $err_parent->{children}, $err_child_idx, 1;			
						
			#$log->info("[$oid] fixed, opa: \n".Dumper($uwm));
			
		}
	}
	
	$log->info("[$oid] fixing dates");	
	$error_found = 1;
	my $cnt2 = 0;	
	while($error_found){
		$error_found = 0;
		$cnt2++;
		if($cnt2 > 200){
			$log->error("[$oid] [$cnt] iteration limit reached");
			exit(0);
		}				
		$error_found = get_and_fix_node_with_wrong_date($uwm);	
	}
		
	# set defaults
	$log->info("[$oid] setting defaults");
	set_json_node_ui_value('http://phaidra.univie.ac.at/XML/metadata/lom/V1.0','language', $uwm, 'xx');
	set_json_node_ui_value('http://phaidra.univie.ac.at/XML/metadata/lom/V1.0','status', $uwm, 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_2/44');
	set_json_node_ui_value('http://phaidra.univie.ac.at/XML/metadata/lom/V1.0','cost', $uwm, '0');
	set_json_node_ui_value('http://phaidra.univie.ac.at/XML/metadata/lom/V1.0','copyright', $uwm, '1');
	
	#if($dirty){
		$log->info("[$oid] [$cnt] done, saving changes");
		
		if($type eq 'bag'){	
			$mango->db->collection('bags')->update({bagid => $oid},{'$set' => {updated => time, 'metadata.uwmetadata' => $uwm}});
		}
		
		if($type eq 'template'){		
			my $bsonid = Mango::BSON::ObjectID->new($oid);	
			$mango->db->collection('templates')->update({_id => $bsonid},{'$set' => {updated => time, uwmetadata => $uwm}});	
		}	
	#}else{
	#	$log->info("[$oid] [$cnt] done, no changes to save");
	#}
	
	exit(1);
}

# find nodes which have a child node of the same type as parent (eg entity as a child of entity)
sub find_node_with_hierarchy_error {
	my ($opa, $parent_idx, $parent, $children) = @_;

	my $child = undef;
	my $idx=0;
	
	foreach my $n (@{$children}){		
		if(defined($parent)){
			#$log->info($n->{xmlname} ." --- ". $parent->{xmlname});
			if($n->{xmlns} eq $parent->{xmlns} && $n->{xmlname} eq $parent->{xmlname}){
				#$log->info("FOUND!!");
				return (1, $opa, $parent, $parent_idx, $n, $idx);
			}
		}
		
		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		if($children_size > 0){
			my ($found_error, $r_opa, $r_parent, $r_parent_idx, $r_n, $r_idx) = find_node_with_hierarchy_error($parent, $idx, $n, $n->{children});
			if($found_error){
				return ($found_error, $r_opa, $r_parent, $r_parent_idx, $r_n, $r_idx);
			}			
		}
		
		$idx++;				
	}
	
}

sub get_and_fix_node_with_wrong_date {
	
	my $metadata = shift;
	
	my $ret = 0;
	foreach my $n (@{$metadata}){
		
		if(
		( 
			($n->{xmlns} eq 'http://phaidra.univie.ac.at/XML/metadata/provenience/V1.0' && $n->{xmlname} eq 'date_from') || 
			($n->{xmlns} eq 'http://phaidra.univie.ac.at/XML/metadata/provenience/V1.0' && $n->{xmlname} eq 'date_to')
		) && (length $n->{ui_value} == 3)
		){			
			$log->info("[$oid] node with wrong date found ".$n->{ui_value});
			$ret = 1;
			$n->{ui_value} = '0'.$n->{ui_value};
			last;
		}else{
			my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
			if($children_size > 0){
				$ret = get_and_fix_node_with_wrong_date($n->{children});
				last if($ret);
			}
		}
	}
	return $ret;
}

sub get_json_node {
	my ($namespace, $xmlname, $metadata) = @_;

	my $ret;
	foreach my $n (@{$metadata}){
		if($n->{xmlns} eq $namespace && $n->{xmlname} eq $xmlname){
			$ret = $n;
			last;
		}else{
			my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
			if($children_size > 0){
				$ret = get_json_node($namespace, $xmlname, $n->{children});
				last if($ret);
			}
		}
	}
	return $ret;
}

sub set_json_node_ui_value {
	my ($namespace, $xmlname, $metadata, $value) = @_;
	my $n = get_json_node($namespace, $xmlname, $metadata);
	if($n){
		$n->{'ui_value'} = $value;
	}
}
