package PhaidraBagger::Controller::Frontend;

use strict;
use warnings;
use v5.10;
use Mango 0.24;
use Mojo::JSON qw(encode_json decode_json);
use PhaidraBagger::Model::Cache;
use base 'Mojolicious::Controller';


use Encode qw(decode encode);
use URI::Escape;


sub chillin {
	my $self = shift;
	$self->render('chillin');
}

sub home {
    my $self = shift;
    
    unless($self->flash('redirect_to')){
    	# if no redirect was set, reload the current url
			$self->flash({redirect_to => $self->url_for('/')});
    }

    if($self->stash('opensignin')){
    	$self->flash({opensignin => 1});
    }
        
    my $init_data = { current_user => $self->current_user };
    $self->stash(init_data => encode_json($init_data));
    $self->stash(init_data_perl => $init_data);   

    $self->render('home');
}

sub post_selection {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot save selection, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my $payload = $self->req->json;
	my $selection = $payload->{selection};

	$self->mango->db->collection('user.selections')->update({username => $username}, { username => $username, selection => $selection }, { upsert => 1 });

	$self->render(json => { alerts => [] }, status => 200);

}

sub get_selection {
	my $self = shift;

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot load selection, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my $res = $self->mango->db->collection('user.selections')->find_one({username => $username});

	$self->render(json => { selection => $res->{selection} }, status => 200);
}

sub toggle_classification {
	my $self = shift;

	my $res = { alerts => [], status => 200 };

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot add classification, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}

	my $payload = $self->req->json;
	my $uri = $payload->{uri};

	my @uri = ($uri);
	my $cursor = $self->mango->db->collection('user.classifications')->find({ username => $username, classifications => {'$all' => \@uri } });
	my $hits = $cursor->count;

	if($hits > 0){
		$self->mango->db->collection('user.classifications')->update({username => $username}, { '$set' => {username => $username}, '$pullAll' => { classifications => \@uri } });
	}else{
		$self->mango->db->collection('user.classifications')->update({username => $username}, { '$set' => {username => $username}, '$addToSet' => { classifications => $uri } }, {upsert => 1});
	}

	$self->render(json => { alerts => [] }, status => 200);

}

sub get_classifications {
	my $self = shift;

	my $username = $self->current_user->{username};

	unless(defined($username)){
		$self->render(json => { alerts => [{ type => 'danger', msg => "Cannot load classifications, current user is missing (the session might be expired)." }] }, status => 500);
		return;
	}
	
	my $cache_model = PhaidraBagger::Model::Cache->new;	

	my @clss;
	# project defined classifications
	my $r = $self->mango->db->collection('project.settings')->find_one({project => $self->current_user->{project}});
	foreach my $uri (@{$r->{settings}->{classifications}}){
		my $class = $cache_model->resolve_class_uri($self, $uri);
		$class->{type} = 'project';
		push @clss, $class;
	}

	# user defined classification
	$r = $self->mango->db->collection('user.classifications')->find_one({username => $username});
	foreach my $uri (@{$r->{classifications}}){
		my $class = $cache_model->resolve_class_uri($self, $uri);
		$class->{type} = 'user';
		push @clss, $class;
	}
	#$self->app->log->debug($self->app->dumper(\@clss));
	$self->render(json => { classifications => \@clss }, status => 200);
}

sub makeSolrFieldsQuery{
    
    my $self = shift;
    my $filter = shift;
    my $ranges = shift;
    my $sortvalue = shift;
    my $sortfield = shift;
    my $allowedStatuses = shift;
    my $project = shift;
    
    
    $filter->{solr_field} = '' if not defined $filter->{solr_field};
    $filter->{solr_query} = '' if not defined $filter->{solr_query};
    
    if($filter->{solr_field} eq 'created' or $filter->{solr_field} eq 'updated'){
         #skip
    }else{
         $filter->{solr_query} = $self->escapeSolrSpecialChars($filter->{solr_query});
    }
    
    if(defined $allowedStatuses){
          $allowedStatuses = decode_json($allowedStatuses);
    }else{
          $allowedStatuses = "";
    }      
    
    # restriction of all statuses to allowed, defined in config json
    my $defaulAllStatuses = '';
    my $statCount = 1;
    if(defined $allowedStatuses && ref($allowedStatuses) eq 'ARRAY'){
         foreach my $allowedStatus (@{$allowedStatuses}){
               if($statCount == 1){
                      $defaulAllStatuses = "status:".$allowedStatus->{value};
               }else{
                      $defaulAllStatuses = $defaulAllStatuses." OR status:".$allowedStatus->{value};
               }
               $statCount++;
         }
    }
 
    my $fieldsQuery = '';
    my $fieldsQueryHash = {};

    if($filter->{solr_field} ne ""){
           $filter->{solr_query} = "*" if $filter->{solr_query} eq '';
           $fieldsQueryHash->{$filter->{solr_field}} = $filter->{solr_query};
    }
    
    #accessed over facet/filter
    if(defined $filter->{assignee}){
           $filter->{assignee} = "*" if $filter->{assignee} eq '';
           $filter->{assignee} = $self->escapeSolrSpecialChars($filter->{assignee});
           $fieldsQueryHash->{assignee} = $filter->{assignee};
    }
    #accessed over facet/filter
    if(defined $filter->{status}){
            $filter->{status} = $self->escapeSolrSpecialChars($filter->{status});
            $fieldsQueryHash->{status} = $filter->{status};
    }
    #accessed over facet/filter
    if(defined $filter->{tag}){
            $filter->{tag} = $self->escapeSolrSpecialChars($filter->{tag});
            $fieldsQueryHash->{bag_tgs} = $filter->{tag};
    }
 
    # ranges for 'created'
    if(defined $ranges->{created}->{year} and not defined $ranges->{created}->{month} and not defined $ranges->{created}->{day}){            
            my $year = $ranges->{created}->{year};
            $fieldsQueryHash->{created} = "[".$year."-01-01T00:00:00Z TO ".$year."-01-01T00:00:00Z+1YEARS]";
    }
    if(defined $ranges->{created}->{year} and defined $ranges->{created}->{month} and not defined $ranges->{created}->{day}){            
            my $year  = $ranges->{created}->{year};
            my $month = $ranges->{created}->{month};
            $fieldsQueryHash->{created} = "[".$year."-".$month."-01T00:00:00Z TO ".$year."-".$month."-01T00:00:00Z+1MONTHS]";
    }
    if(defined $ranges->{created}->{year} and defined $ranges->{created}->{month} and defined $ranges->{created}->{day}){            
            my $year  = $ranges->{created}->{year};
            my $month = $ranges->{created}->{month};
            my $day   = $ranges->{created}->{day};
            $fieldsQueryHash->{created} = "[".$year."-".$month."-".$day."T00:00:00Z TO ".$year."-".$month."-".$day."T00:00:00Z+1DAYS]";
    }
    # ranges for 'updated' 
    if(defined $ranges->{updated}->{year} and not defined $ranges->{updated}->{month} and not defined $ranges->{updated}->{day}){            
            my $year = $ranges->{updated}->{year};
            $fieldsQueryHash->{updated} = "[".$year."-01-01T00:00:00Z TO ".$year."-01-01T00:00:00Z+1YEARS]";
    }
    if(defined $ranges->{updated}->{year} and defined $ranges->{updated}->{month} and not defined $ranges->{updated}->{day}){            
            my $year  = $ranges->{updated}->{year};
            my $month = $ranges->{updated}->{month};
            $fieldsQueryHash->{updated} = "[".$year."-".$month."-01T00:00:00Z TO ".$year."-".$month."-01T00:00:00Z+1MONTHS]";
    }
    if(defined $ranges->{updated}->{year} and defined $ranges->{updated}->{month} and defined $ranges->{updated}->{day}){            
            my $year  = $ranges->{updated}->{year};
            my $month = $ranges->{updated}->{month};
            my $day   = $ranges->{updated}->{day};
            $fieldsQueryHash->{updated} = "[".$year."-".$month."-".$day."T00:00:00Z TO ".$year."-".$month."-".$day."T00:00:00Z+1DAYS]";
    }

    my $i = 1;
    my $doubleQuote = "\"";
    
    foreach my $key ( keys %{$fieldsQueryHash} ){
             $doubleQuote = "\"";
             if($key eq "created" or $key eq "updated"){
                   $doubleQuote = "";
             }
             if($fieldsQueryHash->{$key} == "*"){
                   $doubleQuote = "";
             }
             if($i == 1){
                   $fieldsQuery = $key.":".$doubleQuote.$fieldsQueryHash->{$key}.$doubleQuote;
             }else{
                   $fieldsQuery = $fieldsQuery." AND ".$key.":".$doubleQuote.$fieldsQueryHash->{$key}.$doubleQuote;
             }

             $i++;
    }
    
    # search all
    if( $filter->{solr_field} eq "" ){
            $filter->{solr_query} = "*" if $filter->{solr_query} eq '';
            if($fieldsQuery eq ''){
                   if($filter->{solr_query} eq "*"){
                          $fieldsQuery = "*:*";
                   }else{
                          $fieldsQuery = $self->getQuerySearchAllFields($filter->{solr_query});
                   }
            }else{
                   if($filter->{solr_query} ne "*"){
                          $fieldsQuery = $fieldsQuery." AND (".$self->getQuerySearchAllFields($filter->{solr_query}).")";
                   }
            }
    }
    
    # user project
    if($fieldsQuery eq ''){
        $fieldsQuery = "project:".$project;
    }else{
        $fieldsQuery = "(".$fieldsQuery.") AND "."project:".$project;
    }
    
    if($defaulAllStatuses ne ''){
          $fieldsQuery = $fieldsQuery." AND (".$defaulAllStatuses.")";
    }
        
    return $fieldsQuery;
    
}

sub getQuerySearchAllFields{
    
    my $self = shift;
    my $query = shift;
    
    my $searchAllFields = '*:*';
    my $fields = $self->app->config->{solr}->{fields};
   
    my $index = 1;
    foreach (@{$fields}) { 
         if( !($_->{value} eq 'created'  || $_->{value} eq 'updated' || $_->{value} eq 'dc_date' ) ){
               if($index == 1){
                     $searchAllFields = $_->{value} . ":\"$query\"";
               }else{
                     $searchAllFields = $searchAllFields." OR " . $_->{value} . ":\"$query\"";
               }
               $index++;
         }
    } 
    
    #$self->app->log->debug("getQuerySearchAllFields_dump:",$self->app->dumper($searchAllFields));
    #$self->app->log->debug("getQuerySearchAllFields:",$searchAllFields);
    
    return $searchAllFields;
}

sub makeSolrRangesQuery{

    my $self = shift;
    my $ranges = shift;
    my $urlHash = shift;
    
    if(defined $ranges->{created}->{day}){
          my $day = $ranges->{created}->{day};
          my $month = $ranges->{created}->{month};
          my $year = $ranges->{created}->{year};
          #without pivot, also in other elsif
          $urlHash->append("facet.range" => "{!tag=r1}created");
          $urlHash->append("f.created.facet.range.start" => $year."-".$month."-".$day."T00:00:00.000Z" );
          $urlHash->append("f.created.facet.range.end" => $year."-".$month."-".$day."T00:00:00.000Z+1DAYS" );
          $urlHash->append("f.created.facet.range.gap" => "+1DAY" );
    }elsif(defined $ranges->{created}->{month}){
          my $month_start = $ranges->{created}->{month};
          my $year = $ranges->{created}->{year};
          $urlHash->append("facet.range" => "{!tag=r1}created");
          $urlHash->append("f.created.facet.range.start" => $year."-".$month_start."-01T00:00:00.000Z" );
          $urlHash->append("f.created.facet.range.end" => $year."-".$month_start."-01T00:00:00.000Z+1MONTHS" );
          $urlHash->append("f.created.facet.range.gap" => "+1DAY" );
    }elsif(defined $ranges->{created}->{year}){
          my $year_start = $ranges->{created}->{year};
          my $year_end = $year_start + 1;
          $urlHash->append("facet.range" => "{!tag=r1}created");
          $urlHash->append("f.created.facet.range.start" => $year_start."-01-01T00:00:00.000Z" );
          $urlHash->append("f.created.facet.range.end" => $year_end."-01-01T00:00:00.000Z" );
          $urlHash->append("f.created.facet.range.gap" => "+1MONTH" );
    }else{
          $urlHash->append("facet.range" => "{!tag=r1}created");
          $urlHash->append("f.created.facet.range.start" => "2007-01-01T00:00:00.000Z" );
          $urlHash->append("f.created.facet.range.end" => "NOW/DAY" );
          $urlHash->append("f.created.facet.range.gap" => "+1YEAR" );
    }
    
    if(defined $ranges->{updated}->{day}){
          my $day = $ranges->{updated}->{day};
          my $month = $ranges->{updated}->{month};
          my $year = $ranges->{updated}->{year};
          $urlHash->append("facet.range" => "{!tag=r2}updated");
          $urlHash->append("f.updated.facet.range.start" => $year."-".$month."-".$day."T00:00:00.000Z" );
          $urlHash->append("f.updated.facet.range.end" => $year."-".$month."-".$day."T00:00:00.000Z+1DAYS" );
          $urlHash->append("f.updated.facet.range.gap" => "+1DAY" );
    }elsif(defined $ranges->{updated}->{month}){
          my $month_start = $ranges->{updated}->{month};
          my $year = $ranges->{updated}->{year};
          $urlHash->append("facet.range" => "{!tag=r2}updated");
          $urlHash->append("f.updated.facet.range.start" => $year."-".$month_start."-01T00:00:00.000Z" );
          $urlHash->append("f.updated.facet.range.end" => $year."-".$month_start."-01T00:00:00.000Z+1MONTHS" );
          $urlHash->append("f.updated.facet.range.gap" => "+1DAY" );
    }elsif(defined $ranges->{updated}->{year}){
          my $year_start = $ranges->{updated}->{year};
          my $year_end = $year_start + 1;
          $urlHash->append("facet.range" => "{!tag=r2}updated");
          $urlHash->append("f.updated.facet.range.start" => $year_start."-01-01T00:00:00.000Z" );
          $urlHash->append("f.updated.facet.range.end" => $year_end."-01-01T00:00:00.000Z" );
          $urlHash->append("f.updated.facet.range.gap" => "+1MONTH" );
    }else{
          $urlHash->append("facet.range" => "{!tag=r2}updated");
          $urlHash->append("f.updated.facet.range.start" => "2007-01-01T00:00:00.000Z" );
          $urlHash->append("f.updated.facet.range.end" => "NOW/DAY" );
          $urlHash->append("f.updated.facet.range.gap" => "+1YEAR" );
    }
    
    return $urlHash;
}

sub search_solr_all {
   
    my $self = shift;

    my $filter          = $self->param('filter');
    my $ranges          = $self->param('ranges');
    my $sortvalue       = $self->param('sortvalue');
    my $sortfield       = $self->param('sortfield');
    my $allowedStatuses = $self->param('allowedStatuses');
    my $project         = $self->param('project');
    
    $filter = encode('UTF-8', $filter, Encode::FB_CROAK);    
    $filter = decode_json($filter);
    $ranges = decode_json($ranges);
     
    my $urlHash = Mojo::Parameters->new;
    
    my $fieldsQuery  = $self->makeSolrFieldsQuery($filter, $ranges, $sortvalue, $sortfield, $allowedStatuses, $project);
   
    $urlHash->append('q' => $fieldsQuery);
    $urlHash->append('facet' => 'true');
    $urlHash->append('facet.field' => 'assignee');
    $urlHash->append('facet.field' => 'status');
    $urlHash->append('facet.field' => 'label');
    
    $urlHash = $self->makeSolrRangesQuery($ranges, $urlHash);
    
    if($sortvalue eq '1'){
           $sortvalue = "asc";
    }else{
           $sortvalue = "desc";
    }
    $urlHash->append('sort' => $sortfield." ".$sortvalue );
    $urlHash->append('wt' => 'json');
    
    my $base = $self->app->config->{solr}->{baseurl};
    my $url = Mojo::URL->new;
    $url->scheme('http'); 
    $url->host($base);
    $url->path("/select");

    $url->query($urlHash);
    
    my $url_string = $url->to_string;
    
    #$self->app->log->debug("url string:",$self->app->dumper($url->to_string));
    my $tx = $self->ua->get($url_string);
    
    if (my $res = $tx->success) {
           $self->render(json => $res->json, status => 200 );
    } else {
          my ($err, $code) = $tx->error;
          if($tx->res->json){       
                 if(exists($tx->res->json->{alerts})) {
                         $self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
                 }else{
                      $self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
                 }
          }else{
                  $self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
          }
    }
}


sub search_solr {

    my $self = shift;
    
    my $from            = $self->param('from');
    my $limit           = $self->param('limit');
    my $sortvalue       = $self->param('sortvalue');
    my $sortfield       = $self->param('sortfield');
    my $allowedStatuses = $self->param('allowedStatuses');
    my $filter          = $self->param('filter');
    my $ranges          = $self->param('ranges');
    my $project         = $self->param('project');
    
    $filter = encode('UTF-8', $filter, Encode::FB_CROAK);
    $filter = decode_json($filter);  
    $ranges = decode_json($ranges);  
      
    my $urlHash = Mojo::Parameters->new;
    my $fieldsQuery  = $self->makeSolrFieldsQuery($filter, $ranges, $sortvalue, $sortfield, $allowedStatuses, $project);
    $urlHash->append('q' => $fieldsQuery);
    $urlHash->append('rows' => $limit);
    $urlHash->append('start' => $from);
    if($sortvalue eq '1'){
           $sortvalue = "asc";
    }else{
           $sortvalue = "desc";
    }
    $urlHash->append('sort' => $sortfield." ".$sortvalue );
    $urlHash->append('wt' => 'json');
    
    my $base = $self->app->config->{solr}->{baseurl};
    my $url = Mojo::URL->new;
    $url->scheme('http'); 
    $url->host($base);
    $url->path("/select");

    $url->query($urlHash);
    
    my $url_string = $url->to_string;
    #$self->app->log->debug("search_solr url string:",$self->app->dumper($url_string));
    my $tx = $self->ua->get($url_string); 
        
    if (my $res = $tx->success) {
           $self->render(json => $res->json, status => 200 );
    } else {
          my ($err, $code) = $tx->error;
          if($tx->res->json){       
                 if(exists($tx->res->json->{alerts})) {
                         $self->render(json => { alerts => $tx->res->json->{alerts} }, status =>  $code ? $code : 500);
                 }else{
                      $self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
                 }
          }else{
                  $self->render(json => { alerts => [{ type => 'danger', msg => $err }] }, status =>  $code ? $code : 500);
          }
    }
}


sub escapeSolrSpecialChars {

    my $self = shift;
    my $query = shift;
    
    $query =~ s/\\/\\\\/g;  #\
    $query =~ s/\+/\\\+/g;  #+ 
    $query =~ s/-/\\-/g;    #-
    $query =~ s/\!/\\\!/g;  #!
    $query =~ s/\(/\\\(/g;  #(
    $query =~ s/\)/\\\)/g;  #)
    $query =~ s/{/\\{/g;    #}
    $query =~ s/}/\\}/g;    #}
    $query =~ s/\[/\\\[/g;  #[
    $query =~ s/\]/\\\]/g;  #]
    $query =~ s/\^/\\\^/g;  #^
    $query =~ s/"/\\"/g;    #"
    $query =~ s/~/\\~/g;    #~
    $query =~ s/\*/\\\*/g;  #*
    $query =~ s/:/\\:/g;    #:
    $query =~ s/\?/\\\?/g;  #?
    
    #$self->app->log->debug("escapeSolrSpecialChars_dump:",$self->app->dumper($query));
    #$self->app->log->debug("escapeSolrSpecialChars:",$query);
    
    return $query;
}

1;