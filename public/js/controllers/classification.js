app.controller('ClassificationCtrl', function($scope, $modal, $location, DirectoryService, FrontendService, VocabularyService, MetadataService, JobService, promiseTracker) {

	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

	$scope.alerts = [];

	$scope.initdata = '';
	$scope.current_user = '';
	
	$scope.mode = 'bagedit_uwmetadata';

	$scope.init = function (initdata, mode) {
		$scope.mode = mode;
		$scope.initdata = angular.fromJson(initdata);
		$scope.current_user = $scope.initdata.current_user;
		$scope.getClassifications();
		$scope.getMyClassifications();
		if(mode == 'bagedit_mods'){
			$scope.getModsBagClassifications();
		}
  };

    $scope.clsns = 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification';

    $scope.lastSelectedTaxons = {};

    $scope.selectedmyclass = {};

    $scope.myclasses = [];

    $scope.searchclasses = [];
    $scope.class_search = {query: ''};

    $scope.class_roots = [];
	$scope.class_roots_all = [];
	
	$scope.mods_bag_classes = [];

	$scope.getModsBagClassifications = function() {
		$scope.form_disabled = true;
	     var promise = MetadataService.getModsBagClassifications($scope.initdata.bagid);
	     $scope.loadingTracker.addPromise(promise);
	     promise.then(
	      function(response) {
	        $scope.form_disabled = false;
	        $scope.mods_bag_classes = [];
	        for (var i = 0; i < response.data.bag_classifications.length; ++i) {
	        	$scope.mods_bag_classes.push(response.data.bag_classifications[i]);	           
	        }
	        $scope.alerts = response.data.alerts;
	      }
	      ,function(response) {
	        $scope.form_disabled = false;
	        $scope.alerts = response.data.alerts;
	       }
	    );
	}

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

							if($scope.initdata['included_classifications']){
								for (var j = 0; j < $scope.initdata.included_classifications.length; ++j) {
										if($scope.initdata.included_classifications[j] == response.data.terms[i].uri){
												$scope.class_roots.push(term);
										}
								}
							}else{
								$scope.class_roots.push(term);
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
		 
		 if($scope.mode == 'bagedit_mods'){
			 var uri = $scope.mods_bag_classes[index].uri;
			 var node2remove_idx = -1;
			 for (var i = 0; i < $scope.$parent.fields.length; ++i) {			 
				 if($scope.$parent.fields[i].xmlname == 'classification'){
					 var cls = $scope.$parent.fields[i]; 
					 var authuri;
					 var valueuri;
					 for (var j = 0; j < cls.attributes.length; ++j) {
						 if(cls.attributes[j].xmlname == 'authorityURI'){
							 authuri = cls.attributes[j].ui_value; 
						 }
						 if(cls.attributes[j].xmlname == 'valueURI'){
							 valueuri = cls.attributes[j].ui_value; 
						 }
					 }
					 if(authuri == 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification' && valueuri == uri){
						 node2remove_idx = i;
						 break;
					 }
				 }
			 }
			 if(node2remove_idx >= 0){
				 $scope.$parent.fields.splice(node2remove_idx, 1);
			 }
			 $scope.save();
			 $scope.getModsBagClassifications();
			 return
		 }
		 
		 if($scope.mode == 'bagedit_uwmetadata'){
			 $scope.selectBagClassificationNode().children.splice(index,1);
			 $scope.save();
		 }
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

	 $scope.selectLastModsClassNodeIdx = function(){
		 
		 var last_idx = 0;
		 for (var i = 0; i < $scope.$parent.fields.length; ++i) {			 
			 if($scope.$parent.fields[i].xmlname == 'classification'){
				 last_idx = i;
			 }else{
				 if(last_idx > 0){
					return last_idx;
				 }
			 }
		 }
		 return last_idx;
	 }

	 $scope.addClassToObjectFromTaxon = function(uri){
		 
		 if($scope.mode == 'bagedit_mods'){
			 var idx = $scope.selectLastModsClassNodeIdx();
			 				 
			 var newnode = {
		            "xmlname":"classification",
		            "input_type":"input_text",
		            "label":"Classification",
		            "attributes":[
		                {
		                    "xmlname":"lang",
		                    "input_type":"input_text",
		                    "label":"Language"
		                },
		                {
		                    "xmlname":"script",
		                    "input_type":"input_text",
		                    "label":"Script"
		                },
		                {
		                    "xmlname":"transliteration",
		                    "input_type":"input_text",
		                    "label":"Transliteration"
		                },
		                {
		                    "xmlname":"authority",
		                    "input_type":"select",
		                    "label":"Authority"
		                },
		                {
		                    "xmlname":"authorityURI",
		                    "input_type":"input_text",
		                    "label":"Authority URI",
		                    "ui_value": 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification'
		                },
		                {
		                    "xmlname":"valueURI",
		                    "input_type":"input_text",
		                    "label":"Value URI",
		                    "ui_value": uri
		                },
		                {
		                    "xmlname":"edition",
		                    "input_type":"input_text",
		                    "label":"Edition"
		                },
		                {
		                    "xmlname":"displayLabel",
		                    "input_type":"input_text",
		                    "label":"Display label"
		                },
		                {
		                    "xmlname":"usage",
		                    "input_type":"select",
		                    "label":"Usage"
		                },
		                {
		                    "xmlname":"generator",
		                    "input_type":"input_text",
		                    "label":"Generator"
		                }
		            ]
		     }; 			 
				 
			 $scope.$parent.fields.splice(idx,0,newnode);
			 $scope.save();
			 $scope.getModsBagClassifications();
			 return;
		 }
		 
		 if($scope.mode == 'bagedit_uwmetadata'){
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
		 }
	 };

	 $scope.addClassToObject = function(classif){

		 if($scope.mode == 'bagedit_mods'){
			 $scope.addClassToObjectFromTaxon($scope.lastSelectedTaxons[classif.uri].uri);
			 $scope.save();
			 $scope.getModsBagClassifications();
			 return;
		 }
		 
		 if($scope.mode == 'bagedit_uwmetadata'){
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
		}
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
	      			var term = response.data.terms[i];
					term.current_path = [];
	      			/*
	      			var pos = $scope.classes_config[response.data.terms[i].uri];	      			
	      			if(pos > 0){
	      				// pos goes from 1
	      				$scope.searchclasses[pos-1] = response.data.terms[i];
	      				$scope.searchclasses[pos-1].terms = response.data.terms[i].terms;
		      			// init current_path array
	      				$scope.searchclasses[pos-1].current_path = [];
	      			}
	      			*/
	      			if($scope.initdata['included_classifications']){
						for (var j = 0; j < $scope.initdata.included_classifications.length; ++j) {
							if($scope.initdata.included_classifications[j] == response.data.terms[i].uri){
								$scope.searchclasses.push(term);
							}
						}
					}else{
						$scope.searchclasses.push(term);
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
