package PhaidraBagger::Model::Mods;

use strict;
use warnings;
use v5.10;
use Storable qw(dclone);
use base qw/Mojo::Base/;

sub mods_fill_tree {
	my $self = shift;
	my $c = shift;
	# what was saved in db
	my $mods = shift;
	# what we are filling with the saved values; this is what we return to frontend
	my $tree = shift;
	
	my %mods_nodes_hash;
	my $tree_copy = dclone($tree);
	
	$self->create_mods_nodes_hash($c, $tree_copy, \%mods_nodes_hash, '');
	
	$self->mods_fill_tree_rec($c, $mods, $tree, \%mods_nodes_hash, '');
	
	$self->unset_used_node_flag($c, $tree);
	
}

sub mods_fill_tree_rec {	
	my $self = shift;
	my $c = shift;
	my $read_children = shift;	
	my $mods_tree = shift;
	my $mods_nodes_hash = shift;
	my $path = shift;
	
	foreach my $n (@{$read_children}){
		
		my $child_path = ($path eq '' ? '' : $path.'_').$n->{xmlname};
		
		# this gives as an empty node to fill (it adds new one if needed)
		# it also keeps recursion in $mods/$children, which we read, in sync with $mods_tree, which we are writing to 
		my $current_mods_tree_node = $self->mods_get_emtpy_tree_node($c, $child_path, $mods_tree, '', $mods_nodes_hash);		
		
		if($current_mods_tree_node->{input_type} eq 'node'){
			$current_mods_tree_node->{used_node} = 1;	
		}
		
		if(defined($n->{ui_value}) && $n->{ui_value} ne ''){
			$current_mods_tree_node->{ui_value} = $n->{ui_value};
		}
				
		# copy attribute values 
		foreach my $n_a (@{$n->{attributes}}){
			if(defined($n_a->{ui_value}) && $n_a->{ui_value} ne ''){
				foreach my $c_a (@{$current_mods_tree_node->{attributes}}){
					if($n_a->{xmlname} eq $c_a->{xmlname}){
						$c_a->{ui_value} = $n_a->{ui_value};
					}
				}
			}				
		}
			
		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		if($children_size > 0){
			$self->mods_fill_tree_rec($c, $n->{children}, $mods_tree, $mods_nodes_hash, $child_path);
		}
		
	}
		
}


sub create_mods_nodes_hash {

	my $self = shift;
	my $c = shift;
	my $children = shift;
	my $h = shift;
	my $parent_path = shift;

	foreach my $n (@{$children}){

		my $path = ($parent_path eq '' ? '' : $parent_path.'_').$n->{xmlname};
		
		$h->{$path} = $n;

		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		if($children_size > 0){
			$self->create_mods_nodes_hash($c, $n->{children}, $h, $path);
		}

	}

}

sub unset_used_node_flag {

	my $self = shift;
	my $c = shift;
	my $children = shift;

	foreach my $n (@{$children}){
		$c->app->log->debug("XXXXXX un:".$n->{used_node});
		delete $n->{used_node} if exists $n->{used_node};

		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		if($children_size > 0){
			$self->unset_used_node_flag($c, $n->{children});
		}
	}
}

sub mods_get_emtpy_tree_node {
	my ($self, $c, $search_path, $mods_tree, $mods_tree_path, $mods_nodes_hash) = @_;
	
	my $node;
	my $i = 0;	
	
	foreach my $n (@{$mods_tree}){
		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		my $curr_path = ($mods_tree_path eq '' ? '' : $mods_tree_path.'_').$n->{xmlname};
		if($curr_path eq $search_path){
			# we have found the node we are searching for, is it empty?
			if( (defined($n->{ui_value}) && $n->{ui_value} ne '') || $n->{used_node}){
				# it's not, add new node
				my $new_node = dclone($mods_nodes_hash->{$search_path});
				splice @{$mods_tree}, $i, 0, $new_node;
				
				$node = $new_node;
			}else{
				$node = $n;
			}
		
		}elsif($children_size > 0){
			$node = $self->mods_get_emtpy_tree_node($c, $search_path, $n->{children}, $curr_path, $mods_nodes_hash);			
		}
		
		$i++;
		
		last if defined $node;
	}
	return $node;
}

sub mods_strip_empty_nodes {
	my $self = shift;
	my $c = shift;
	my $children = shift;
	
	for my $i ( 0 .. $#$children ) {
 
		my $node = @{$children}[$i];
		
		# remove children if there are no values in the subtree
		my $children_size = defined($node->{children}) ? scalar (@{$node->{children}}) : 0;
		if($children_size > 0){		
			$self->mods_strip_empty_nodes($c, $node->{children});
			my $children_size2 = defined($node->{children}) ? scalar (@{$node->{children}}) : 0;	
			if($children_size2 == 0){
				delete $node->{children};
			}					
		}else{
			if(exists($node->{children})){
				delete $node->{children};
			}
		} 		
		
		# remove empty attributes
		my $a = $node->{attributes};
		for my $j ( 0 .. $#$a ) {	
			if(!defined(@{$a}[$j]->{ui_value}) || @{$a}[$j]->{ui_value} eq ''){
				undef @{$a}[$j];
			}
		}
		@{$a} = grep{ defined }@{$a};
		if(scalar @{$a} > 0){
			$node->{attributes} = $a;
		}else{
			delete $node->{attributes};
		}
				
		if(!exists($node->{children}) && !exists($node->{attributes}) && (!defined($node->{ui_value}) || $node->{ui_value} eq '' )){
			# delete the node itself
			undef @{$children}[$i];
		}
			
	}	
	
	# remove undefined nodes
	@{$children} = grep{ defined }@{$children};
	
	return $children;	
}


1;
__END__
