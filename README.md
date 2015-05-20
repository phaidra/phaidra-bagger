## Installation

### install mongodb

### install perlbrew

(/opt/perl5 to install one perlbrew that all users can use, alternatively install into home directory)

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

<pre>
{

#### replace all the /var/www/bagger with actual path to repo

#### whatever
    "installation_id": "nice_n_unique",

#### proxy = 1 if the hypnotoad is possibly behined another server (like apache <-> hypnotoad)
   "hypnotoad": {
        "listen": ["http://*:3001"],
        "proxy": 1
   },

   "mode":"production",

#### encryption keys, just generate some random stuff 
   "secret":"changeme",
   "enc_key":"changeme",

   "session_expiration":"7200",

#### 0 if the bagger is served from http!!! otherwise the browser won't be sending the cookies so login/session won't be possible
  "secure_cookies":"1",
   
  "log_path":"/var/log/phaidra/PhaidraBagger.log",
  "log_level":"debug",
  "bagger_agent_path":"/var/www/bagger/lib/PhaidraBaggerAgent/phaidra_bagger_agent.pl",
  "validate_uwmetadata":"1",
  "defaults": {
    	"metadata_field_language": "de"
   },

    "projects": {
        
        "TestProject": {

#### the project account
        
            "account": "username",
            

#### configure project members, only the members listed are able to log in. THIS IS NO USER MANAGEMENT. For authentication, Mojolicious::Plugin::Authentication is used. Users are authenticated against phaidra-api of the default phaidra instance (see ingest_instances config), so it only makes sense to list users which can be authenticated there

            "members":  [
	            		{
		            		"username": "username",
		            		"role": "manager"
	            		},
	            		{
		            		"username": "username",
		            		"role": "manager"
	            		}
            		],
            		
#### some logic, like status colors or the need for to_ingest status on ingest are hardcoded, so don't change this unless necessary
            		
            "statuses":  [
	            		{
                                        "label": "New",
                                        "value": "new"
                                },
                                {
                                        "label": "To check",
                                        "value": "to_check"
                                },
                                {
                                        "label": "Checked",
                                        "value": "checked"
                                },
                                {
                                        "label": "To ingest",
                                        "value": "to_ingest"
                                }
            		],

            "default_assignee": "username",
            
#### operations/actions only a manager role can invoke
            
            "restricted_operations": ["set_assignee"],
            "restricted_actions": ["POST /job/"],
            
#### input folder
            
            "folders": {
                "in": "/var/www/bagger/data/p1/folders/in",
                "uwmetadata_import": "/var/www/bagger/data/p1/folders/in"
            },
            
#### if the import is implemented in another webapp
	    "import_url": "import-sub-app",
            
#### convert command is used by the import from folder (see 'folders') to generate thumbnails
            "thumbnails": {
		    	"dir": "/var/www/bagger/thumbnails/p2",
		    	"url_path": "thumbnails/p2",
		    	"convert_cmd": "convert",
		    	"thumbnail_medium_cmd": "/var/www/bagger/lib/downsize -s 2048 -t 20",
		    	"thumbnail_small_cmd": "/var/www/bagger/lib/downsize -s 60 -t 20"
		    }
        }
    },

    "ingest_instances": {

#### example: phaidra-sandbox    
        "phaidra-instance": {
            "baseurl": "phaidra-sandbox.univie.ac.at",
            "apibaseurl": "services.phaidra-sandbox.univie.ac.at/api",
            "metadata_format_version": "1",
            "local_uwmetadata_tree": "/var/www/bagger/public/uwmetadata/tree.json",
            "local_mods_tree": "/var/www/bagger/public/mods/tree.json",
            
#### important
            "is_default": "1"
        },
        "phaidra-instance2": {
            "baseurl": "phaidra-instance2.univie.ac.at",
            "apibaseurl": "services.phaidra-instance2.univie.ac.at/api",
            "metadata_format_version": "1",
            "local_uwmetadata_tree": "/var/www/bagger/public/uwmetadata/tree.json",
            "is_default": "0"
        }
    },

#### user used to ask for directory informations  (names, departments, etc)
    "directory_user": {
      "username": "username",
      "password": "password"
    },

    "mongodb": {
        "host": "host",
        "port": "27017",
        "username": "username",
        "password": "password",
        "database": "database"
    },

#### let this be
    "authentication": {
    	"realm": "Phaidra",
    	"token_header": "X-XSRF-TOKEN",
        "token_cookie": "XSRF-TOKEN",
    },
}
</pre>

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

