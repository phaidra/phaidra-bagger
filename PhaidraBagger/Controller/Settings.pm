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

sub load {
	my $self = shift;

	my $project_settings;

	if($self->current_user->{role} eq 'manager'){
		$project_settings = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
		if($project_settings){
			$project_settings = $project_settings->{settings};
		}else{
			$project_settings = $self->config->{projects}->{$self->current_user->{project}};
		}
		$project_settings->{name} = $self->current_user->{project};
	}

	my $user_settings = $self->mango->db->collection('user.settings')->find_one({ username => $self->current_user->{username}, project => $self->current_user->{project}});

	# get user templates (default template settings)
	my $templates = $self->mango->db->collection('templates.uwmetadata')
		->find({ created_by => $self->current_user->{username} })
		->sort({ created => 1 })
		->fields({ title => 1, created => 1, updated => 1, created_by => 1 })
		->all();

    my $settings = {
    	project => $project_settings,
    	user => $user_settings->{settings},
    	templates => $templates,    	
    	members => $self->config->{projects}->{$self->current_user->{project}}->{members},
    	statuses => $self->config->{projects}->{$self->current_user->{project}}->{statuses}
    };


    $self->render(json => { alerts => [], settings => $settings }, status => 200);
}

sub settings {
	my $self = shift;

    my $init_data = {
    	navtitlelink => "settings",
    	navtitle => 'Settings',
    	current_user => $self->current_user,
    };

    $self->stash(
    	init_data => encode_json($init_data),
    	navtitlelink => "settings",
    	navtitle => 'Settings'
    );

    $self->render('settings');
}

sub save {
	my $self = shift;
	my $project_settings = $self->req->json->{project_settings};
	my $user_settings = $self->req->json->{user_settings};

	if($user_settings){
		$self->app->log->info("[".$self->current_user->{username}."] Saving settings of user ".$self->current_user->{username}." on project ".$self->current_user->{project});
		my $reply = $self->mango->db->collection('user.settings')->update({ username => $self->current_user->{username}, project => $self->current_user->{project}},{'$set' => { username => $self->current_user->{username}, project => $self->current_user->{project}, updated => time, settings => $user_settings}}, {upsert => 1});
	}

	if($self->current_user->{role} eq 'manager'){
		if($project_settings){
			$self->app->log->info("[".$self->current_user->{username}."] Saving settings of project ".$self->current_user->{project});
			my $reply = $self->mango->db->collection('project.settings')->update({ project => $self->current_user->{project}},{'$set' => { project => $self->current_user->{project}, updated => time, settings => $project_settings }}, {upsert => 1});
		}
	}

	$self->render(json => { alerts => [] }, status => 200);
}


1;
