var ConfirmDeleteModalCtrl = function ($scope, $modalInstance) {

	$scope.ok = function () {		
		$modalInstance.close();
	};

	$scope.cancel = function () {
		$modalInstance.dismiss('cancel');
	};
};

app.controller('JobsCtrl',  function($scope, $modal, $location, DirectoryService, JobService, promiseTracker) {
    
	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');
	
	$scope.alerts = [];
	
	$scope.jobs = [];        
    
    $scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };
            
	$scope.initdata = '';
	$scope.current_user = '';
			
	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;		
    	$scope.getMyJobs();    	
    };
    
    $scope.deleteJob = function (tid) {

    	var modalInstance = $modal.open({
            jobUrl: $('head base').attr('href')+'views/modals/confirm_delete.html',
            controller: ConfirmDeleteModalCtrl
    	});
    	
    	modalInstance.result.then(function () {
    		var promise = JobService.deleteJob(tid);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
             	function(response) { 
             		$scope.alerts = response.data.alerts;
             		for(var i = 0 ; i < $scope.jobs.length; i++){
             			if($scope.jobs[i]._id == tid){
             				$scope.jobs.splice(i,1);
             			}             			
             		}             		
             		$scope.form_disabled = false;
             	}
             	,function(response) {
             		$scope.alerts = response.data.alerts;
             		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
             		$scope.form_disabled = false;
             	}
            );
	    });
    };	

 $scope.getMyJobs = function() {
	 $scope.form_disabled = true;
     var promise = JobService.getMyJobs();
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) { 
      		$scope.alerts = response.data.alerts;
      		$scope.jobs = response.data.jobs;
      		$scope.form_disabled = false;
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      		$scope.form_disabled = false;
      	}
     );    	      
 };   
       
});


