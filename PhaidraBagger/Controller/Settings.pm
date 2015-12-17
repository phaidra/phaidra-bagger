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

		#if($project_settings->{included_classifications}){
		#	my %included_classifications_hash = map { $_ => 1 } @{$project_settings->{included_classifications}};
		#	$project_settings->{included_classifications} = \%included_classifications_hash;
		#}
	}

	my $user_settings = $self->mango->db->collection('user.settings')->find_one({ username => $self->current_user->{username}, project => $self->current_user->{project}});

	# get user templates (default template settings)
	my $templates = $self->mango->db->collection('templates')
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
        my $payload = $self->req->json;
        my $data = $payload->{'data'};  
        $self->app->log->debug('save data123:',$self->app->dumper($data));
        
        
        my $project_settings = $self->req->json->{project_settings};
        my $user_settings = $self->req->json->{user_settings};

        
        
        my $project_settings_mongo = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
        if(defined $data->{members_settings}){
                $project_settings_mongo->{settings}->{members} = $data->{members_settings}; 
        }
        $self->app->log->debug('project_settings_mongo1234:',$self->app->dumper($project_settings_mongo));
       
       
        
        
        
        if($user_settings){
                $self->app->log->info("[".$self->current_user->{username}."] Saving settings of user ".$self->current_user->{username}." on project ".$self->current_user->{project});

                my $reply = $self->mango->db->collection('user.settings')->update({ 
                                                                                    username => $self->current_user->{username}, 
                                                                                    project => $self->current_user->{project}},
                                                                                            {'$set' => { 
                                                                                                         username => $self->current_user->{username}, 
                                                                                                         project => $self->current_user->{project}, 
                                                                                                         updated => time, 
                                                                                                         settings => $user_settings
                                                                                                        }}, 
                                                                                                                  {upsert => 1}
                                                                                  );
        }

        if($self->current_user->{role} eq 'manager'){
                if($project_settings){
                        my @included_classifications_array;
                        foreach my $uri (keys %{$project_settings->{included_classifications}}){
                                # only if true
                                if($project_settings->{included_classifications}->{$uri}){
                                        push @included_classifications_array, $uri;
                                }
                        }
                        if(scalar @included_classifications_array > 0){
                                $project_settings->{included_classifications} = \@included_classifications_array;
                        }

                        $self->app->log->info("[".$self->current_user->{username}."] Saving settings of project ".$self->current_user->{project});
                        my $reply = $self->mango->db->collection('project.settings')->update({ project => $self->current_user->{project}},{'$set' => { 
                                                                                                              project => $self->current_user->{project}, 
                                                                                                              updated => time, 
                                                                                                              settings => $project_settings 
                                                                                                          } }, 
                                                                                                             {upsert => 1}
                                                                                            );

                        # rewrite the app config, the app config gets only refreshed on restart
                        if($project_settings){
                                $self->app->log->info("Rewriting db project config");
                                $self->config->{projects}->{$self->current_user->{project}} = $project_settings;
                        }
                }
        }

        $self->render(json => { alerts => [] }, status => 200);
}


sub save_old {
	my $self = shift;
	
	my $project_settings = $self->req->json->{project_settings};
	my $user_settings = $self->req->json->{user_settings};

	#my $project_settings_mongo = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
	#my $mongoSettingsForSaving = $self->($project_settings_mongo->{settings});
		
	if($user_settings){
		$self->app->log->info("[".$self->current_user->{username}."] Saving settings of user ".$self->current_user->{username}." on project ".$self->current_user->{project});

		my $reply = $self->mango->db->collection('user.settings')->update({ 
		                                                                    username => $self->current_user->{username}, 
		                                                                    project => $self->current_user->{project}},
		                                                                            {'$set' => { 
		                                                                                         username => $self->current_user->{username}, 
		                                                                                         project => $self->current_user->{project}, 
		                                                                                         updated => time, 
		                                                                                         settings => $user_settings
		                                                                                        }}, 
		                                                                                                  {upsert => 1}
		                                                                  );
	}

	if($self->current_user->{role} eq 'manager'){
		if($project_settings){
			my @included_classifications_array;
			foreach my $uri (keys %{$project_settings->{included_classifications}}){
				# only if true
				if($project_settings->{included_classifications}->{$uri}){
					push @included_classifications_array, $uri;
				}
			}
			if(scalar @included_classifications_array > 0){
				$project_settings->{included_classifications} = \@included_classifications_array;
			}

			$self->app->log->info("[".$self->current_user->{username}."] Saving settings of project ".$self->current_user->{project});
			my $reply = $self->mango->db->collection('project.settings')->update({ project => $self->current_user->{project}},{'$set' => { 
			                                                                                      project => $self->current_user->{project}, 
			                                                                                      updated => time, 
			                                                                                      settings => $project_settings 
			                                                                                  } }, 
			                                                                                     {upsert => 1}
			                                                                    );

			# rewrite the app config, the app config gets only refreshed on restart
			if($project_settings){
				$self->app->log->info("Rewriting db project config");
				$self->config->{projects}->{$self->current_user->{project}} = $project_settings;
			}
		}
	}

	$self->render(json => { alerts => [] }, status => 200);
}


1;
