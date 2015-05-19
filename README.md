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

###  configure 

see PhaidraBagger.json.example, point the bagger against eg phaidra-sandbox API
