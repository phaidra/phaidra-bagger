
app.controller('BagsCtrl',  function($scope, $modal, $location, DirectoryService, BagService, FrontendService, promiseTracker) {
    
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
    $scope.filter = '';
    $scope.from = 0;
    $scope.limit = 5;
    $scope.sortfield = 'updated';
    $scope.sortvalue = -1;
    			
	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;
		$scope.folderid = $scope.initdata.folderid;		

		$scope.filter = { folderid: $scope.folderid };
		
    	$scope.refreshResults();
    	
    	if($scope.current_user){
    		$scope.loadSelection();
    	}
    	
    }; 

    $scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };    
    
    $scope.selectNone = function(event){
    	$scope.selection = [];	
    	$scope.saveSelection();
    };
    
    $scope.selectVisible = function(event){
    	$scope.selection = [];	
    	for( var i = 0 ; i < $scope.items.length ; i++ ){	     			
	    	$scope.selection.push($scope.items[i].bagid);
	    }
    	$scope.saveSelection();
    };

    $scope.selectAll = function(event){
	    var promise = BagService.search($scope.filter, 0, 0, $scope.sortfield, $scope.sortvalue);
	    $scope.loadingTracker.addPromise(promise);
	    promise.then(
	     	function(response) { 
	     		$scope.alerts = response.data.alerts;
	     		$scope.selection = [];
	     		for( var i = 0 ; i < response.data.items.length ; i++ ){	     			
	     			$scope.selection.push(response.data.items[i].bagid);
	     		}	
	     		$scope.saveSelection();
	     		return false;
	     	}
	     	,function(response) {
	     		$scope.alerts = response.data.alerts;
	     		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	     		return false;
	     	}
	    );   	    	    
    }
    
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
    	    		    		
    	$scope.refreshResults();
    	
    	$scope.currentPage = page;
    };
  
    
 $scope.refreshResults = function() {
	 $scope.searchBags($scope.filter, $scope.from, $scope.limit, $scope.sortfield, $scope.sortvalue); 
 }
 
 $scope.searchBags = function(filter, from, limit, sortfield, sortvalue) {
	 
     var promise = BagService.search(filter, from, limit, sortfield, sortvalue);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) { 
      		$scope.alerts = response.data.alerts;
      		$scope.items = response.data.items;
      		$scope.totalItems = response.data.hits;
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      	}
     );    	      
 }; 
 
 $scope.addFilter = function (type, value) {
	 if($scope.filter){
		 $scope.filter[type] = value;
		 $scope.refreshResults();
	 }
 }
 
 $scope.toggleSort = function (sortfield, sortvalue) {	 
	 if($scope.sortfield == sortfield){
		 $scope.sortvalue = $scope.sortvalue == 1 ? -1 : 1;
	 }else{
		 $scope.sortvalue = 1;
	 }	 
	 $scope.sortfield = sortfield; 
	 $scope.refreshResults();
 }
 
 $scope.removeFilter = function (type, value) {
	 if($scope.filter){
		 delete $scope.filter[type];
		 $scope.refreshResults();
	 }
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
      		//$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      	}
     );
 } 
 
 $scope.setAttributeMass = function (attribute, value) {
	 var promise = BagService.setAttributeMass($scope.selection, attribute, value);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) { 
      		$scope.alerts = response.data.alerts;
      		$scope.refreshResults();
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		//$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      	}
     );
 } 

 $scope.removeTag = function () {
	 
 }
 
  $scope.editTag = function (add) {

	  var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/define_tag.html',
            controller: TagModalCtrl,
            scope: $scope,
            resolve: {
		      add: function(){
			    return add;
			  }	  
		    }
	  });
  };

  $scope.getMemberDisplayname = function (username) {
	  
	  for( var i = 0 ; i < $scope.initdata.members.length ; i++ ){
		  if($scope.initdata.members[i].username == username){
			  return $scope.initdata.members[i].displayname; 
		  }		  
	  }
	  
  }
  
  $scope.canSetAttribute = function (attribute) {
	  return $scope.initdata.restricted_ops.indexOf('set_'+attribute) == -1 || $scope.current_user.role == 'manager';
  }
  

});

var TagModalCtrl = function ($scope, $modalInstance, FrontendService, BagService, promiseTracker, add) {

	$scope.modaldata = { tag: '' };	
	
	$scope.operation = add ? 'Add' : 'Remove';

    $scope.hitEnterTagEdit = function(evt){
    	if(angular.equals(evt.keyCode,13)){
    		$scope.editTag();
    	}
    };
    	
	$scope.editTag = function () {
		
		$scope.form_disabled = true;

		var promise;
		if(add){
			promise = BagService.setAttributeMass($scope.selection, 'tags', $scope.modaldata.tag);
		}else{
			promise = BagService.unsetAttributeMass($scope.selection, 'tags', $scope.modaldata.tag);
		}		
		
    	$scope.loadingTracker.addPromise(promise);
    	promise.then(
    		function(response) { 
    			$scope.form_disabled = false;
    			$scope.alerts = response.data.alerts;
    			$modalInstance.close();
    			$scope.refreshResults();
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


