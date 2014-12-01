package PhaidraBagger::Controller::Frontend;

use strict;
use warnings;
use v5.10;
use Mango 0.24;
use Mojo::JSON qw(encode_json);
use PhaidraBagger::Model::Cache;
use base 'Mojolicious::Controller';

sub chillin {
	my $self = shift;
	$self->render('chillin');
}

sub home {
    my $self = shift;

    unless($self->flash('redirect_to')){
    	# if no redirect was set, reload the current url
			$self->flash({redirect_to => $self->url_for('/')});
    }

    if($self->stash('opensignin')){
    	$self->flash({opensignin => 1});
    }

    my $init_data = { current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));
    $self->stash(init_data_perl => $init_data);

    $self->render('home');
}

sub post_selection {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot save selection, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my $payload = $self->req->json;
	my $selection = $payload->{selection};

	$self->mango->db->collection('user.selections')->update({username => $username}, { username => $username, selection => $selection }, { upsert => 1 });

	$self->render(json => { alerts => [] }, status => 200);

}

sub get_selection {
	my $self = shift;

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot load selection, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my $res = $self->mango->db->collection('user.selections')->find_one({username => $username});

	$self->render(json => { selection => $res->{selection} }, status => 200);
}

sub toggle_classification {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot add classification, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my $payload = $self->req->json;
	my $uri = $payload->{uri};

	my @uri = ($uri);
	my $cursor = $self->mango->db->collection('user.classifications')->find({ username => $username, classifications => {'$all' => \@uri } });
	my $hits = $cursor->count;

	if($hits > 0){
		$self->mango->db->collection('user.classifications')->update({username => $username}, { '$set' => {username => $username}, '$pullAll' => { classifications => \@uri } });
	}else{
		$self->mango->db->collection('user.classifications')->update({username => $username}, { '$set' => {username => $username}, '$addToSet' => { classifications => $uri } }, {upsert => 1});
	}

	$self->render(json => { alerts => [] }, status => 200);

}

sub get_classifications {
	my $self = shift;

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot load classifications, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my @clss;
	# project defined classifications
	my $r = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
	foreach my $uri (@{$r->{settings}->{classifications}}){
		my $class = $self->_resolve_class_uri($uri);
		$class->{type} = 'project';
		push @clss, $class;
	}

	# user defined classification
	$r = $self->mango->db->collection('user.classifications')->find_one({username => $username});
	foreach my $uri (@{$r->{classifications}}){
		my $class = $self->_resolve_class_uri($uri);
		$class->{type} = 'user';
		push @clss, $class;
	}
	#$self->app->log->debug($self->app->dumper(\@clss));
	$self->render(json => { classifications => \@clss }, status => 200);
}

sub _resolve_class_uri {
		my $self = shift;
		my $uri = shift;

		my $class;

		my $cache_model = PhaidraBagger::Model::Cache->new;

		# get taxon labels
		my $res = $cache_model->get_terms_label($self, $uri);
		if($res->{status} eq 200){
			$class = $res->{labels};
		}else{
			$self->app->log->error("Cannot get taxon labels: ".$self->app->dumper($res));
		}

		# get classification labels
		my $ns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification';
		$uri =~ m/($ns\/cls_\d+)\//;
		$res = $cache_model->get_terms_label($self, $1);
		if($res->{status} eq 200){
			$class->{classification} = $res->{labels};
		}else{
			$self->app->log->error("Cannot get classification labels: ".$self->app->dumper($res));
		}
		$class->{uri} = $uri;

		return $class;
}


1;
