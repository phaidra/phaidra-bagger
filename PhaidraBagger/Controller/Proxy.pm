package PhaidraBagger::Controller::Proxy;

use strict;
use warnings;
use v5.10;
use PhaidraBagger::Model::Cache;
use base 'Mojolicious::Controller';

sub get_object_uwmetadata {
	
	my $self = shift;  	
	my $pid = $self->stash('pid');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');		
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/object/$pid/uwmetadata");
	}else{
		$url->path("/object/$pid/uwmetadata");
	}
	$url->query({mfv => $self->app->config->{phaidra}->{metadata_format_version}});
	
	my $token = $self->load_token;	
	
  	$self->ua->get($url => {$self->app->config->{authentication}->{token_header} => $token} => sub { 	
  		my ($ua, $tx) = @_;

	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;
		 	if($tx->res->json){	  
			  	if(exists($tx->res->json->{alerts})) {
				 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
				 }else{
				  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
				 }
		 	}
		}
		
  	});

}

sub generate_object_uwmetadata {
	
	my $self = shift;  	
	my $pid = $self->stash('pid');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/object/$pid/uwmetadata");
	}else{
		$url->path("/object/$pid/uwmetadata");
	}
		
	$url->query({mfv => $self->app->config->{phaidra}->{metadata_format_version}});
	
	my $token = $self->load_token;
	
  	$self->ua->post($url => {$self->app->config->{authentication}->{token_header} => $token},
  		json => $self->req->json,
  	 	sub { 	
	  		my ($ua, $tx) = @_;
	
		  	if (my $res = $tx->success) {
		  		$self->render(json => $res->json, status => 200 );
		  	}else {
			 	my ($err, $code) = $tx->error;	 
			 	if(exists($tx->res->json->{alerts})) {
			 		$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 	}else{
			  		$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 	}
			}		
  		}
  	);

}


sub get_uwmetadata_tree {
	my $self = shift;  
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');	
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/uwmetadata/tree");
	}else{
		$url->path("/uwmetadata/tree");
	}
	$url->query({mfv => $self->app->config->{phaidra}->{metadata_format_version}});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}

sub get_uwmetadata_languages {
	my $self = shift;  
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');		
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/languages");
	}else{
		$url->path("/languages");
	}
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}
	
sub get_help_tooltip {
	my $self = shift;  
	
	my $id = $self->param('id');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');		
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/help/tooltip");
	}else{
		$url->path("/help/tooltip");
	}
	
	$url->query({id => $id});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}		
	
sub get_directory_get_org_units {
	my $self = shift;  
	
	my $parent_id = $self->param('parent_id');
	my $values_namespace = $self->param('values_namespace');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');	
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/directory/get_org_units");
	}else{
		$url->path("/directory/get_org_units");
	}
	$url->query({parent_id => $parent_id, values_namespace => $values_namespace});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}		
  	});
}

sub get_directory_get_study {
	my $self = shift;  
	
	my $spl = $self->param('spl');
	my @ids = $self->param('ids');
	my $values_namespace = $self->param('values_namespace');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');	
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/directory/get_study");
	}else{
		$url->path("/directory/get_study");
	}
	
	$url->query({spl => $spl, ids => \@ids, values_namespace => $values_namespace});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
	
}
sub get_directory_get_study_name {
	my $self = shift;  
	
	my $spl = $self->param('spl');
	my @ids = $self->param('ids');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');	
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/directory/get_study_name");
	}else{
		$url->path("/directory/get_study_name");
	}
	$url->query({spl => $spl, ids => @ids});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}  	

sub get_terms_children {
	my $self = shift;  
	
	my $uri = $self->param('uri');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');		
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/terms/children");
	}else{
		$url->path("/terms/children");
	}
	
	$url->query({uri => $uri});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}		

sub get_taxonpath {
	my $self = shift;  
	
	my $uri = $self->param('uri');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');		
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/terms/taxonpath");
	}else{
		$url->path("/terms/taxonpath");
	}
	
	$url->query({uri => $uri});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}

sub get_search {
	my $self = shift;  
	
	my $q = $self->param('q');
	
	my $res = { alerts => [], status => 200 };
	
	my $url = Mojo::URL->new;
	$url->scheme('https');		
	my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
	$url->host($base[0]);
	if(exists($base[1])){
		$url->path($base[1]."/terms/search");
	}else{
		$url->path("/terms/search");
	}
	
	$url->query({q => $q});
		
  	$self->ua->get($url => sub { 	
  		my ($ua, $tx) = @_;
	  	if (my $res = $tx->success) {
	  		$self->render(json => $res->json, status => 200 );
	  	}else {
		 	my ($err, $code) = $tx->error;	  
		  	if(exists($tx->res->json->{alerts})) {
			 	$self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
			 }else{
			  	$self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
			 }
		}
		
  	});
}			

sub get_terms_label {	
	my $self = shift;  
	my $cache_model = PhaidraBagger::Model::Cache->new;
    my $res = $cache_model->get_terms_label($self, $self->param('uri'));
	$self->render(json => $res, status => $res->{status});
}
	

1;
