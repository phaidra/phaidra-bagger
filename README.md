Installation

sudo bash

mkdir /opt/perl5
sudo chown username:group -R /opt/perl5/
export PERLBREW_ROOT=/opt/perl5

curl -kL http://install.perlbrew.pl | bash
# add 'source /opt/perl5/etc/bashrc'
sudo vi ~/.bash_profile
perlbrew install perl-5.16.0
perlbrew switch perl-5.16.0
sudo chown username:group -R /opt/perl5/

