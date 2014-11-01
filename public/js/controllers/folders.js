
app.controller('FoldersCtrl',  function($scope, $http, $modal, $location, promiseTracker) {
    
	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');
	
	$scope.alerts = [];	
	
	$scope.items = [];
	$scope.importResults = [];
	
	$scope.initdata = '';
	$scope.current_user = '';
    
    $scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };
    			
	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;		
    	$scope.getFolderList();
    };

     $scope.runImport = function() {
    	 var promise = $http({
 	        method  : 'GET',
 		    url     : $('head base').attr('href')+'folders/import'
 		 });	  
 	     $scope.loadingTracker.addPromise(promise);
 	     promise.then(
 	      	function(response) { 
 	      		$scope.importResults = response.data.alerts;	      	      		
 	      		$scope.getFolderList();
 	      	}
 	      	,function(response) {
 	      		$scope.alerts = response.data.alerts;
 	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
 	      	}
 	     ); 
     }
     
     $scope.getFolderList = function() {
	     var promise = $http({
	        method  : 'GET',
		    url     : $('head base').attr('href')+'folders/list'
		 });	  
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;
	      		$scope.items = response.data.items;
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      	}
	     );    	      
     };   
 
 $scope.deactivateFolder = function(folderid) {

  //if(!confirm('Are you sure?')){
  //	  return;
  //}
   
  var promise = $http({
	method  : 'PUT',
    url     : $('head base').attr('href')+'folder/'+folderid+'/deactivate'
  });	  
  $scope.loadingTracker.addPromise(promise);
  promise.then(
   	function(response) { 
   		$scope.alerts = response.data.alerts;
   		
   		// if it was ok, refresh list
   		var promise1 = $http({
	       method  : 'GET',
		   url     : $('head base').attr('href')+'folders/list'
		});	  
	    $scope.loadingTracker.addPromise(promise);
	    promise1.then(
	     	function(response) { 
	     		$scope.alerts = response.data.alerts;
	     		$scope.items = response.data.items;
	     	}
	     	,function(response) {
	     		$scope.alerts = response.data.alerts;
	     		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	     	}
	    );   

   	}
   	,function(response) {
   		$scope.alerts = response.data.alerts;
   		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
   	}
  );  
 };
 
 
});


