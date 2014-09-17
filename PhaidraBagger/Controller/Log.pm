package PhaidraBagger::Controller::Log;

use strict;
use warnings;
use v5.10;
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

sub log {
    my $self = shift;
    my $init_data = { tid => $self->stash('tid'), current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));  	 
    $self->render('log');	
}

sub events {

  my $c = shift;

  # Change content type
  $c->res->headers->content_type('text/event-stream');

  # Subscribe to "message" event and forward "log" events to browser
  my $cb = $c->app->log->on(message => sub {
    my ($log, $level, @lines) = @_;
    $c->write("[$level] @lines\n\n");
  });

  # Unsubscribe from "message" event again once we are done
  $c->on(finish => sub {
    my $c = shift;
    $c->app->log->unsubscribe(message => $cb);
  });
  
}

1;
