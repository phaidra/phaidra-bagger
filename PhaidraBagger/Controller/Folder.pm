package PhaidraBagger::Controller::Folder;

use strict;
use warnings;
use v5.10;
use Mango::BSON ':bson';
use Mango::BSON::ObjectID;
use Mojo::Home;
use Mojo::JSON qw(encode_json decode_json);
use File::Find;
use POSIX qw(strftime);
use lib "lib";
my $home = Mojo::Home->new;
$home->detect('PhaidraBagger');

use base 'Mojolicious::Controller';

sub import {

	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $projectconfig = $self->app->config->{projects}->{$self->current_user->{project}};
	my $basepath = $projectconfig->{folders}->{in};

	my $folders = $self->hashdir($basepath);

	$self->app->log->info($self->app->dumper($folders));

	foreach my $folder (keys %{$folders}){
		$self->app->log->info("Importing folder $folder");

		my $folderpath = $basepath;

		$folderpath .= '/' unless substr($folderpath, -1) eq '/';
		$folderpath .= $folder;

		$self->app->log->info("Importing folder, folderpath $folderpath");

		# folder name + project name is the folder id
		my $folderid = $self->current_user->{project}.$folder;
		# clean folder id of special chars
		$folderid =~ s/\W//g;
	    my $found = $self->mango->db->collection('folders')->find_one({folderid => $folderid, project => $self->current_user->{project}});

		if(defined($found->{folderid})){
			push @{$res->{alerts}}, "Not inserting folder $folder, already exists with folderid ".$found->{folderid};
		}else{
			my $reply = $self->mango->db->collection('folders')->insert({ folderid => $folderid, name => $folder, project => $self->current_user->{project}, path => $folderpath, status => 'active', created => time, updated => time } );
			my $oid = $reply->{oid};
			if($oid){
				push @{$res->{alerts}}, "Importing folder $folderid [oid: $oid]";
			}else{
				push @{$res->{alerts}}, "Importing folder $folderid failed";
			}
		}

		# importing files
		foreach my $file (@{$folders->{$folder}->{'.'}}){
			$self->app->log->info("Importing object ".$file);

			# folder + filename, is the id
			my $bagid = $folderid."_".$file;
			# clean file id of special chars
			$bagid =~ s/\W//g;
			my $foundfile = $self->mango->db->collection('bags')->find_one({bagid => $bagid, project => $self->current_user->{project}});

			if(defined($foundfile->{folderid})){
				push @{$res->{alerts}}, "Not inserting file $file, already exists with fileid ".$foundfile->{bagid};
			}else{
				my $reply = $self->mango->db->collection('bags')->insert({ bagid => $bagid, file => $file, label => $file, folderid => $folderid, tags => [], project => $self->current_user->{project}, metadata => {uwmetadata => ''}, status => 'new', assignee => $projectconfig->{default_assignee}, created => time, updated => time } );
				my $oid = $reply->{oid};
				if($oid){
					push @{$res->{alerts}}, "Inserting bag $bagid [oid: $oid]";
				}else{
					push @{$res->{alerts}}, "Inserting bag $bagid failed";
				}

				if(exists($projectconfig->{thumbnails})){
					$self->app->log->info("Generating thumbnails for file $bagid in folder $folder");
					$self->generate_thumbnail($projectconfig, $folder, $file, $bagid);
				}
			}

		}

	}

	$self->render(json => $res, status => $res->{status});
}

sub generate_thumbnail {

	my $self = shift;
	my $projectconfig = shift;
	my $folder = shift;
	my $file = shift;
	my $bagid = shift;

	my $basepath = $projectconfig->{folders}->{in};
	my $filepath = $basepath;
	$filepath.= '/' unless substr($basepath, -1) eq '/';
	$filepath .= $folder.'/'.$file;

	my $thumb_dir = $projectconfig->{thumbnails}->{dir};

	my $thumb_dir_path = $thumb_dir;
	$thumb_dir_path .= '/' unless substr($thumb_dir_path, -1) eq '/';

	my $c_cmd = $projectconfig->{thumbnails}->{convert_cmd};
	my $m_cmd = $projectconfig->{thumbnails}->{thumbnail_medium_cmd};
	my $s_cmd = $projectconfig->{thumbnails}->{thumbnail_small_cmd};

	$file =~ m/(^.*)\.([a-zA-Z0-9]*)$/;
	my $name = $1;
	my $ext = $2;

	my $thumb_c_path = $thumb_dir_path."c_".$bagid.'_1.png';
	my $thumb_m_path = $thumb_dir_path."m_".$bagid.'_1.png';
	my $thumb_s_path = $thumb_dir_path."s_".$bagid.'_1.png';

	my $generate_from_path = $filepath;

	$self->app->log->info("Generating thumbnail for file $file");

	unless($ext eq 'png' || $ext eq 'PNG'){
		$self->app->log->debug("Converting $file to png");
		# first convert to png
		system("$c_cmd '$filepath' '$thumb_c_path'");
		if( $? == -1 ){
		  $self->app->log->error("failed to convert file $filepath to png: $!");
		}

		$generate_from_path = $thumb_c_path;
	}

	# medium, for file detail
	$self->app->log->debug("Generating medium thumbnail from $generate_from_path");
	system("$m_cmd '$generate_from_path' '$thumb_m_path'");
	if( $? == -1 ){
	  $self->app->log->error("failed to generate medium thumbnail for $filepath: $!");
	}

	# small, for file list
	$self->app->log->debug("Generating small thumbnail from $generate_from_path");
	system("$s_cmd '$generate_from_path' '$thumb_s_path'");
	if( $? == -1 ){
	  $self->app->log->error("failed to generate small thumbnail for $filepath: $!");
	}

	unless($ext eq 'png' || $ext eq 'PNG'){
		$self->app->log->debug("Deleting temp conversion file $thumb_c_path");
		# delete the png conversion file
		unlink $thumb_c_path or $self->app->log->error("failed to delete $thumb_c_path: $!");;
	}

}

sub folders {
    my $self = shift;
	my $thumb_path = $self->url_for($self->config->{projects}->{$self->current_user->{project}}->{thumbnails}->{url_path});
	my $redmine_baseurl = $self->config->{projects}->{$self->current_user->{project}}->{redmine_baseurl};
    my $init_data = { current_user => $self->current_user, thumb_path => $thumb_path, redmine_baseurl => $redmine_baseurl};
    $self->stash(init_data => encode_json($init_data));

	$self->render('folder/list');
}

sub get_folders {
    my $self = shift;

    $self->render_later;

	my $cursor = $self->mango->db->collection('folders')
		->find({ project => $self->current_user->{project}, status => 'active' })
		->sort({updated => -1})
		->fields({ folderid => 1, name => 1, path => 1, created => 1, updated => 1, project => 1 });

	my $coll = $cursor->all();
	$self->render(json => { items => $coll, alerts => [] , status => 200 });

}

sub deactivate_folder {

	my $self = shift;
	my $folderid = $self->stash('folderid');

	unless($self->current_user->{role} eq 'manager'){
		$self->render(json => { alerts => [{ type => 'danger', msg => "You are not authorized for this operation" }] }, status => 403);
		return;
	}

	$self->app->log->info("[".$self->current_user->{username}."] Deactivating folder $folderid");

	my $reply = $self->mango->db->collection('folders')->update({folderid => $folderid, project => $self->current_user->{project}},{ '$set' => {updated => time, 'status' => 'inactive' }} );

	$self->render(json => { alerts => [{ type => 'success', msg => "$folderid deactivated" }] }, status => 200);

}

sub hashdir {
	my $self = shift;
		my $dir = shift;
		opendir my $dh, $dir or die $!;
		my $tree = {}->{$dir} = {};
		while( my $file = readdir($dh) ) {
				next if $file =~ m[^\.{1,2}$];
				my $path = $dir .'/' . $file;
				$tree->{$file} = $self->hashdir($path), next if -d $path;
				push @{$tree->{'.'}}, $file;
		}
		return $tree;
}


1;
