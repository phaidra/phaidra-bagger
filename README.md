Installation

0) install mongodb

1) tis to install one perlbrew that all users can use, alternatively install 

mkdir /opt/perl5

sudo chown username:group -R /opt/perl5/

export PERLBREW_ROOT=/opt/perl5


2) install perlbrew

curl -kL http://install.perlbrew.pl | bash


3) add 'source /opt/perl5/etc/bashrc'

sudo vi ~/.bash_profile

perlbrew install perl-5.16.0

perlbrew switch perl-5.16.0

sudo chown username:group -R /opt/perl5/


4) install cpanminus (to make installing perl modules easier)

curl -L http://cpanmin.us | perl - --sudo App::cpanminus


5) install Mojolicious

curl -L cpanmin.us | perl - Mojolicious


6) install perl modules (some might need libraries like expat-devel, mysql-devel, libxml etc)

cpanm Mango
cpanm Mojolicious::Plugin::I18N
cpanm Mojolicious::Plugin::Authentication
cpanm Mojolicious::Plugin::Session
cpanm Mojolicious::Plugin::CHI
cpanm IO::Socket::SSL
cpanm DBI
cpanm Mojo::IOLoop::ProcBackground

7) configure (see PhaidraBagger.json.example, point the bagger against eg phaidra-sandbox API)
