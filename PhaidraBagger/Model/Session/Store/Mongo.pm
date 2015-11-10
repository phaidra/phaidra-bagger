package PhaidraBagger::Model::Session::Store::Mongo;

use strict;
use warnings;
use base 'MojoX::Session::Store';
use Mango 0.24;
use Data::Dumper;

__PACKAGE__->attr('mango');
__PACKAGE__->attr('log');


#sub is_async { 1 }

sub create {
    my ($self, $sid, $expires, $data) = @_;
    
    $expires = $expires*1000;
    #$self->log->debug("mango:",Dumper($self->mango));
    #$self->log->debug("mango sid:",Dumper($sid));
    #$self->log->debug("mango expires:",Dumper($expires));
    #$self->log->debug("mango data:",Dumper($data));
  
    #mf hack!!!
    $data->{"mojox\uff0Esession\uff0Eip_address"} = $data->{"mojox.session.ip_address"};
    delete $data->{"mojox.session.ip_address"};
    
    $self->mango->db->collection('session')->update({_id => $sid}, { _id => $sid, expires => Mango::BSON::Time->new($expires), data => $data }, { upsert => 1 }); 	   
    
    return 1;
}

sub update {	
    shift->create(@_);
}

sub load {
    my ($self, $sid) = @_;    
    
    #$self->log->debug("loadsid:",Dumper($sid));
    my $res = $self->mango->db->collection('session')->find_one({_id => $sid});
    #$res->{expires} = 0 if not defined $res->{expires};
    my $expires = $res->{expires}/1000;    
    
    return ($expires, $res->{data});
}

sub delete {
    my ($self, $sid) = @_;    
    
    my $res = $self->mango->db->collection('session')->remove({_id => $sid});
    
    return 1;
}

1;

