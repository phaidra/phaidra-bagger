package PhaidraBagger::Controller::Template;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(decode_json encode_json);
use Storable qw(dclone);
use base 'Mojolicious::Controller';


sub uwmetadata_template_editor {
    my $self = shift;
    my $init_data = { tid => $self->stash('tid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));
    $self->render('templates/uwmetadata/edit');
}

sub mods_template_editor {
    my $self = shift;
    my $init_data = { tid => $self->stash('tid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));
    $self->render('templates/mods/edit');
}

sub load {

	my $self = shift;
	my $tid = $self->stash('tid');

	$self->app->log->info("[".$self->current_user->{username}."] Loading template $tid");

	my $oid = Mango::BSON::ObjectID->new($tid);

	my $doc = $self->mango->db->collection('templates')->find_one({_id => $oid});

	unless(defined($doc)){
		$self->app->log->error("[".$self->current_user->{username}."] Error loading template ".$tid);
		$self->render(
			json => {
			uwmetadata => '',
			title => '',
			alerts => [{ type => 'danger', msg => "Template with id ".$tid." was not found" }]
			},
		status => 500);
		return;
	}

	if($doc->{uwmetadata}){
		$self->reset_hide_rec($doc->{uwmetadata});
		
		$self->app->log->info("[".$self->current_user->{username}."] Loaded uwmetadata template ".$doc->{title}." [$tid]");
		$self->render(
			json => {
				uwmetadata => $doc->{uwmetadata},			
				title => $doc->{title},
			},
			status => 200
		);
		return;
	}	
	
	if($doc->{mods}){
		my $cache_model = PhaidraBagger::Model::Cache->new;
		my $res = $cache_model->get_mods_tree($self);
		my $mods_tree = $res->{tree};		 			
		$self->mods_fill_tree($doc->{mods}, $mods_tree);
		
		$self->app->log->info("[".$self->current_user->{username}."] Loaded uwmetadata template ".$doc->{title}." [$tid]");
		$self->render(
			json => {
				mods => $mods_tree,
				vocabularies => $res->{vocabularies},
				vocabularies_mapping => $res->{vocabularies_mapping},
				languages => $res->{languages},
				title => $doc->{title},
			},
			status => 200
		);	
		return;	
	}

}

# everything in a template should be visible
sub reset_hide_rec {
	my $self = shift;
	my $children = shift;
	
	foreach my $n (@{$children}){		
		if($n->{hide}){
			$n->{hide} = 0;
		}				
		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		if($children_size > 0){		
			$self->reset_hide_rec($n->{children});						
		}		
	}	
}

sub toggle_shared {	
	my $self = shift;
	my $tid = $self->stash('tid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Toggle shared on template $tid");

	my $oid = Mango::BSON::ObjectID->new($tid);

	my $t = $self->mango->db->collection('templates')->find_one({_id => $oid}, {shared => 1, created_by => 1});
	
	if($t->{created_by} ne $self->current_user->{username}){
		$self->app->log->error("[".$self->current_user->{username}."] Cannot toggle shared: User is not the owner of the template ".$tid);
		$self->render(
			json => {
				alerts => [{ type => 'danger', msg => "User ".$self->current_user->{username}." is not the owner of the template $tid" }]
			},
		status => 400);
		return;
	}
	
	my $shared;
	if($t->{shared}){
		$shared = Mojo::JSON->false;
	}else{
		$shared = Mojo::JSON->true;
	}
	$self->mango->db->collection('templates')->update({_id => $oid},{ '$set' => {shared => $shared} } );

	$self->render(json => { alerts => [] }, status => 200);		
}

sub save {

	my $self = shift;
	my $tid = $self->stash('tid');

	$self->app->log->info("[".$self->current_user->{username}."] Saving template $tid");

	my $oid = Mango::BSON::ObjectID->new($tid);

	if($self->req->json->{uwmetadata}){
		my $reply = $self->mango->db->collection('templates')->update({_id => $oid},{ '$set' => {updated => time, uwmetadata => $self->req->json->{uwmetadata}} } );
	}
	if($self->req->json->{mods}){
		my $mods = $self->mods_strip_empty_nodes($self->req->json->{mods});		
		my $reply = $self->mango->db->collection('templates')->update({_id => $oid},{ '$set' => {updated => time, mods => $mods} } );
	}

	$self->render(json => { alerts => [] }, status => 200);
}

sub mods_strip_empty_nodes {
	my $self = shift;
	my $children = shift;
	
	for my $i ( 0 .. $#$children ) {
 
		my $node = @{$children}[$i];
		
		# remove children if there are no values in the subtree
		my $children_size = defined($node->{children}) ? scalar (@{$node->{children}}) : 0;
		if($children_size > 0){		
			$self->mods_strip_empty_nodes($node->{children});
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

sub create_mods_nodes_hash {

	my $self = shift;
	my $children = shift;
	my $h = shift;
	my $parent_path = shift;

	foreach my $n (@{$children}){

		my $path = ($parent_path eq '' ? '' : $parent_path.'_').$n->{xmlname};
		
		$h->{$path} = $n;

		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		if($children_size > 0){
			$self->create_mods_nodes_hash($n->{children}, $h, $path);
		}

	}

}

sub mods_fill_tree {
	my $self = shift;
	my $mods = shift;
	my $tree = shift;
	my $path = shift;
	
	my %mods_nodes_hash;
	my $tree_copy = dclone($tree);
	
	$self->create_mods_nodes_hash($tree_copy, \%mods_nodes_hash, '');
	
	$self->mods_fill_tree_rec($mods, $tree, \%mods_nodes_hash, '');
	
}

sub mods_fill_tree_rec {	
	my $self = shift;
	my $read_children = shift;	
	my $mods_tree = shift;
	my $mods_nodes_hash = shift;
	my $path = shift;
	
	foreach my $n (@{$read_children}){
		
		my $child_path = ($path eq '' ? '' : $path.'_').$n->{xmlname};
		
		# this gives as an empty node to fill (it adds new one if needed)
		# it also keeps recursion in $mods/$children, which we read, in sync with $mods_tree, which we are writing to 
		my $current_mods_tree_node = $self->mods_get_emtpy_tree_node($child_path, $mods_tree, '', $mods_nodes_hash);
		
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
			$self->mods_fill_tree_rec($n->{children}, $mods_tree, $mods_nodes_hash, $child_path);
		}
	}
		
}

sub mods_get_emtpy_tree_node {
	my ($self, $search_path, $mods_tree, $mods_tree_path, $mods_nodes_hash) = @_;
	
	my $node;
	my $i = 0;	
	
	foreach my $n (@{$mods_tree}){
		my $children_size = defined($n->{children}) ? scalar (@{$n->{children}}) : 0;
		my $curr_path = ($mods_tree_path eq '' ? '' : $mods_tree_path.'_').$n->{xmlname};
		if($curr_path eq $search_path){
			# we have found the node we are searching for, is it empty?
			if(defined($n->{ui_value}) && $n->{ui_value} ne ''){
				# it's not, add new node
				my $new_node = dclone($mods_nodes_hash->{$search_path});
				splice @{$mods_tree}, $i, 0, $new_node;
				
				$node = $new_node;
			}else{
				$node = $n;
			}
		
		}elsif($children_size > 0){
			$node = $self->mods_get_emtpy_tree_node($search_path, $n->{children}, $curr_path, $mods_nodes_hash);			
		}
		
		$i++;
		
		last if defined $node;
	}
	return $node;
}

sub delete {

	my $self = shift;
	my $tid = $self->stash('tid');

	$self->app->log->info("[".$self->current_user->{username}."] Removing template $tid");

	my $oid = Mango::BSON::ObjectID->new($tid);

	my $reply = $self->mango->db->collection('templates')->remove({_id => $oid});

	$self->render(json => { alerts => [] }, status => 200);
}


sub create {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $title = $self->req->json->{title};

	$self->app->log->info("[".$self->current_user->{username}."] Creating template ".$title);

	my $reply;
	if($self->req->json->{uwmetadata}){
		$self->app->log->info("[".$self->current_user->{username}."] saving uwmetadata");
		$reply = $self->mango->db->collection('templates')->insert({ title => $title, created => time, updated => time, project => $self->current_user->{project}, created_by => $self->current_user->{username}, uwmetadata => $self->req->json->{uwmetadata} } );
	}
	elsif($self->req->json->{mods}){
		$self->app->log->info("[".$self->current_user->{username}."] saving mods");	
		my $mods = $self->mods_strip_empty_nodes($self->req->json->{mods});		
		$reply = $self->mango->db->collection('templates')->insert({ title => $title, created => time, updated => time, project => $self->current_user->{project}, created_by => $self->current_user->{username}, mods => $mods } );
	}
	
	$self->render(json => { alerts => [{ type => 'danger', msg => "Saving template $title failed" }] }, status => 500)
		unless($reply);

	my $oid = $reply->{oid};
	if($oid){
		$self->app->log->info("[".$self->current_user->{username}."] Created template ".$title." [$oid]");
		$self->render(json => { tid => "$oid", alerts => [{ type => 'success', msg => "Template $title created" }] }, status => 200);
	}else{
		$self->render(json => { alerts => [{ type => 'danger', msg => "Saving template $title failed" }] }, status => 500);
	}
}

sub templates {
    my $self = shift;

	my $init_data = { current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));

	$self->render('templates/list');
}

sub my {
    my $self = shift;

    $self->render_later;

	my $uwcoll = $self->mango->db->collection('templates')
		->find(
			{ 
			uwmetadata => {'$exists' => Mojo::JSON->true},	
			'$or' => 
				[ 
					{ project => $self->current_user->{project}, created_by => $self->current_user->{username} }, 					 
					{ project => $self->current_user->{project}, shared => Mojo::JSON->true }
				]
			}
		)
		->sort({created => 1})
		->fields({ title => 1, created => 1, updated => 1, created_by => 1, shared => 1 , created_by => 1 })
		->all();

	my $modscoll = $self->mango->db->collection('templates')
		->find(
			{ 
				mods => {'$exists' => Mojo::JSON->true},
				'$or' => 
				[ 
					{ project => $self->current_user->{project}, created_by => $self->current_user->{username} }, 					 
					{ project => $self->current_user->{project}, shared => Mojo::JSON->true }
				]
			}
		)
		->sort({created => 1})
		->fields({ title => 1, created => 1, updated => 1, created_by => 1, shared => 1 , created_by => 1 })
		->all();

	if(!defined($uwcoll) && !defined($modscoll)){
		my $err = $self->mango->db->command(bson_doc(getLastError => 1, w => 2));
	   	$self->app->log->info("[".$self->current_user->{username}."] Error searching templates: ".$self->app->dumper($err));
	   	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching templates" }] }, status => 500);
	}

	my @coll = ();
	foreach my $d (@{$uwcoll}){
		$d->{type} = 'uwmetadata';
		push @coll, $d;
	}
	foreach my $d (@{$modscoll}){
		$d->{type} = 'mods';
		push @coll, $d;
	}

	$self->render(json => { templates => \@coll, alerts => [] , status => 200 });
}

=cut
sub load_difab {

	my $self = shift;
	my $tid = $self->stash('tid');

	$self->app->log->info("[".$self->current_user->{username}."] Loading template $tid");

	my $oid = Mango::BSON::ObjectID->new($tid);

	$self->render_later;
	my $reply = $self->mango->db->collection('templates')->find_one(
		{_id => $oid} =>
			sub {
				    my ($reply, $error, $doc) = @_;

				    if ( $error ){
				    	$self->app->log->error("[".$self->current_user->{username}."] Error loading template ".$tid.":".$self->app->dumper($error));
						$self->render(
								json => {
									uwmetadata => '',
									title => '',
									alerts => [{ type => 'danger', msg => "Template with id ".$tid." was not found" }]
								},
						status => 500);
				    }

				    $self->app->log->info("[".$self->current_user->{username}."] Loaded template ".$doc->{title}." [$tid]");

				    my $uwmetadata = $doc->{uwmetadata};

				    $self->difab_filter($uwmetadata, 0, 0);

					$self->render(
							json => {
								uwmetadata => $uwmetadata,
								title => $doc->{title},
								#alerts => [{ type => 'success', msg => "Template ".$doc->{title}." loaded" }]
							},
					status => 200);

				}
	);

}


my %filter = (

	# mandatory
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#general" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#identifier" => { default => undef, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#title" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#language" => { default => "xx", included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#description" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#lifecycle" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#upload_date" => { default => undef, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#status" => { default => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_2/44", included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#contribute" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#role" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#entity" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity#firstname" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity#lastname" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/entity#institution" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#rights" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#cost" => { default => 0, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#copyright" => { default => 1, included => 0},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#license" => { default => "http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/voc_21/12"},

	# difab wanted
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#alt_title" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/lom/V1.0#keyword" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#histkult" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#dimensions" => { default => undef, included_children => 1 },
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#reference_number" => { default => undef, included_children => 1 },
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#inscription" => { default => undef, value_lang => 'bg'},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#note" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/histkult/V1.0#gps" => { default => undef},
	"http://phaidra.univie.ac.at/XML/metadata/provenience/V1.0#provenience" => { default => undef, included_children => 1},
	"http://phaidra.univie.ac.at/XML/metadata/provenience/V1.0#location" => { default => undef},

);


sub difab_filter(){

	my $self = shift;
	my $children = shift;
	my $included_children = shift;
	my $set_default = shift;

	foreach my $child (@{$children}){

		my $children_size = defined($child->{children}) ? scalar (@{$child->{children}}) : 0;

		my $chid = $child->{xmlns}."#".$child->{xmlname};

		#$self->app->log->debug("checking $chid");

		my $def = $filter{$chid};
		if(defined($def)){

			#$self->app->log->debug("def found ".$self->app->dumper($def));

			# included
			if(defined($def->{included})){
				$child->{included} = $def->{included};
			}else{
				$child->{included} = 1;
			}

			if($set_default){
				# default
				if(defined($def->{default})){
					$child->{ui_value} = $def->{default};
				}
				# value_lang
				if(defined($def->{value_lang})){
					$child->{value_lang} = $def->{value_lang};
				}

			}


		}else{
			# HACK rights>description has same xmlns & xmlname as general>description (WTAF)
			if($child->{help_id} eq "helpmeta_37"){
				$child->{included} = 0;
			}

			$child->{included} = $included_children ? 1 : 0;
		}

		if($children_size > 0){
			if(defined($def)){
				if(defined($def->{included_children})){
					$self->difab_filter($child->{children}, $def->{included_children}, $set_default);
					return;
				}
			}
			$self->difab_filter($child->{children}, $included_children, $set_default);
		}
	}

}
=cut

1;
