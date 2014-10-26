package PhaidraBagger::Controller::Settings;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mango::BSON::Time;
use Mango::BSON::Document;
use Time::Local;
use Date::Parse qw(str2time);
use Mojo::JSON qw(encode_json);
use base 'Mojolicious::Controller';

sub settings {
	my $self = shift;

	my $project_settings;
	
	if($self->current_user->{role} eq 'manager'){
		$project_settings = $self->mango->db->collection('project.settings')->find_one({ username => $self->current_user->{username}, project => $self->current_user->{project}});		
		unless($project_settings){
			$project_settings = $self->config->{projects}->{$self->current_user->{project}};	
		}
	}			    
	
	my $user_settings = $self->mango->db->collection('user.settings')->find_one({ username => $self->current_user->{username}, project => $self->current_user->{project}});
			    
    my $init_data = { 
    	project_settings => $project_settings,
    	user_settings => $user_settings,
    	navtitlelink => "settings", 
    	navtitle => 'Settings', 
    	current_user => $self->current_user,
    	members => $self->config->{projects}->{$self->current_user->{project}}->{members}, 
    	statuses => $self->config->{projects}->{$self->current_user->{project}}->{statuses} 
    };
    
    $self->stash(
    	init_data => encode_json($init_data), 
    	navtitlelink => "settings", 
    	navtitle => 'Settings'
    );
      	 
    $self->render('settings');			
}

sub user_save {	
	my $self = shift;  	
	my $project_settings = $self->req->json->{project_settings};
	my $user_settings = $self->req->json->{user_settings};
	
	if($user_settings){
		$self->app->log->info("[".$self->current_user->{username}."] Saving settings of user ".$self->current_user->{username}." on project ".$self->current_user->{project});	
		my $reply = $self->mango->db->collection('user.settings')->update({ username => $self->current_user->{username}, project => $self->current_user->{project}},{'$set' => { username => $self->current_user->{username}, project => $self->current_user->{project}, updated => time, settings => $user_settings}}, {upsert => 1});	
	}
	
	if($project_settings){
		$self->app->log->info("[".$self->current_user->{username}."] Saving settings of project ".$self->current_user->{project});	
		my $reply = $self->mango->db->collection('project.settings')->update({ project => $self->current_user->{project}},{'$set' => { project => $self->current_user->{project}, updated => time, settings => $project_settings }}, {upsert => 1});	
	}
	
	$self->render(json => { alerts => [] }, status => 200);
}


1;
