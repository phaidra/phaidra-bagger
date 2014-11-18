app.controller('ClassificationCtrl',  function($scope, $modal, $location, DirectoryService, FrontendService, VocabularyService, JobService, promiseTracker) {

	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

	$scope.alerts = [];

	$scope.initdata = '';
	$scope.current_user = '';

	$scope.init = function (initdata, mode) {
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;
		$scope.getClassifications();
  	$scope.getMyClassifications();
  };

    $scope.clsns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification';

    // TODO: read from user config
    $scope.classes_config = {
      'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_1': 1,
      'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_3': 2,
      'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_8': 3,
      'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_9': 4,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_7': 5,
    	'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification/cls_5': 6
    };

    $scope.lastSelectedTaxons = {};

    $scope.selectedmyclass = {};

    $scope.myclasses = [];

    $scope.searchclasses = [];
    $scope.class_search = {query: ''};

    $scope.class_roots = [];
		$scope.class_roots_all = [];

    $scope.getClassifications = function() {
		 $scope.form_disabled = true;
	     var promise = VocabularyService.getClassifications();
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) {
	      		$scope.alerts = response.data.alerts;
						$scope.class_roots_all = [];
	      		// filter and order
	      		$scope.class_roots = [];
	      		for (var i = 0; i < response.data.terms.length; ++i) {
							var term = response.data.terms[i];
							term.current_path = [];
	      			var pos = $scope.classes_config[response.data.terms[i].uri];
	      			if(pos > 0){
	      				// pos goes from 1
	      				$scope.class_roots[pos-1] = response.data.terms[i];
		      			// init current_path array
	      				$scope.class_roots[pos-1].current_path = [];
	      			}

							$scope.class_roots_all.push(term);
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

		 if($scope.selectedmyclass.selected){
			 if($scope.selectedmyclass.selected.uri == uri){
				 $scope.selectedmyclass = {};
			 }
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

	 $scope.addClassToObjectFromTaxon = function(uri){

		 $scope.form_disabled = true;
	     var promise = VocabularyService.getTaxonPath(uri);
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) {
	      		$scope.alerts = response.data.alerts;

	      		var taxonpath = {
	      			 xmlns: $scope.clsns,
			   	     xmlname: "taxonpath",
			   	     datatype: "Node",
			   	     children: [
			           {
			   	             xmlns: $scope.clsns,
			   	             xmlname: "source",
			   	             datatype: "ClassificationSource",
			   	             ui_value: response.data.taxonpath[0].uri,
			   	             value_labels: response.data.taxonpath[0].labels
			   	       }
			   	    ]
			   	};

	      		for (var i = 1; i < response.data.taxonpath.length; ++i) {

	      			 var taxondata = response.data.taxonpath[i];

	      			 var t = {
					     xmlns: $scope.clsns,
					     xmlname: "taxon",
					     datatype: "Taxon",
					     ordered: 1,
	      				 data_order: i-1,
					 	 ui_value: taxondata.uri,
					 	 value_labels: {
						 	labels: taxondata.labels,
						 	upstream_identifier: taxondata.upstream_identifier,
						 	term_id: taxondata.term_id
						 }

					 };

	      			 // copy nonpreferred array
					 if(typeof taxondata.nonpreferred != 'undefined'){
						 if(taxondata.nonpreferred.length > 0){
							 t.value_labels['nonpreferred'] = [];
							 for (var j = 0; j < taxondata.nonpreferred.length; ++j) {
								 t.value_labels['nonpreferred'].push(taxondata.nonpreferred[j]);
							 }
						 }
					 }

					 taxonpath.children.push(t);
	      		}

	      		var ch = $scope.selectBagClassificationNode().children;
				// -2 because the last two are not taxonpaths but description and keywords
				ch.splice(ch.length-2,0,taxonpath);
				$scope.save();

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
				     ordered: 1,
				     data_order: i,
				 	 ui_value: taxons.selected.uri,
				 	 value_labels: {
					 	labels: taxons.selected.labels,
					 	upstream_identifier: taxons.selected.upstream_identifier,
					 	term_id: taxons.selected.term_id
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

	 $scope.hitEnterSearch = function(evt){
    	if(angular.equals(evt.keyCode, 13) && !(angular.equals($scope.class_search.query, null) || angular.equals($scope.class_search.query, ''))){
    		$scope.search($scope.class_search.query);
    	}
     };

	 $scope.search = function(query) {
		 $scope.form_disabled = true;
	     var promise = VocabularyService.searchClassifications(query);
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      	function(response) {
	      		$scope.alerts = response.data.alerts;

	      		// filter and order
	      		$scope.searchclasses = [];
	      		for (var i = 0; i < response.data.terms.length; ++i) {
	      			var pos = $scope.classes_config[response.data.terms[i].uri];
	      			if(pos > 0){
	      				// pos goes from 1
	      				$scope.searchclasses[pos-1] = response.data.terms[i];
	      				$scope.searchclasses[pos-1].terms = response.data.terms[i].terms;
		      			// init current_path array
	      				$scope.searchclasses[pos-1].current_path = [];
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


	 $scope.selectBagClassificationNode = function() {
		 return $scope.$parent.fields[6];
	 }

	 $scope.isMyClass = function(uri) {
		 for (var i = 0; i < $scope.myclasses.length; ++i) {
			 if($scope.myclasses[i].uri == uri){
				 return true;
			 }
		 }
		 return false;
	 }


});
