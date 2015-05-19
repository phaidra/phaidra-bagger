## Installation

### install mongodb

### install perlbrew

##### tis to install one perlbrew that all users can use, alternatively install 

mkdir /opt/perl5

sudo chown username:group -R /opt/perl5/

export PERLBREW_ROOT=/opt/perl5

curl -kL http://install.perlbrew.pl | bash

sudo vi ~/.bash_profile (add 'source /opt/perl5/etc/bashrc')

perlbrew install perl-5.16.0

perlbrew switch perl-5.16.0

sudo chown username:group -R /opt/perl5/

###  install cpanminus

(optional, to make installing perl modules easier)

curl -L http://cpanmin.us | perl - --sudo App::cpanminus

###  install Mojolicious

curl -L cpanmin.us | perl - Mojolicious

###  install perl modules

cpanm Mango

cpanm Mojolicious::Plugin::I18N

cpanm Mojolicious::Plugin::Authentication

cpanm Mojolicious::Plugin::Session

cpanm Mojolicious::Plugin::CHI

cpanm IO::Socket::SSL

cpanm DBI

cpanm Mojo::IOLoop::ProcBackground

##  Configuration

see PhaidraBagger.json.example, point the bagger against eg phaidra-sandbox API

## Run

hypnotoad phaidra-bagger.cgi

(resp you can use morbo)

## Create bags

Resp if 'folders' are configured in json, the 'Import' button on 'Folders' page should run a process that scans the 'in' folder for folders (creating a folder record) containing files (creating bag records). However, you can also create those structures yourself:

An example folder structure

<pre>
{
    "_id" : ObjectId("547c94e5b3bf4e5183690000"),
    "status" : "active",
    "project" : "MyProject",
    "name" : "Test Folder",
    "path" : "/var/www/bagger/data/TestProject/folders/in/Test Folder",
    "created" : 1417450725,
    "updated" : 1417450725,
    "folderid" : "TestFolder"
}
</pre>

An example bag structure

<pre>
{
    "_id" : ObjectId("553a529bad0cd794d62b5a9d"),
    "assignee" : "username",
    "bagid" : "Test",
    "created" : 1429885508,
    "file" : "best_picture_ever.tif",
    "folderid" : "TestFolder",
    "label" : "Test",
    "metadata" : {
        "uwmetadata" : []
    },
    "project" : "MyProject",
    "status" : "new",
    "tags" : [],
    "updated" : 1429886939
}
</pre>

2) Query metadata in JSON format from API

From existing object:
GET https://services.phaidra-sandbox.univie.ac.at/api/object/o:123456789/uwmetadata

Empty tree:
GET https://services.phaidra-sandbox.univie.ac.at/api/uwmetadata/tree

and save into bagger 

$bag->{metadata}->{uwmetadata} = $antwortjson->{uwmetadata} 

The tree is currently not compressed by saving (everything is saved, not just the filled in values). This will be fixed later for uwmetadata. For mods the compression is implemented.

4) Log in into bagger and open the bag to edit the metadata.... etc

