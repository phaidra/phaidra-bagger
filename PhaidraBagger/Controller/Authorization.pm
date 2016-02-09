package PhaidraBagger::Controller::Authorization;

use strict;
use warnings;
use v5.10;
use Mojo::ByteStream qw(b);
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

# bridge
sub check {	
	my $self = shift;
	
	my $restricted_actions = $self->app->config->{projects}->{$self->current_user->{project}}->{restricted_actions};
	my $path = $self->req->url->path;
	my $method = $self->req->method;
	#$self->app->log->debug("$method $path");
	foreach my $op (@{$restricted_actions}){		
		if("$method $path" =~ $op){			
			unless($self->current_user->{role} eq 'manager'){
				$self->render(json => { alerts => [{ type => 'danger', msg => "You are not authorized for this operation" }] }, status => 403);
				return 0;	
			}
			last;
		}
	}
   
    return 1;
}

1;
