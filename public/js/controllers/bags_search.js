
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

        $scope.solr_query = "";
        $scope.solr_field = "";
        $scope.dublincoreFields = [];
  
        $scope.solr_response = {};
        $scope.facetFieldsStatus = [];
        $scope.filter_send = {};
        $scope.ranges = {};
        $scope.facetRangesCreated = [];
        $scope.facetRangesUpdated = [];
  
  $scope.init = function (initdata) {
	
        $scope.initdata = angular.fromJson(initdata);
	console.log('search initdata:',$scope.initdata);
        $scope.current_user = $scope.initdata.current_user;
	$scope.folderid = $scope.initdata.folderid;

        console.log('search statuses test:',$scope.initdata.statuses);

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
  	//TODO get it from full dublicore later
        var field1 = {};
        field1.value = "assignee";
        field1.label = "assignee";
        $scope.dublincoreFields.push(field1);
        
        var field2 = {};
        field2.value = "label";
        field2.label = "label";
        $scope.dublincoreFields.push(field2);
        
        var field3 = {};
        field3.value = "project";
        field3.label = "project";
        $scope.dublincoreFields.push(field3);
        
        var field4 = {};
        field4.value = "bagid";
        field4.label = "bagid";
        $scope.dublincoreFields.push(field4);
        
        var field5 = {};
        field5.value = "created";
        field5.label = "created";
        $scope.dublincoreFields.push(field5);
        
        var field6 = {};
        field6.value = "file";
        field6.label = "file";
        $scope.dublincoreFields.push(field6);
        
        var field7 = {};
        field7.value = "folderid";
        field7.label = "folderid";
        $scope.dublincoreFields.push(field7);
        
        var field8 = {};
        field8.value = "status";
        field8.label = "status";
        $scope.dublincoreFields.push(field8);
        
        var field9 = {};
        field9.value = "tags";
        field9.label = "tags";
        $scope.dublincoreFields.push(field9);
        
        var field10 = {};
        field10.value = "updated";
        field10.label = "updated";
        $scope.dublincoreFields.push(field10);
        
        var field11 = {};
        field11.value = "dc_rights";
        field11.label = "rights";
        $scope.dublincoreFields.push(field11);

        var field12 = {};
        field12.value = "dc_date";
        field12.label = "date";
        $scope.dublincoreFields.push(field12);
                
        var field13 = {};
        field13.value = "dc_creator";
        field13.label = "creator";
        $scope.dublincoreFields.push(field13);
                
        var field14 = {};
        field14.value = "dc_language";
        field14.label = "language";
        $scope.dublincoreFields.push(field14);
        
        var field15 = {};
        field15.value = "dc_subject";
        field15.label = "subject";
        $scope.dublincoreFields.push(field15);

        var field16 = {};
        field16.value = "dc_description";
        field16.label = "description";
        $scope.dublincoreFields.push(field16);
        
        var field17 = {};
        field17.value = "dc_identifier";
        field17.label = "identifier";
        $scope.dublincoreFields.push(field17);

        var field18 = {};
        field18.value = "dc_relation";
        field18.label = "relation";
        $scope.dublincoreFields.push(field18);
        
        var field19 = {};
        field19.value = "dc_title";
        field19.label = "title";
        $scope.dublincoreFields.push(field19);

        
        var field20 = {};
        field20.value = "dc_publisher";
        field20.label = "publisher";
        $scope.dublincoreFields.push(field20);
        
        
        console.log('search_solr_all  facetRangesCreated:', $scope.facetRangesCreated);
  };

   
   $scope.searchQuerySolr = function() {
           
            console.log('searchQuerySolr solr_query:',$scope.solr_query,'solr_field:',$scope.solr_field, $scope.from, $scope.limit, $scope.sortvalue, $scope.sortfield, allowedStatuses);
            
            console.log('filter123:',$scope.filter);
            
          
            angular.copy($scope.filter, $scope.filter_send);
            $scope.filter_send.solr_query = $scope.solr_query;
            $scope.filter_send.solr_field = $scope.solr_field;
            console.log('filter124:',$scope.filter_send);
            console.log('ranges124:',$scope.ranges);
            
            var allowedStatuses = {};
            if($scope.initdata.statuses){
                  allowedStatuses = angular.toJson($scope.initdata.statuses); 
            }
            
            var promise = FrontendService.search_solr_all($scope.solr_query, $scope.solr_field, $scope.filter_send, $scope.ranges, $scope.sortvalue, $scope.sortfield, allowedStatuses);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
                function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.totalItems = response.data.response.numFound;
                        $scope.facetFieldsStatus = $scope.formatFacets(response.data.facet_counts.facet_fields.status);
                        $scope.facetFieldsAssignee = $scope.formatFacets(response.data.facet_counts.facet_fields.assignee);
                        $scope.facetFieldsLabel = $scope.formatFacets(response.data.facet_counts.facet_fields.label);
                        if(typeof response.data.facet_counts.facet_ranges.test_date !== 'undefined'){
                                 $scope.facetRangesCreated = $scope.formatFacets(response.data.facet_counts.facet_ranges.test_date.counts);
                        }
                        if(typeof response.data.facet_counts.facet_ranges.test_date_updated !== 'undefined'){
                                 $scope.facetRangesUpdated = $scope.formatFacets(response.data.facet_counts.facet_ranges.test_date_updated.counts);
                        }
                        console.log('search_solr_all  facetRangesCreated:', $scope.facetRangesCreated);
                        console.log('search_solr_all  scope.totalItems:', $scope.totalItems);
                        console.log('search_solr_all response.data:', response.data);
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
            console.log('scope.ranges:',$scope.ranges);
            var allowedStatuses = {};
            if($scope.initdata.statuses){
                  allowedStatuses = angular.toJson($scope.initdata.statuses); 
            }
            var promise = FrontendService.searchSolr($scope.solr_query, $scope.solr_field, $scope.from, $scope.limit, $scope.filter_send, $scope.ranges, $scope.sortvalue, $scope.sortfield, allowedStatuses);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
                function(response) {
                        $scope.alerts = response.data.alerts;
                        $scope.solr_response = response.data.response;
                        console.log('searchQuerySolr response.data:',response.data);
                        //$scope.totalItems = response.data.response.numFound;
                        console.log('searchQuerySolr_onePage scope.totalItems:', $scope.totalItems);
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
          console.log('facet',facet);
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
  
  
  $scope.narrowFacet = function(field, query) {
        
      console.log('field77',field);
      console.log('query77',query);
      
      $scope.solr_query = query;
      $scope.solr_field = field;
      $scope.searchQuerySolr();
  }
  

 $scope.addFilter = function (type, value) {
         
         if(typeof type !== 'undefined' ){                
                  $scope.filter[type] = value;
         }
         
         console.log('solr_response.docs after:',$scope.solr_response.docs);
         console.log('filter3333:',$scope.filter); 
        
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
                 $scope.solr_query = '';
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

     console.log('setAttribute::bag.bagid, attribute, value:1',bag.bagid,':2', attribute,':3', value);
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
            $scope.filter_send.solr_query = $scope.solr_query;
            $scope.filter_send.solr_field = $scope.solr_field;
            var promise = FrontendService.search_solr_all($scope.solr_query, $scope.solr_field, $scope.filter_send, $scope.ranges, $scope.sortvalue, $scope.sortfield);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
                function(response) {
                        $scope.selection = [];
                        for( var i = 0 ; i < response.data.docs.length ; i++ ){
                                $scope.selection.push(response.data.docs[i].bagid);
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
				console.log('modaldata.tag',$scope.modaldata.tag);
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
