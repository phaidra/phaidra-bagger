
app.controller('JobCtrl',  function($scope, $modal, $location, DirectoryService, JobService, BagService, promiseTracker) {
    
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');	
	$scope.alerts = [];	
	$scope.items = [];
	$scope.jobid = '';      
	
	$scope.totalItems = 0;
    $scope.currentPage = 1;
    $scope.maxSize = 10;
    $scope.filter = '';
    $scope.from = 0;
    $scope.limit = 5;
    $scope.sortfield = '';
    $scope.sortvalue = -1;
            
	$scope.initdata = '';
	$scope.current_user = '';

    $scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };	

	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;
		$scope.jobid = $scope.initdata.jobid;
		$scope.refreshResults();
    };
    
    $scope.refreshResults = function() {
    	$scope.searchJobBags($scope.jobid, $scope.from, $scope.limit, $scope.sortfield, $scope.sortvalue); 
    }
    
    $scope.setPage = function (page) {
    	if(page == 1){
			$scope.from = 0;
		}else{    		
			$scope.from = (page-1)*$scope.limit;
		}
    	    		    		
    	$scope.refreshResults();
    	
    	$scope.currentPage = page;
    };
  
    $scope.searchJobBags = function(jobid, from, limit, sortfield, sortvalue) {
	 
	     var promise = BagService.searchJobBags(jobid, from, limit, sortfield, sortvalue);
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
        
});
