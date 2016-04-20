
app.controller('JobCtrl',  function($scope, $modal, $location, DirectoryService, JobService, BagService, promiseTracker) {
    
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');	
	$scope.alerts = [];	
	$scope.items = [];
	$scope.jobid = '';      
    $scope.job;    

	$scope.selection = [];
	
	$scope.totalItems = 0;
    $scope.currentPage = 1;
    $scope.maxSize = 300;
    $scope.filter = '';
    $scope.from = 0;
    $scope.limit = 200;
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
        $scope.loadJob($scope.jobid);
    };

    $scope.selectNone = function(event){
        $scope.selection = [];
    };

    $scope.selectVisible = function(event){
        $scope.selection = [];
        for( var i = 0 ; i < $scope.items.length ; i++ ){
            $scope.selection.push($scope.items[i].bagid);
        }
    };

    $scope.selectAll = function(event){   
        var promise = BagService.searchJobBags($scope.jobid, 0, 0, $scope.sortfield, $scope.sortvalue);
	    $scope.loadingTracker.addPromise(promise);
	    promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;
	      		$scope.selection = [];
                for( var i = 0 ; i < response.data.items.length ; i++ ){
                    $scope.selection.push(response.data.items[i].bagid);
                }	      		
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      	}
	     );    	      
    }

    $scope.toggleBag = function(bagid) {
        var idx = $scope.selection.indexOf(bagid);
        if(idx == -1){
                $scope.selection.push(bagid);
        }else{
                $scope.selection.splice(idx,1);
        }
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

 $scope.createMdupdateJob = function () {
          var modalInstance = $modal.open({
          templateUrl: $('head base').attr('href')+'views/modals/create_mdupdate_job.html',
          controller: CreateMdupdateJobModalCtrl,
          scope: $scope
          });
 }

 $scope.loadJob = function(jobid) {
     
         var promise = JobService.load(jobid);
         $scope.loadingTracker.addPromise(promise);
         promise.then(
            function(response) { 
                $scope.alerts = response.data.alerts;
                $scope.job = response.data.job;
                $scope.totalItems = response.data.hits;
            }
            ,function(response) {
                $scope.alerts = response.data.alerts;
                $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
            }
         );           
 };

 var CreateMdupdateJobModalCtrl = function ($scope, $modalInstance, FrontendService, JobService, promiseTracker) {

        $scope.modaldata = { name: '', start_at: null, ingest_job: $scope.job};

        $scope.baseurl = $('head base').attr('href');

        $scope.today = function() {
            $scope.modaldata.start_at = new Date();
        };

        // init
        $scope.today();

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
                        $scope.createUpdateJob();
                }
        };

        $scope.createUpdateJob = function () {

                $scope.form_disabled = true;

                var promise = JobService.createMetadataUpdateJob($scope.selection, $scope.modaldata);

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

        
});
