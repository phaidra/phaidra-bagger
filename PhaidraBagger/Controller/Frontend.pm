package PhaidraBagger::Controller::Frontend;

use strict;
use warnings;
use v5.10;
use Mango 0.24;
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

sub home {
    my $self = shift;  	 
    
    unless($self->flash('redirect_to')){
    	# if no redirect was set, reload the current url
    	$self->flash({redirect_to => $self->req->url});
    }
    
    my $init_data = { current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));  

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

	$self->mango->db->collection('selections')->update({username => $username}, { username => $username, selection => $selection }, { upsert => 1 });

	$self->render(json => { alerts => [] }, status => 200);

}

sub get_selection {
	my $self = shift;  	 

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot load selection, current user is missing (the session might be expired)." }] }, status => 500);
		return;	
	}	

	my $res = $self->mango->db->collection('selections')->find_one({username => $username});

	$self->render(json => { selection => $res->{selection} }, status => 200);	
}

1;
