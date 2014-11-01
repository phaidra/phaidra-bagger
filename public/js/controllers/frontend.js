var app = angular.module('frontendApp', ['ngAnimate', 'ngSanitize', 'ui.bootstrap', 'ui.bootstrap.modal', 'ui.bootstrap.datepicker', 'ui.bootstrap.timepicker', 'ui.sortable', 'ui.select', 'ajoslin.promise-tracker', 'directoryService', 'vocabularyService', 'metadataService', 'frontendService', 'bagService', 'jobService', 'Url']);

app.filter("nl2br", function($filter) {
 return function(data) {
   if (!data) return data;
   return data.replace(/\n\r?/g, '<br />');
 };
});

app.controller('FrontendCtrl', function($scope, $window, $modal, $log, DirectoryService, MetadataService, promiseTracker) {
    
	// we will use this to track running ajax requests to show spinner	
	$scope.loadingTracker = promiseTracker.register('loadingTrackerFrontend');
	
    $scope.alerts = [];        
    $scope.query = '';   
    
	$scope.initdata = '';
	$scope.current_user = '';
	
	$scope.user_settings = [];
	$scope.project_settings = [];
			
	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;
		$scope.baseurl = $('head base').attr('href');
    };
    
    $scope.initSettings = function (initdata_settings) {
    	var d = angular.fromJson(initdata_settings);
    	$scope.initdata = d;
		$scope.current_user = d.current_user;
		$scope.baseurl = $('head base').attr('href');
		$scope.user_settings = d.user_settings;
		$scope.project_settings = d.project_settings;
		$scope.getUwmfields();
    };
    
    $scope.getUwmfields = function () {
    	var promise = MetadataService.getUwmetadataTree();
		$scope.loadingTracker.addPromise(promise);
		promise.then(
		  	function(response) { 
		  		$scope.alerts = response.data.alerts;	   
		  		$scope.uwmfields = $scope.getUwmfieldsFromTree(response.data.tree);
		  		$scope.form_disabled = false;		  		
		  	}
		  	,function(response) {
		  		$scope.alerts = response.data.alerts;
		  		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
		   		$scope.form_disabled = false;
		   	}
		);
	};
	
	$scope.defaultAssigneeDisplayName = function() {
		for (var i = 0; i < $scope.project_settings.members.length; ++i) {
			if($scope.project_settings.members[i].username == $scope.project_settings.default_assignee){
				return $scope.project_settings.members[i].displayname;
			}			
		}		
	}
	
	$scope.getUwmfieldsFromTree = function (fields) {
		for (var i = 0; i < fields.length; ++i) {
			
		}		
	};	

    $scope.forceLoadPage = function(link) {
    	$window.location = link;
    };
        
    $scope.hitEnterSearch = function(evt){    	
    	if(angular.equals(evt.keyCode,13) && !(angular.equals($scope.query,null) || angular.equals($scope.query,''))){
    		window.location = $('head base').attr('href')+'search?q='+encodeURIComponent($scope.query);
    	}
    };
    
    $scope.search = function(){    	
    	if(!(angular.equals($scope.query,null) || angular.equals($scope.query,''))){
    		window.location = $('head base').attr('href')+'search?q='+encodeURIComponent($scope.query);
    	}
    };
    
    $scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };
    
    $scope.signin_open = function () {

    	var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/loginform.html',
            controller: SigninModalCtrl
    	});
    };
    
    $scope.init = function () {
    	if($('#signin').attr('data-open') == 1){
    		$scope.signin_open();
    	}
    };
      
});

var SigninModalCtrl = function ($scope, $modalInstance, DirectoryService, FrontendService, promiseTracker) {
		
	$scope.user = {username: '', password: ''};
	$scope.alerts = [];		
	
	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');	

	$scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };
    
    $scope.hitEnterSignin = function(evt){
    	if(angular.equals(evt.keyCode,13) 
    			&& !(angular.equals($scope.user.username,null) || angular.equals($scope.user.username,''))
    			&& !(angular.equals($scope.user.password,null) || angular.equals($scope.user.password,''))
    			)
    	$scope.signin();
    };
    	
	$scope.signin = function () {
		
		$scope.form_disabled = true;
		
		var promise = DirectoryService.signin($scope.user.username, $scope.user.password);		
    	$scope.loadingTracker.addPromise(promise);
    	promise.then(
    		function(response) { 
    			$scope.form_disabled = false;
    			$scope.alerts = response.data.alerts;    			
    			$modalInstance.close();
    			var red = $('#signin').attr('data-redirect');
    			if(red){
    				window.location = red;
    			}else{
    				window.location.reload();
    			}
    		}
    		,function(response) {
    			$scope.form_disabled = false;
    			$scope.alerts = response.data.alerts;
            }
        );
		return;
		
	};

	$scope.cancel = function () {
		$modalInstance.dismiss('cancel');
	};
};


/*
app.run(function(editableOptions) {
  editableOptions.theme = 'bs3';
});
*/
