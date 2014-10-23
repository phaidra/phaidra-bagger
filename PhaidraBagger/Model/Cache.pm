package PhaidraBagger::Model::Cache;

use strict;
use warnings;
use v5.10;
use base qw/Mojo::Base/;

sub get_terms_label {
	my $self = shift;
	my $c = shift;   	
	my $uri = shift;
	
	my $res = { alerts => [], status => 200 };
	
	my $cachekey = 'labels_'.$uri;
	my $cacheval = $c->app->chi->get($cachekey);
	  		
	if($cacheval){   			  	
		$c->app->log->debug("[cache hit] $cachekey");
		$res->{labels} = $cacheval;
		return $res;			
	}else{
		
		$c->app->log->debug("[cache miss] $cachekey");
	
		my $url = Mojo::URL->new;
		$url->scheme('https');		
		my @base = split('/',$c->app->config->{phaidra}->{apibaseurl});
		$url->host($base[0]);
		if(exists($base[1])){
			$url->path($base[1]."/terms/label");
		}else{
			$url->path("/terms/label");
		}
		
		$url->query({uri => $uri});
		
  		my $tx = $c->ua->get($url);
  		
  		if (my $r = $tx->success) {
  			my $cacheval = $tx->res->json->{labels};  		
	    	$c->app->chi->set($cachekey, $cacheval, '1 day');    
	    	# serialization check
	    	$cacheval = $c->app->chi->get($cachekey);
  			$res->{labels} = $cacheval;  
  			return $res;
  		} else {
			my ($err, $code) = $tx->error;
			if(exists($tx->res->json->{alerts})) {
				$res->{alerts} = $tx->res->json->{alerts};
				$res->{status} = $code ? $code : 500;				
			}else{
				$res->{alerts} = [{ type => 'danger', msg => $err }];
				$res->{status} = $code ? $code : 500;	
			}
			return $res;
		}
  
	}
	
}	

1;
__END__
