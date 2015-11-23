app.controller('BagsCtrl',  function($scope, $modal, $location, $timeout, DirectoryService, BagService, FrontendService, promiseTracker, Url) {

  // we will use this to track running ajax requests to show spinner
  $scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

  $scope.alerts = [];

  $scope.selection = [];

  $scope.items = [];
  $scope.itemstype = '';

  $scope.members = [];

  $scope.initdata = '';
  $scope.current_user = '';
  $scope.folderid = '';

  $scope.totalItems = 0;
  $scope.currentPage = 1;
  $scope.maxSize = 10;
  $scope.filter = {};
  $scope.from = 0;
  $scope.limit = 10;
  $scope.sortfield = 'label';
  $scope.sortvalue = '1';
  
  $scope.solr_field = "All Fields";
  $scope.solr_field_display = "All Fields";
  $scope.placeholder = 'Search';
  $scope.dublincoreFields = [];
  
  $scope.solr_response = {};
  $scope.facetFieldsStatus = [];
  $scope.filter_send = {};
  $scope.ranges = {};
  $scope.facetRangesCreated = [];
  $scope.facetRangesUpdated = [];
  $scope.pattern_error_display = 0;
  $scope.solr_query_date_flag = 0;
  $scope.solrQuery_date = "";
  $scope.solrQuery_not_date = "";

  $scope.init = function (initdata) {
	
        $scope.initdata = angular.fromJson(initdata);
        //delete it
        //$scope.initdata.current_user.project = 'UB-Maps';
        
	console.log('search initdata:',$scope.initdata);
        $scope.current_user = $scope.initdata.current_user;
	$scope.folderid = $scope.initdata.folderid;
       
        
	if($scope.folderid){
			$scope.filter['folderid'] = $scope.folderid;
	}
             
	if($scope.initdata.query){
		$scope.filter = $scope.initdata.query.filter;
		$scope.from = $scope.initdata.query.from;
		$scope.limit = $scope.initdata.query.limit;
		$scope.sortfield = $scope.initdata.query.sortfield;
		$scope.sortvalue = $scope.initdata.query.sortvalue;
	}

        $scope.searchQuerySolr();
        
        if($scope.current_user){
  		$scope.loadSelection();
  	}
  	
  	var field0 = {};
        field0.value = "All Fields";
        field0.label = "All Fields";
        $scope.dublincoreFields.push(field0);
  	
        for( var i = 0 ; i < $scope.initdata.fields.length ; i++ ){
               var field = {};
               field.value =  $scope.initdata.fields[i].value;
               field.label = $scope.initdata.fields[i].label;
               $scope.dublincoreFields.push(field);    
        }
  };
   $scope.getQuerySolr = function() {
            
            var sorlQuery = '';
            if($scope.solr_query_date_flag){
                 sorlQuery = $scope.solrQuery_date; 
            }else{
                 sorlQuery = $scope.solrQuery_not_date;
            }
            return sorlQuery;
   }

   $scope.searchQuerySolr = function() {
          
            if($scope.solr_field == 'All Fields'){
                 delete $scope.solr_field; 
            }
            
            // here!!!  search all fields qeury = 2004-12-02T16:39:18 returns all  and qure and field are undefined

            
           
            angular.copy($scope.filter, $scope.filter_send);

            $scope.filter_send.solr_query = $scope.getQuerySolr();           
            $scope.filter_send.solr_field = $scope.solr_field;
            
            var allowedStatuses = {};
            if($scope.initdata.statuses){
                  allowedStatuses = angular.toJson($scope.initdata.statuses); 
            }

            var promise = FrontendService.search_solr_all($scope.filter_send, $scope.ranges, $scope.sortvalue, $scope.sortfield, allowedStatuses, $scope.initdata.current_user.project);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
                function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.totalItems = response.data.response.numFound;
                        $scope.facetFieldsStatus = $scope.formatFacets(response.data.facet_counts.facet_fields.status);
                        $scope.facetFieldsAssignee = $scope.formatFacets(response.data.facet_counts.facet_fields.assignee);
                        $scope.facetFieldsLabel = $scope.formatFacets(response.data.facet_counts.facet_fields.label);
                        if(typeof response.data.facet_counts.facet_ranges.created !== 'undefined'){
                                 $scope.facetRangesCreated = $scope.formatFacets(response.data.facet_counts.facet_ranges.created.counts);
                        }
                        if(typeof response.data.facet_counts.facet_ranges.updated !== 'undefined'){
                                 $scope.facetRangesUpdated = $scope.formatFacets(response.data.facet_counts.facet_ranges.updated.counts);
                        }
                        $scope.form_disabled = false;
                        $scope.searchQuerySolr_onePage();
                }
                ,function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
                        $scope.form_disabled = false;
                }
            );
    }
  
   $scope.searchQuerySolr_onePage = function() {
            
            if($scope.solr_field == 'All Fields'){
                 delete $scope.solr_field; 
            }
     
            
            var allowedStatuses = {};
            if($scope.initdata.statuses){
                  allowedStatuses = angular.toJson($scope.initdata.statuses); 
            }
            
            $scope.filter_send.solr_query = $scope.getQuerySolr();           
            $scope.filter_send.solr_field = $scope.solr_field;
            
            var promise = FrontendService.searchSolr($scope.from, $scope.limit, $scope.filter_send, $scope.ranges, $scope.sortvalue, $scope.sortfield, allowedStatuses, $scope.initdata.current_user.project);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
                function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.solr_response = response.data.response;
                        $scope.form_disabled = false;
                }
                ,function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
                        $scope.form_disabled = false;
                }
            );
   }
  
 $scope.formatFacets = function(facet) {

          var formatedFacet = [];
          var couple = 1;
          var field_name = "";
          for( var i = 0 ; i < facet.length ; i++ ){
                  if(couple == 1){
                        field_name = facet[i];
                        couple = 2;
                  }else{
                       var s = {};
                       s.field = field_name;
                       s.count = facet[i];
                       formatedFacet.push(s);
                       couple = 1;
                  }
          }
          return formatedFacet;
  }
  
 $scope.addFilter = function (type, value) {
         
         if(typeof type !== 'undefined' ){                
                  $scope.filter[type] = value;
         }
         
         $scope.searchQuerySolr();
 } 
 
  $scope.getMemberDisplayname = function (username) {
          for( var i = 0 ; i < $scope.initdata.members.length ; i++ ){
                  if($scope.initdata.members[i].username == username){
                          return $scope.initdata.members[i].displayname;
                  }
          }
          return username;
  }
 
  $scope.removeFilter = function (type, value) {
          if($scope.filter){                 
                 delete $scope.filter[type];
                 $scope.solrQuery_not_date = '';
                 $scope.solrQuery_date = '';
                 $scope.searchQuerySolr(); 
          }
 }
 
  $scope.getYear = function (date) {
          
          var res = date.split("-");
          return res[0];
  }
  
  $scope.getMonth = function (date) {
          
          var res = date.split("-");
          return res[1];
  }
  
  $scope.getDay = function (date) {
          
          var res = date.split("-");
          var res2 = res[2];
          var res3 = res2.split("T");
          return res3[0];
  }
    $scope.getDate = function (date, date_part) {
          
          var res;
          if(date_part == "year"){
               res = $scope.getYear(date);  
          }
          if(date_part == "month"){
               res = $scope.getMonth(date);  
          }
          if(date_part == "day"){
               res = $scope.getDay(date);  
          }

          return res;
  }
 
  $scope.narrowFacetRange = function (field, dateRange, date) {
         
          if(typeof  dateRange == 'undefined'){
               dateRange = '';
          }
          var range = {};
          if(dateRange == 'year'){
                $scope.ranges[field] = {};
                $scope.ranges[field].year = $scope.getYear(date);
                delete $scope.ranges[field].month;  
                delete $scope.ranges[field].day;  
          }
          if(dateRange == 'month'){
               $scope.ranges[field].year  = $scope.getYear(date);
               $scope.ranges[field].month = $scope.getMonth(date);
               delete $scope.ranges[field].day;  
          }
          if(dateRange == 'day'){
               $scope.ranges[field].year  = $scope.getYear(date);
               $scope.ranges[field].month = $scope.getMonth(date);
               $scope.ranges[field].day   = $scope.getDay(date);
          }
          if(dateRange == 'all'){
                delete $scope.ranges[field]; 
          }
          $scope.searchQuerySolr();
  }
 
 
   $scope.getRangesLabel = function (type, value) {
           
           var res = '';
           if(typeof  value.year != 'undefined'){
                res = value.year;
           }
           if(typeof  value.month != 'undefined'){
                res = res+'-'+value.month;
           }
           if(typeof  value.day != 'undefined'){
                res = res+'-'+value.day;
           }
           res = type+':'+res;
           
           return res;
   }
 
   $scope.toggleSort = function (sortfield, sortvalue) {
         if($scope.sortfield == sortfield){
                 $scope.sortvalue = $scope.sortvalue == '1' ? '-1' : '1';
         }else{
                 $scope.sortvalue = '1';
         }
         $scope.sortfield = sortfield;
         $scope.searchQuerySolr();
   }
 
  $scope.setAttribute = function (bag, attribute, value) {

     var promise = BagService.setAttribute(bag.bagid, attribute, value);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
        function(response) {
                $scope.alerts = response.data.alerts;
                bag[attribute] = value;
        }
        ,function(response) {
                $scope.alerts = response.data.alerts;
                $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
        }
     );
  }
  
  $scope.setLimit = function(limit){
           $scope.limit = limit;
           $scope.searchQuerySolr();
  }
 
  $scope.selectVisible = function(event){
        $scope.selection = [];
        for( var i = 0 ; i < $scope.solr_response.docs.length ; i++ ){
                $scope.selection.push($scope.solr_response.docs[i].bagid);
            }
        $scope.saveSelection();
  };
 

    $scope.selectAll = function() {
           
            angular.copy($scope.filter, $scope.filter_send);
            $scope.filter_send.solr_query = $scope.getQuerySolr();
            $scope.filter_send.solr_field = $scope.solr_field;
            var allowedStatuses = {};
            if($scope.initdata.statuses){
                  allowedStatuses = angular.toJson($scope.initdata.statuses); 
            }
            var promise = FrontendService.search_solr_all($scope.filter_send, $scope.ranges, $scope.sortvalue, $scope.sortfield, allowedStatuses, $scope.initdata.current_user.project);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
                function(response) {
                        $scope.selection = [];
                        for( var i = 0 ; i < response.data.response.docs.length ; i++ ){
                                $scope.selection.push(response.data.response.docs[i].bagid);
                        }
                        $scope.saveSelection();
                        $scope.alerts = response.data.alerts;
                }
                ,function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
                        $scope.form_disabled = false;
                }
            );
    }
    
    $scope.getFilterLabel = function(type, value){

         if(type == 'status'){
                 if(value.length == 1){
                         var statValue = value[0];
                         for( var i = 0 ; i < $scope.initdata.statuses.length ; i++ ){
                                if($scope.initdata.statuses[i].value == statValue){
                                        return $scope.initdata.statuses[i].label;
                                }
                         }
                 }
         }

         if(type == 'assignee'){
                 return $scope.getMemberDisplayname(value);
         }

         return value;
 }
 
  $scope.setAttributeMass = function (attribute, value) {
     
     var promise = BagService.setAttributeMass($scope.selection, attribute, value);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
        function(response) {
                $scope.alerts = response.data.alerts;
                $scope.searchQuerySolr();
                //$timeout( function(){ $scope.searchQuerySolr(); }, 1000);
               
        }
        ,function(response) {
                $scope.alerts = response.data.alerts;
                $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
        }
     );
 }
 
 
 
 

    $scope.closeAlert = function(index) {
    	       $scope.alerts.splice(index, 1);
    };

    $scope.getBagUrlWithQuery = function (bagid) {
		var url = $('head base').attr('href')+'bag/'+bagid+'/edit';
		var params = {
			filter: $scope.filter,
			from: $scope.from,
			limit: $scope.limit,
			sortfield: $scope.sortfield,
			sortvalue: $scope.sortvalue
		};
		//return url+'?'+ $scope.qs(params, null);
		return Url.buildUrl(url, params);
    };

    $scope.selectNone = function(event){
    	$scope.selection = [];
    	$scope.saveSelection();
    };

    $scope.saveSelection = function() {
    	var promise = FrontendService.updateSelection($scope.selection);
	    $scope.loadingTracker.addPromise(promise);
	    promise.then(
	     	function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.form_disabled = false;
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      		$scope.form_disabled = false;
	      	}
	    );
    }

    $scope.loadSelection = function() {
    	var promise = FrontendService.getSelection();
	    $scope.loadingTracker.addPromise(promise);
	    promise.then(
	     	function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.selection = response.data.selection;
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      	}
	    );
    }

    $scope.toggleFile = function(pid) {
    	var idx = $scope.selection.indexOf(pid);
    	if(idx == -1){
    		$scope.selection.push(pid);
    	}else{
    		$scope.selection.splice(idx,1);
    	}
    	$scope.saveSelection();
    };

   $scope.setPage = function (page) {
        if(page == 1){
               $scope.from = 0;
         }else{
               $scope.from = (page-1)*$scope.limit;
         }
        $scope.searchQuerySolr();
        
        $scope.currentPage = page;
    };
    

  // not used now
  //$scope.isNotDefaultFilter = function(type, value){
  //	 if(type == 'status'){
  //		 if(value.length > 1){
  //			 return false;
  //		 }
  //	 }
  //	 return true;
  // }
 

  $scope.tagModal = function (mode) {

	var modalInstance = $modal.open({
        templateUrl: $('head base').attr('href')+'views/modals/define_tag.html',
        controller: TagModalCtrl,
        scope: $scope,
        resolve: {
			    mode: function(){
				   return mode;
				  }
		    }
	  });
  };

  $scope.createIngestJob = function () {
	  var modalInstance = $modal.open({
          templateUrl: $('head base').attr('href')+'views/modals/create_ingest_job.html',
          controller: CreateIngestJobModalCtrl,
          scope: $scope
	  });
  }


  $scope.canSetAttribute = function (attribute) {
	  return $scope.initdata.restricted_ops.indexOf('set_'+attribute) == -1 || $scope.current_user.role == 'manager';
  }

  $scope.iso8601ToUnixEpoch = function (dateString) {
          
          return Date.parse(dateString)
  }

  $scope.setSearchQuery = function (value, label) {

          $scope.solr_field = value;
          $scope.solr_field_display = label;
          if(value == 'created' || value == 'updated' || value == 'dc_date') {
               $scope.placeholder = '[YYYY-MM-DDThh:mm:ssZ TO YYYY-MM-DDThh:mm:ssZ]';
               $scope.pattern_error_display = 1;
               $scope.solr_query_date_flag = 1;
          }else{
               $scope.solr_query_date_flag = 0;
               $scope.pattern_error_display = 0;
               $scope.placeholder = 'Search';
          }
  }
  
  
});

var TagModalCtrl = function ($scope, $modalInstance, FrontendService, BagService, promiseTracker, mode) {

	$scope.modaldata = { tag: '' };

	$scope.operation = 'Ok';

	switch(mode){
		case 'add':
			$scope.operation = 'Add';
			break;

		case 'remove':
			$scope.operation = 'Remove';
			break;

		case 'filter':
			$scope.operation = 'Filter';
			break;
	}

    $scope.hitEnterTagEdit = function(evt){
    	if(angular.equals(evt.keyCode,13)){
    		$scope.applyAction();
    	}
    };

    $scope.applyAction = function () {

		$scope.form_disabled = true;

		var promise;

		switch(mode){
			case 'add':
				promise = BagService.setAttributeMass($scope.selection, 'tags', $scope.modaldata.tag);
				break;

			case 'remove':
                                promise = BagService.unsetAttributeMass($scope.selection, 'tags', $scope.modaldata.tag);
				break;

			case 'filter':
				$scope.addFilter('tag', $scope.modaldata.tag);
				$modalInstance.close();
                                $scope.searchQuerySolr();
				break;
		}

		if(promise){
                      $scope.loadingTracker.addPromise(promise);
                      promise.then(
    		         function(response) {
    			       $scope.form_disabled = false;
    			       $scope.alerts = response.data.alerts;
    			       $modalInstance.close();
                               $scope.searchQuerySolr();
    		         }
    		        ,function(response) {
    			      $scope.form_disabled = false;
    			      $scope.alerts = response.data.alerts;
    			      $modalInstance.close();
      	                }
                    );
	       }

	       return;

    };

	$scope.cancel = function () {
		$modalInstance.dismiss('cancel');
	};
};

var CreateIngestJobModalCtrl = function ($scope, $modalInstance, FrontendService, JobService, promiseTracker) {

	$scope.modaldata = { name: '', start_at: null, ingest_instance: null};

	$scope.baseurl = $('head base').attr('href');

	$scope.today = function() {
		$scope.modaldata.start_at = new Date();
	};

	// init
	$scope.today();

	$scope.ingestModalInit = function() {
		Object.keys($scope.initdata.ingest_instances).forEach(function (key) {
		    if($scope.initdata.ingest_instances[key].is_default == '1'){
		    	$scope.modaldata.ingest_instance = key;
		    }

		})
	}

	$scope.clear = function () {
		$scope.modaldata.start_at = null;
	};

	$scope.open = function($event) {
	    $event.preventDefault();
	    $event.stopPropagation();

	    $scope.opened = true;
	  };

	$scope.hitEnterCreate = function(evt){
		if(angular.equals(evt.keyCode,13)){
			$scope.createJob();
		}
	};

	$scope.createJob = function () {

		$scope.form_disabled = true;

		var promise = JobService.create($scope.selection, $scope.modaldata);

		$scope.loadingTracker.addPromise(promise);
		promise.then(
			function(response) {
				$scope.form_disabled = false;
				$scope.alerts = response.data.alerts;
				$modalInstance.close();
				window.location = $('head base').attr('href')+'jobs';
			}
			,function(response) {
				$scope.form_disabled = false;
				$scope.alerts = response.data.alerts;
				$modalInstance.close();
	        }
	    );
		return;

	};

	$scope.cancel = function () {
		$modalInstance.dismiss('cancel');
	};
};
