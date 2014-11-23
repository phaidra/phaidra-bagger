var ConfirmDeleteModalCtrl = function ($scope, $modalInstance, itemname) {

	$scope.itemname = itemname;

	$scope.itemtype = 'job';

	$scope.ok = function () {
		$modalInstance.close();
	};

	$scope.cancel = function () {
		$modalInstance.dismiss('cancel');
	};
};

app.controller('JobsCtrl',  function($scope, $interval, $modal, $location, DirectoryService, JobService, promiseTracker) {

	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

	$scope.alerts = [];

	$scope.jobs = [];

  $scope.closeAlert = function(index) {
  	$scope.alerts.splice(index, 1);
  };

	$scope.initdata = '';
	$scope.current_user = '';

	$scope.refresh_promise;
	$scope.refresh_cnt = 0;

	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;
		$scope.refreshResults();
		$scope.refresh();
  };

    $scope.deleteJob = function (jobid, jobname) {

    	var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/confirm_delete.html',
            controller: ConfirmDeleteModalCtrl,
            resolve: {
	    		itemname: function(){
			    	return jobname;
			  }
            }

    	});

    	modalInstance.result.then(function () {
    		var promise = JobService.remove(jobid);
            $scope.loadingTracker.addPromise(promise);
            promise.then(
             	function(response) {
             		$scope.alerts = response.data.alerts;
             		for(var i = 0 ; i < $scope.jobs.length; i++){
             			if($scope.jobs[i]._id == jobid){
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

  $scope.refreshResults = function() {
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

  $scope.refresh = function() {

	if($scope.refresh_cnt >= 2){
		$scope.stopRefresh();
	}
	
    $scope.refresh_promise = $interval(function(){
			$scope.refreshResults();
			// the change in status might not be immediately visible
			// we stop refresh first then, when we haven't saw any change in 3 refreshes
			$scope.refresh_cnt++;
			var running_job_found = false;
			for( var i = 0 ; i < $scope.jobs.length ; i++ ){
				if($scope.jobs[i].status == 'running'){
					running_job_found = true;
				}
			}

			if(!running_job_found && $scope.refresh_cnt >= 2){
				$scope.stopRefresh();				
			}

		}, 5000);

  };

  $scope.stopRefresh = function() {
  	if (angular.isDefined($scope.refresh_promise)) {
      $interval.cancel($scope.refresh_promise);
      $scope.refresh_cnt = 0;
    }
  };

  $scope.$on('$destroy', function() {
    // Make sure that the interval is destroyed too
    $scope.stopRefresh();
  });

  $scope.toogleRun = function(jobid) {
	 $scope.form_disabled = true;
     var promise = JobService.toggleRun(jobid);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) {
      		$scope.alerts = response.data.alerts;
			$scope.refresh_cnt = 0;
			$scope.refresh();
      		$scope.form_disabled = false;
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      		$scope.form_disabled = false;
      	}
     );
 };

 $scope.editIngestJob = function (job) {
	  var modalInstance = $modal.open({
          templateUrl: $('head base').attr('href')+'views/modals/edit_ingest_job.html',
          controller: EditIngestJobModalCtrl,
          scope: $scope,
		  resolve: {
		      job: function(){
			    return job;
			  }
		  }
	  });
  }

  $scope.getMemberDisplayname = function (username) {
	  for( var i = 0 ; i < $scope.initdata.members.length ; i++ ){
		  if($scope.initdata.members[i].username == username){
			  return $scope.initdata.members[i].displayname;
		  }
	  }
  }

});

var EditIngestJobModalCtrl = function ($scope, $modalInstance, FrontendService, JobService, promiseTracker, job) {

	$scope.job = job;

	$scope.baseurl = $('head base').attr('href');

	$scope.modaldata = { 
	  name: job.name, 
	  start_at: job.start_at*1000, 
	  ingest_instance: job.ingest_instance, 
	  create_collection: job.create_collection,
	  add_to_collection: job.add_to_collection
	};

	$scope.today = function() {
		$scope.modaldata.start_at = new Date();
	};

	$scope.clear = function () {
		 $scope.modaldata.start_at = null;
	};

	$scope.open = function($event) {
	    $event.preventDefault();
	    $event.stopPropagation();
	    $scope.opened = true;
	};

	$scope.hitEnterSave = function(evt){
		if(angular.equals(evt.keyCode,13)){
			$scope.saveJob();
		}
	};

	$scope.saveJob = function () {

		$scope.form_disabled = true;

		var promise = JobService.save($scope.job._id, $scope.modaldata);

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
