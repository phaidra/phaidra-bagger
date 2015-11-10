package PhaidraBagger;

use strict;
use warnings;
use Mojo::Base 'Mojolicious';
use Mojo::Log;
use Mojolicious::Plugin::I18N;
use Mojolicious::Plugin::Authentication;
use Mojolicious::Plugin::Session;
use Mojo::Loader;
use lib "lib/phaidra_directory";
use PhaidraBagger::Model::Session::Store::Mongo;

$ENV{MOJO_MAX_MESSAGE_SIZE} = 1073741824;
$ENV{MOJO_INACTIVITY_TIMEOUT} = 600;
$ENV{MOJO_HEARTBEAT_TIMEOUT} = 600;

# This method will run once at server start
sub startup {
    my $self = shift;

    my $config = $self->plugin( 'JSONConfig' => { file => 'PhaidraBagger.json' } );
	$self->config($config);
	$self->mode($config->{mode});
    $self->secrets([$config->{secret}]);

    # init log
  	$self->log(Mojo::Log->new(path => $config->{log_path}, level => $config->{log_level}));
	#$self->log->debug("Config:\n".$self->app->dumper($self));

	# make config->{phaidra} point to default ingest instance, for quick access
	my $have_default_instance = 0;
	foreach my $k (%{$config->{ingest_instances}}){
		if(exists($config->{ingest_instances}->{$k})){
			if(exists($config->{ingest_instances}->{$k}->{is_default})){
				if($config->{ingest_instances}->{$k}->{is_default} eq '1'){
					$have_default_instance = 1;
					$config->{phaidra} = $config->{ingest_instances}->{$k};
					#$self->log->info("Default ingest instance: ".$self->dumper($config->{phaidra}));
				}
			}
		}
	}
	unless($have_default_instance){
		$self->log->error("Cannot find default ingest_instance");
	}

    # init auth
    $self->plugin(authentication => {
		load_user => sub {
			my $self = shift;
			my $username  = shift;

	 		my $login_data = $self->app->chi->get($username);

	    	unless($login_data){
	    		$self->app->log->debug("[cache miss] $username");

	    		my $login_data;

	    		my $url = Mojo::URL->new;
				$url->scheme('https');
				$url->userinfo($self->app->config->{directory_user}->{username}.":".$self->app->config->{directory_user}->{password});
				my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
				$url->host($base[0]);
				$url->path($base[1]."/directory/user/$username/data") if exists($base[1]);
			  	my $tx = $self->ua->get($url);

			 	if (my $res = $tx->success) {
			 		$login_data = $tx->res->json->{user_data};
				} else {
				 	my ($err, $code) = $tx->error;
				 	$self->app->log->error("Getting user data failed for user $username. Error code: $code, Error: ".$self->app->dumper($err));
				 	if($tx->res->json && exists($tx->res->json->{alerts})){
						$self->stash({phaidra_auth_result => { alerts => $tx->res->json->{alerts}, status  =>  $code ? $code : 500 }});
				 	}else{
						$self->stash({phaidra_auth_result => { alerts => [{ type => 'danger', msg => $err }], status  =>  $code ? $code : 500 }});
					}
				 	return undef;
				}

				foreach my $p (keys %{$self->app->config->{projects}}){
					foreach my $u (@{$self->app->config->{projects}->{$p}->{members}}){
						if($u->{username} eq $username){
							$login_data->{project} = $p;
							$login_data->{role} = $u->{role};
							$login_data->{displayname} = $u->{displayname};
						}
					}
				}

		        # rewrite project config with the one from db (if any is found)
		        my $project_settings = $self->mango->db->collection('project.settings')->find_one({project => $login_data->{project}});
		        if($project_settings){
		          $self->app->log->info("Loading db project config");
		          $project_settings->{name} = $login_data->{project};
		          $self->config->{projects}->{$login_data->{project}} = $project_settings->{settings};
		        }

				$self->app->log->info("Loaded user: ".$self->app->dumper($login_data));
	    		$self->app->chi->set($username, $login_data, '1 day');
	    		# keep this here, the set method may change the structure a bit so we better read it again
	    		$login_data = $self->app->chi->get($username);
	    	}else{
	    		$self->app->log->debug("[cache hit] $username");
	    	}

			return $login_data;
		},
		validate_user => sub {
			my ($self, $username, $password, $extradata) = @_;
			$self->app->log->info("Validating user: ".$username);

			# delete from cache
			$self->app->chi->remove($username);

			# if the user is not in configuration -> wiederschauen
			my $is_in_config = 0;
			foreach my $p (keys %{$self->app->config->{projects}}){
				foreach my $u (@{$self->app->config->{projects}->{$p}->{members}}){
					if($u->{username} eq $username){
						$is_in_config = 1; last;
					}
				}
			}
			unless ($is_in_config){
				$self->app->log->error("User $username not found in any project");
				return undef;
			}

			my $url = Mojo::URL->new;
			$url->scheme('https');
			$url->userinfo($username.":".$password);
			my @base = split('/',$self->app->config->{phaidra}->{apibaseurl});
			$url->host($base[0]);
			$url->path($base[1]."/signin") if exists($base[1]);
		  	my $tx = $self->ua->get($url);

		 	if (my $res = $tx->success) {

			  		# save token
			  		my $token = $tx->res->cookie($self->app->config->{authentication}->{token_cookie})->value;

			  		my $session = $self->stash('mojox-session');
					$session->load;
					unless($session->sid){
						$session->create;
					}
					$self->save_token($token);

			  		$self->app->log->info("User $username successfuly authenticated");
			  		$self->stash({phaidra_auth_result => { token => $token , alerts => $tx->res->json->{alerts}, status  =>  200 }});

			  		return $username;
			 }else {
				 	my ($err, $code) = $tx->error;
				 	$self->app->log->error("Authentication failed for user $username. Error code: $code, Error: ".$self->app->dumper($err));
				 	if($tx->res->json && exists($tx->res->json->{alerts})){
						$self->stash({phaidra_auth_result => { alerts => $tx->res->json->{alerts}, status  =>  $code ? $code : 500 }});
				 	}else{
						$self->stash({phaidra_auth_result => { alerts => [{ type => 'danger', msg => $err }], status  =>  $code ? $code : 500 }});
					}

				 	return undef;
			}

		},
	});

	$self->attr(_mango => sub { return Mango->new('mongodb://'.$config->{mongodb}->{username}.':'.$config->{mongodb}->{password}.'@'.$config->{mongodb}->{host}.'/'.$config->{mongodb}->{database}) });
	$self->helper(mango => sub { return shift->app->_mango});

	#$self->attr(_mango_local => sub { return Mango->new('mongodb://'.$config->{mongodb_local}->{username}.':'.$config->{mongodb_local}->{password}.'@'.$config->{mongodb_local}->{host}.'/'.$config->{mongodb_local}->{database}) });
        #$self->helper(mango_local => sub { return shift->app->_mango_local});
	
    # we might possibly save a lot of data to session
    # so we are not going to use cookies, but a database instead
    $self->plugin(
        session => {
                        stash_key     => 'mojox-session',
                        store  => PhaidraBagger::Model::Session::Store::Mongo->new(
                                mango => $self->mango,
                                'log' => $self->log
                        ),
                        transport => MojoX::Session::Transport::Cookie->new(name => 'b_'.$config->{installation_id}),
                        expires_delta => $config->{session_expiration},
                        ip_match      => 1
        }
    );

	$self->hook('before_dispatch' => sub {
		my $self = shift;

		my $session = $self->stash('mojox-session');
		$session->load;
		if($session->sid){
			# we need mojox-session only for signed-in users
			if($self->signature_exists){
				$session->extend_expires;
				$session->flush;
			}else{
				# this will set expire on cookie as well as in store
				$session->expire;
                                $session->flush;
			}
		}else{
			if($self->signature_exists){
				$session->create;
			}
		}

	});

	$self->hook('after_dispatch' => sub {
		my $self = shift;
		my $json = $self->res->json;
		if($json){
			if($json->{alerts}){
				if(scalar(@{$json->{alerts}}) > 0){
					$self->app->log->debug("Alerts:\n".$self->dumper($json->{alerts}));
				}
			}
		}
	});

	$self->sessions->default_expiration($config->{session_expiration});
	# 0 if the ui is not running on https, otherwise the cookies won't be sent and session won't work
	$self->sessions->secure($config->{secure_cookies});
	$self->sessions->cookie_name('a_'.$config->{installation_id});

    $self->helper(save_token => sub {
    	my $self = shift;
		my $token = shift;

		my $session = $self->stash('mojox-session');
		$session->load;
		unless($session->sid){
			$session->create;
		}

		$session->data(token => $token);
    });

    $self->helper(load_token => sub {
    	my $self = shift;

    	my $session = $self->stash('mojox-session');
		$session->load;
		unless($session->sid){
			return undef;
		}

		return $session->data('token');
    });

  	# init I18N
  	$self->plugin(charset => {charset => 'utf8'});
  	$self->plugin(I18N => {namespace => 'PhaidraBagger::I18N', support_url_langs => [qw(en de it sr)]});

  	# init cache
  	$self->plugin(CHI => {
	    default => {
	      	driver		=> 'Memory',
	      	#driver     => 'File', # FastMmap seems to have problems saving the metadata structure (it won't save anything)
	    	#root_dir   => '/tmp/phaidra-ui-cache',
	    	#cache_size => '20m',
	      	global => 1,
	      	#serializer => 'Storable',
	    },
  	});

    # if we are proxied from base_apache/ui eg like
    # ProxyPass /ui http://localhost:3000/
    # then we have to add /ui/ to base of every req url
    # (set $config->{proxy_path} in config)
    if($config->{proxy_path}){
	    $self->hook('before_dispatch' => sub {
		my $self = shift;
	      	push @{$self->req->url->base->path->trailing_slash(1)}, $config->{proxy_path};
	    });
    }

    my $r = $self->routes;
    $r->namespaces(['PhaidraBagger::Controller']);

    $r->route('') 			  		->via('get')   ->to('frontend#home', opensignin => 1);

    $r->route('signin') 			  	->via('get')   ->to('authentication#signin');
    $r->route('signout') 			->via('get')   ->to('authentication#signout');
    $r->route('loginform') 			->via('get')   ->to('authentication#loginform');

    $r->route('proxy/get_uwmetadata_tree') ->via('get')   ->to('proxy#get_uwmetadata_tree');
    $r->route('proxy/get_uwmetadata_languages') ->via('get')   ->to('proxy#get_uwmetadata_languages');
    $r->route('proxy/get_help_tooltip') ->via('get')   ->to('proxy#get_help_tooltip');
    $r->route('proxy/get_directory_get_org_units') ->via('get')   ->to('proxy#get_directory_get_org_units');
    $r->route('proxy/get_directory_get_study') ->via('get')   ->to('proxy#get_directory_get_study');
    $r->route('proxy/get_directory_get_study_name') ->via('get')   ->to('proxy#get_directory_get_study_name');
    $r->route('proxy/objects') ->via('get')   ->to('proxy#search_owner');
    $r->route('proxy/objects/:username') ->via('get')   ->to('proxy#search_owner');
    $r->route('proxy/search') ->via('get')   ->to('proxy#search');
    $r->route('proxy/object/:pid/related') ->via('get')   ->to('proxy#get_related_objects');
    $r->route('proxy/terms/children') ->via('get')   ->to('proxy#get_terms_children');
    $r->route('proxy/terms/taxonpath') ->via('get')   ->to('proxy#get_taxonpath');
    $r->route('proxy/terms/search') ->via('get')   ->to('proxy#get_search');

    # if not authenticated, users will be redirected to login page
    my $autn = $r->under('/')->to('authentication#check');
    my $autz = $autn->under('/')->to('authorization#check');

    $autz->route('settings') 			->via('get')   ->to('settings#settings');
    $autz->route('settings') 			->via('post')  ->to('settings#save');
    $autz->route('settings/my') 	    ->via('get')   ->to('settings#load');

    $autz->route('selection') 			->via('post')   ->to('frontend#post_selection');
    $autz->route('selection') 			->via('get')   ->to('frontend#get_selection');

    $autz->route('classifications') 			->via('post')   ->to('frontend#toggle_classification');
    $autz->route('classifications') 			->via('get')   ->to('frontend#get_classifications');

    $autz->route('uwmetadata_template_editor') ->via('get')  ->to('template#uwmetadata_template_editor');
    $autz->route('uwmetadata_template_editor/:tid') ->via('get')  ->to('template#uwmetadata_template_editor');

    $autz->route('mods_template_editor') ->via('get')  ->to('template#mods_template_editor');
    $autz->route('mods_template_editor/:tid') ->via('get')  ->to('template#mods_template_editor');

    $autz->route('proxy/get_object_uwmetadata/:pid') ->via('get')   ->to('proxy#get_object_uwmetadata');
    $autz->route('proxy/save_object_uwmetadata/:pid') ->via('post')   ->to('proxy#save_object_uwmetadata');
    $autz->route('proxy/collection/create') ->via('post')   ->to('proxy#collection_create');
    $autz->route('proxy/collection/:pid/members/order') ->via('post')   ->to('proxy#collection_order');
    $autz->route('proxy/collection/:pid/members/:itempid/order/:position') ->via('post')   ->to('proxy#collection_member_order');
    $autz->route('proxy/collection/:pid/members/:itempid/order/') ->via('post')   ->to('proxy#collection_member_order');

    $autz->route('template') ->via('put')   ->to('template#create');
    $autz->route('template/:tid') ->via('post')   ->to('template#save');
    $autz->route('template/:tid') ->via('get')   ->to('template#load');
    $autz->route('template/:tid') ->via('delete')   ->to('template#delete');
    $autz->route('template/:tid/shared/toggle') ->via('post')   ->to('template#toggle_shared');

    $autz->route('templates') ->via('get')   ->to('template#templates');
    $autz->route('templates/my') ->via('get')   ->to('template#my');

    $autz->route('bags') ->via('get')   ->to('bag#bags');
    $autz->route('bags/folder/:folderid') ->via('get')   ->to('bag#folder_bags');
    $autz->route('bags/folder/:folderid') ->via('post')   ->to('bag#folder_bags_with_query');
    $autz->route('bags/search') ->via('post')   ->to('bag#search');
    $autz->route('bags/search/:filterfield/:filtervalue') ->via('post')   ->to('bag#search');
    #$autz->route('bags/import') ->via('get')   ->to('bag#import');
    $autz->route('bags/import/uwmetadata') ->via('get')   ->to('bag#import_uwmetadata_xml');
    $autz->route('bags/set/:attribute/:value') ->via('post')   ->to('bag#set_attribute_mass');
    $autz->route('bags/unset/:attribute/:value') ->via('post')   ->to('bag#unset_attribute_mass');

    $autz->route('bags/solr_search') ->via('get')   ->to('bag#solr_search');
    
    $autz->route('bag/:bagid/edit') ->via('get')   ->to('bag#edit');
    $autz->route('bag/:bagid') ->via('get')   ->to('bag#load');
    $autz->route('bag/template/:tid') ->via('get')   ->to('bag#load_template');
    $autz->route('bag/:bagid/uwmetadata') ->via('post')   ->to('bag#save_uwmetadata');
    $autz->route('bag/:bagid/mods') ->via('post')   ->to('bag#save_mods');
    $autz->route('bag/:bagid/:attribute/:value') ->via('put')   ->to('bag#set_attribute');
    $autz->route('bag/:bagid/:attribute/:value') ->via('delete')   ->to('bag#unset_attribute');
	$autz->route('bag/:bagid/geo') ->via('get')   ->to('bag#get_geo');
	$autz->route('bag/:bagid/geo') ->via('post')   ->to('bag#save_geo');
	$autz->route('bag/:bagid/mods/classifications') ->via('get')   ->to('bag#get_mods_classifications');

	$autz->route('bag/uwmetadata/tree') ->via('get') ->to('bag#get_uwmetadata_tree');
	$autz->route('bag/mods/tree') ->via('get') ->to('bag#get_mods_tree');

    #$autz->route('bag/:bagid/uwmetadata') ->via('get')   ->to('bag#get_uwmetadata');

	$autz->route('job')                        ->via('put')    ->to('job#create');
    $autz->route('job/:jobid')                 ->via('post')   ->to('job#save');
    $autz->route('job/:jobid')                 ->via('get')    ->to('job#load');
    $autz->route('job/:jobid')                 ->via('delete') ->to('job#delete');
    $autz->route('job/:jobid/bags')            ->via('post')   ->to('job#bags');
    $autz->route('job/:jobid/toggle_run')      ->via('post')   ->to('job#toggle_run');
    $autz->route('job/:jobid/view')            ->via('get')    ->to('job#view');
    $autz->route('jobs')                       ->via('get')    ->to('job#jobs');
    $autz->route('jobs/my')                    ->via('get')    ->to('job#my');

    $autz->route('folders') ->via('get')   ->to('folder#folders');
    $autz->route('folders/import') ->via('get')   ->to('folder#import');
    $autz->route('folder/:folderid/deactivate') ->via('put')   ->to('folder#deactivate_folder');
    $autz->route('folders/list') ->via('get')   ->to('folder#get_folders');
=cut
    $autz->route('file/:fileid/edit') ->via('get')   ->to('file#edit');
    $autz->route('file/:fileid/assignee/:username') ->via('put')   ->to('file#change_assignee');
    $autz->route('file/:fileid/uwmetadata') ->via('post')   ->to('file#save_uwmetadata');
    $autz->route('file/template/:tid/difab') ->via('get')   ->to('file#load_difab_template');
=cut
    $autz->route('chillin') ->via('get')   ->to('frontend#chillin');

    $autz->route('log') ->via('get')   ->to('log#log');
    $autz->route('log/events') ->via('get')   ->to('log#events');

    $autz->route('search_solr')     ->via('get')   ->to('frontend#search_solr');
    $autz->route('search_solr_all')     ->via('get')   ->to('frontend#search_solr_all');
   
    
    return $self;
}

1;
 