package PhaidraBagger::Controller::Template;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';


sub uwmetadata_template_editor {
    my $self = shift;
    $self->stash(uwmetadataeditor_mode => 'template');
    my $init_data = { tid => $self->stash('tid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));  	 
    $self->render('uwmetadataeditor');	
}

sub load {
	
	my $self = shift;  	
	my $tid = $self->stash('tid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Loading template $tid");
	
	my $oid = Mango::BSON::ObjectID->new($tid);
	
	my $doc = $self->mango->db->collection('templates.uwmetadata')->find_one({_id => $oid}); 	
	
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
					    
	$self->app->log->info("[".$self->current_user->{username}."] Loaded template ".$doc->{title}." [$tid]");
	$self->render(
		json => { 
			uwmetadata => $doc->{uwmetadata}, 
			title => $doc->{title},
		}, 
		status => 200
	);		
		
}

sub save {
	
	my $self = shift;  	
	my $tid = $self->stash('tid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Saving template $tid");
	
	my $oid = Mango::BSON::ObjectID->new($tid);
	
	my $reply = $self->mango->db->collection('templates.uwmetadata')->update({_id => $oid},{ '$set' => {updated => time, uwmetadata => $self->req->json->{uwmetadata}} } );
	
	$self->render(json => { alerts => [] }, status => 200);

}

sub delete {
	
	my $self = shift;  	
	my $tid = $self->stash('tid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Removing template $tid");
	
	my $oid = Mango::BSON::ObjectID->new($tid);
	
	my $reply = $self->mango->db->collection('templates.uwmetadata')->remove({_id => $oid});
		
	$self->render(json => { alerts => [] }, status => 200);
}


sub create {
	my $self = shift;  
	
	my $res = { alerts => [], status => 200 };
	
	my $title = $self->req->json->{title};
	
	$self->app->log->info("[".$self->current_user->{username}."] Creating template ".$title);
	
	my $reply = $self->mango->db->collection('templates.uwmetadata')->insert({ title => $title, created => time, updated => time, project => $self->current_user->{project}, created_by => $self->current_user->{username}, uwmetadata => $self->req->json->{uwmetadata} } );
	
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

	my $coll = $self->mango->db->collection('templates.uwmetadata')
		->find({ created_by => $self->current_user->{username}})
		->sort({created => 1})
		->fields({ title => 1, created => 1, updated => 1, created_by => 1 })
		->all();
		
	unless(defined($coll)){
		my $err = $self->mango->db->command(bson_doc(getLastError => 1, w => 2));
	   	$self->app->log->info("[".$self->current_user->{username}."] Error searching templates: ".$self->app->dumper($err));
	   	$self->render(json => { alerts => [{ type => 'danger', msg => "Error searching templates" }] }, status => 500);	
	}
	
	my $collsize = scalar @{$coll};
	$self->render(json => { templates => $coll, alerts => [] , status => 200 });
}

sub load_difab {
	
	my $self = shift;  	
	my $tid = $self->stash('tid');
	
	$self->app->log->info("[".$self->current_user->{username}."] Loading template $tid");
	
	my $oid = Mango::BSON::ObjectID->new($tid);
	
	$self->render_later;
	my $reply = $self->mango->db->collection('templates.uwmetadata')->find_one(
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


1;
