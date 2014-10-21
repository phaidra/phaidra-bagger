app.controller('ClassificationCtrl',  function($scope, $modal, $location, DirectoryService, FrontendService, VocabularyService, JobService, promiseTracker) {
    
	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');
	
	$scope.alerts = [];
	            
	$scope.initdata = '';
	$scope.current_user = '';

	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;	
		$scope.getClassifications();
    	$scope.getMyClassifications();    
    };
    
    $scope.clsns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification';
    
    // TODO: read from user config
    $scope.classes_config = {
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_7': 1,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_5': 2,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_6': 3,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_9': 4,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_1': 5,    	
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_13': 6   	
    };
    
    $scope.lastSelectedTaxons = {};

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
		  		$scope.lastSelectedTaxons[classif.uri] = $scope.findLastSelectedTaxon(classif);
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
	 $scope.findLastSelectedTaxon = function(classif){
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
	 };
	 
	 $scope.removeClassFromObject = function(index){
		 $scope.selectBagClassificationNode().children.splice(index,1); 
		 $scope.save();
	 };
	 
	 $scope.save = function(){
		 $scope.$parent.save(); 
	 };
	 
	 $scope.toggleClassification = function(uri){
		 if(typeof uri == 'undefined'){
			 return;
		 }
		 
		 $scope.form_disabled = true;
	     var promise = FrontendService.toggleClassification(uri);
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;
	      		$scope.getMyClassifications();
	      		$scope.form_disabled = false;
	      	}
	      	,function(response) {
	      		$scope.alerts = response.data.alerts;
	      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
	      		$scope.form_disabled = false;
	      	}
	     );    	
	 };
	 

	 $scope.addClassToObject = function(classif){

		 var taxonpath = { 
             xmlns: $scope.clsns,		 
		     xmlname: "taxonpath",
		     datatype: "Node",
		     children: [
    	       {
		             xmlns: $scope.clsns,
		             xmlname: "source",
		             datatype: "ClassificationSource",
		             ui_value: classif.uri,
		             value_labels: classif.labels
		       }
		    ]
		 };
		 
		 for (var i = 0; i < classif.current_path.length; ++i) {
			 var taxons = classif.current_path[i];
			 if(typeof taxons.selected != 'undefined'){
				 var t = {
				     xmlns: $scope.clsns,		 
				     xmlname: "taxon",
				     datatype: "Taxon",
				 	 ui_value: taxons.selected.uri,
				 	 value_labels: {
					 	labels: taxons.selected.labels,
					 	upstream_identifier: taxons.selected.upstream_identifier,
					 	term_is: taxons.selected.term_id 
					 }
				 
				 };
				 
				 // copy nonpreferred array
				 if(typeof taxons.selected.nonpreferred != 'undefined'){
					 if(taxons.selected.nonpreferred.length > 0){
						 t.value_labels['nonpreferred'] = [];
						 for (var j = 0; j < taxons.selected.nonpreferred.length; ++j) {
							 t.value_labels['nonpreferred'].push(taxons.selected.nonpreferred[j]);
						 }
					 }
				 }
				 
				 
				 taxonpath.children.push(t); 
			 }			 
		 }
		 var ch = $scope.selectBagClassificationNode().children;
		 // -2 because the last two are not taxonpaths but description and keywords
		 ch.splice(ch.length-2,0,taxonpath);	
		 $scope.save();
	 };
	 
	 $scope.getFields = function() {
		 return $scope.$parent.fields;
	 }

	 $scope.getMyClassifications = function() {
		 $scope.form_disabled = true;
	     var promise = FrontendService.getClassifications();
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) { 
	      		$scope.alerts = response.data.alerts;
	      		$scope.myclasses = response.data.classifications;
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
	 

	 $scope.selectBagClassificationNode = function() {		 	
		 return $scope.$parent.fields[6];	 
	 }
	 
 
});
