app.controller('ClassificationCtrl',  function($scope, $modal, $location, DirectoryService, VocabularyService, JobService, promiseTracker) {
    
	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');
	
	$scope.alerts = [];
	            
	$scope.initdata = '';
	$scope.current_user = '';
			
	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;		
    	//$scope.getMyClassifications();    	
    };

    $scope.selectedclass = {};
    $scope.myclasses = [
	    { label: 'Adam',      uri: 'adam@email.com' },
	    { label: 'Amalie',    uri: 'amalie@email.com' },
	    { label: 'Wladimir',  uri: 'wladimir@email.com' },
	    { label: 'Samantha',  uri: 'samantha@email.com' },
	    { label: 'Estefanía', uri: 'estefanía@email.com' },
	    { label: 'Natasha',   uri: 'natasha@email.com' },
	    { label: 'Nicole',    uri: 'nicole@email.com' },
	    { label: 'Adrian',    uri: 'adrian@email.com' }
	];
    
    $scope.searchclasses = [
	    { label: 'Adam',      uri: 'adam@email.com' },
	    { label: 'Amalie',    uri: 'amalie@email.com' },
	    { label: 'Wladimir',  uri: 'wladimir@email.com' },
	    { label: 'Samantha',  uri: 'samantha@email.com' },
	    { label: 'Estefanía', uri: 'estefanía@email.com' },
	    { label: 'Natasha',   uri: 'natasha@email.com' },
	    { label: 'Nicole',    uri: 'nicole@email.com' },
	    { label: 'Adrian',    uri: 'adrian@email.com' }
	];
    
    $scope.browseclasses = [
	    { label: 'Adam',      uri: 'adam@email.com' },
	    { label: 'Amalie',    uri: 'amalie@email.com' },
	    { label: 'Wladimir',  uri: 'wladimir@email.com' },
	    { label: 'Samantha',  uri: 'samantha@email.com' },
	    { label: 'Estefanía', uri: 'estefanía@email.com' },
	    { label: 'Natasha',   uri: 'natasha@email.com' },
	    { label: 'Nicole',    uri: 'nicole@email.com' },
	    { label: 'Adrian',    uri: 'adrian@email.com' }
	];
    

	 $scope.getMyClassifications = function() {
		 $scope.form_disabled = true;
	     var promise = VocabularyService.getMyClassifications();
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;
	      		$scope.myclasses = response.data.entries;
	      		$scope.form_disabled = false;
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      		$scope.form_disabled = false;
	      	}
	     );    	      
	 };
   
	 $scope.search = function(query) {
		 $scope.form_disabled = true;
	     var promise = VocabularyService.searchClassifications(query);
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;
	      		$scope.searchclasses = response.data.entries;
	      		$scope.form_disabled = false;
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      		$scope.form_disabled = false;
	      	}
	     );    	      
	 };
	 
	 $scope.getBagClassifications = function(){
		 
	 };
	 
 
 
});
