app.controller('ClassificationCtrl',  function($scope, $modal, $location, DirectoryService, VocabularyService, JobService, promiseTracker) {
    
	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');
	
	$scope.alerts = [];
	            
	$scope.initdata = '';
	$scope.current_user = '';
	
	$scope.bag_classes = [];

	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;		
		//$scope.selectBagClassifications();
		$scope.getClassifications();
    	//$scope.getMyClassifications();    
    };
    
    // TODO: read from user config
    $scope.classes_config = {
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_7': 1,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_5': 2,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_6': 3,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_9': 4,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_1': 5,    	
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_13': 6   	
    };
    

    $scope.selectedmyclass = {};
    
    $scope.myclasses = [];
    
    $scope.searchclasses = [];
    
    $scope.class_roots = [];

    $scope.getClassifications = function() {
		 $scope.form_disabled = true;
	     var promise = VocabularyService.getClassifications();
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;	      		
	      		
	      		// filter and order
	      		$scope.class_roots = [];
	      		for (var i = 0; i < response.data.terms.length; ++i) {
	      			var pos = $scope.classes_config[response.data.terms[i].uri];
	      			if(pos > 0){	      				
	      				// pos goes from 1
	      				$scope.class_roots[pos-1] = response.data.terms[i];
		      			// init current_path array
	      				$scope.class_roots[pos-1].current_path = [];

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
	 };
	 
	 $scope.browse_class_opened = function(classif){
		 
		 if(classif.current_path.length == 0){			 
			 // init the classification
			 classif.current_path = [];
			 var promise = VocabularyService.getChildren(classif.uri);
		     $scope.loadingTracker.addPromise(promise);
		     promise.then(
		      	function(response) { 
		      		$scope.alerts = response.data.alerts;	   
		      		classif.current_path.push({terms: response.data.terms});
		      		$scope.form_disabled = false;
		      	}
		      	,function(response) {
		      		$scope.alerts = response.data.alerts;
		      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
		      		$scope.form_disabled = false;
		      	}
		    );    			 
		 }
	 }
	 
	 $scope.update_current_path = function(item, model, classif, index){
		 		 
		 if(classif.current_path.length > 1){
		 	 classif.current_path.splice(index+1, classif.current_path.length-index);
		 }
				 
		var promise = VocabularyService.getChildren(model.uri);
		$scope.loadingTracker.addPromise(promise);
		promise.then(
		  	function(response) { 
		  		$scope.alerts = response.data.alerts;	   
		  		if(response.data.terms.length > 0){
		  			classif.current_path.push({terms: response.data.terms});
		  		}			      		
		  		$scope.form_disabled = false;		  		
		  	}
		  	,function(response) {
		  		$scope.alerts = response.data.alerts;
		  		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
		   		$scope.form_disabled = false;
		   	}
		);			     
		

	 };
	 
	 // supersafe (and superstupid)
	 $scope.getLastSelectedTaxon = function(classif){
		 var last = classif.current_path[classif.current_path.length-1];		 
		 if(typeof last === 'undefined'){
			 return {};			 
		 }else{					 
			 if(typeof last.selected === 'undefined'){
				var onebefore = classif.current_path[classif.current_path.length-2];
				if(typeof onebefore === 'undefined'){
					return {};
				}else{
					return typeof onebefore.selected === 'undefined' ? {} : onebefore.selected; 
				}
			 }else{
				 return last.selected;
			 }			
		}
	 }

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
	 

	 $scope.selectBagClassifications = function(nodes) {  	
    	 for (var i = 0; i < nodes.length; ++i) {
    		if(nodes[i].xmlns == 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0' && nodes[i].xmlname == 'taxonpath'){
    			$scope.bag_classes.push(nodes[i]);
    		}
    		if(nodes[i].children){
    			$scope.selectBagClassifications(nodes[i].children);
    		}
    	}	 
	 }
	 
 
});
