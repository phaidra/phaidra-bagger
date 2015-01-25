
app.controller('ModseditorCtrl',  function($scope, $modal, $location, DirectoryService, MetadataService, FrontendService, BagService, promiseTracker, Url) {

	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

	$scope.default_helptext = 'Loading tooltip content...';

	// used to disable the form and it's controls on save
	$scope.form_disabled = false;

	$scope.initdata = '';
	$scope.current_user = '';
	$scope.current_bags_query = '';

	$scope.selectedtemplate = '';
	$scope.templatetitle = '';
	$scope.tid = '';

	$scope.bagid = '';
	$scope.bag = [];
	$scope.bag_info;

	$scope.mode = 'bag';

    $scope.fields = [];
    $scope.vocs = [];
    $scope.vocsmap = [];
    $scope.separateTabs = ["originInfo", "physicalDescription", "subject", "part", "recordInfo"];
    $scope.languages = [];
	$scope.geo = [];

    $scope.pid = '';
    $scope.alerts = [];

    $scope.closeAlert = function(index) {
    	$scope.alerts.splice(index, 1);
    };

    $scope.init = function (initdata) {
    	$scope.initdata = angular.fromJson(initdata);
    	$scope.current_user = $scope.initdata.current_user;
    	$scope.bagid = $scope.initdata.bagid;
		$scope.baginfo = $scope.initdata.baginfo;

    	if($scope.initdata.bagid){
        $scope.mode = 'bag';
    		$scope.bagid = $scope.initdata.bagid;
			$scope.bagid = $scope.initdata.bagid;
    		$scope.loadBag();
    	}else{
    		if($scope.initdata.tid){
    			$scope.mode = 'template';
    			$scope.tid = $scope.initdata.tid;
    			$scope.loadTemplate($scope.tid);
    		}else{
    			$scope.mode = 'template';
    			$scope.getModsTree();
    		}
    	}
    };

		$scope.getMemberDisplayname = function (username) {
			for( var i = 0 ; i < $scope.initdata.members.length ; i++ ){
				if($scope.initdata.members[i].username == username){
					return $scope.initdata.members[i].displayname;
				}
			}
		}

		$scope.canSetAttribute = function (attribute) {
			return $scope.initdata.restricted_ops.indexOf('set_'+attribute) == -1 || $scope.current_user.role == 'manager';
		}

		$scope.setAttribute = function (bag, attribute, value) {
			var promise = BagService.setAttribute(bag.bagid, attribute, value);
				$scope.loadingTracker.addPromise(promise);
				promise.then(
					function(response) {
						$scope.alerts = response.data.alerts;
						$scope.baginfo[attribute] = value;
					}
					,function(response) {
						$scope.alerts = response.data.alerts;
						//$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
					}
				);
		}

		$scope.getFieldsCount = function() {
				return $scope.fields.length;
		};

    $scope.getBack2BagsLink = function (){
    	if($scope.initdata.current_bags_query){
    		if($scope.initdata.current_bags_query.filter){
    			if($scope.initdata.current_bags_query.filter.folderid){
    				return Url.buildUrl($('head base').attr('href')+'bags/folder/'+$scope.initdata.current_bags_query.filter.folderid, $scope.initdata.current_bags_query);
    			}
    		}
    	}
    }

    $scope.getPrevBagLink = function (){
    	if($scope.initdata.prev_bag){
    		return Url.buildUrl($('head base').attr('href')+'bag/'+$scope.initdata.prev_bag.bagid+'/edit', $scope.initdata.current_bags_query);
    	}
    }

    $scope.getNextBagLink = function (){
    	if($scope.initdata.next_bag){
    		return Url.buildUrl($('head base').attr('href')+'bag/'+$scope.initdata.next_bag.bagid+'/edit', $scope.initdata.current_bags_query);
    	}
    }

    $scope.reset_values = function (node, default_value){
    	if(!default_value){
    		default_value = '';
    	}
    	node.ui_value = default_value;
    	node.loaded_ui_value = default_value;
    	node.value = default_value;
    	node.loaded_value = default_value;
    }
   
    $scope.load_init = function(){


    };

    $scope.resetEditor = function() {
    	$scope.alerts = [];
		$scope.languages = [];
		$scope.fields = [];
    };

    $scope.getModsTree = function(){
    	$scope.resetEditor();
        var promise = MetadataService.getModsTree();
        $scope.loadingTracker.addPromise(promise);
        promise.then(
    		function(response) {
    			$scope.alerts = response.data.alerts;
    			$scope.languages = response.data.languages;
    			$scope.fields = response.data.tree;
    			$scope.vocs = response.data.vocabularies;
    			$scope.vocsmap = response.data.vocabularies_mapping;
    			$scope.load_init();
    		}
    		,function(response) {
           		$scope.alerts = response.data.alerts;
           		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
           	}
    	);
    };

    $scope.loadBag = function(){
    	$scope.resetEditor();
        var promise = MetadataService.loadBag($scope.bagid);
        $scope.loadingTracker.addPromise(promise);
        promise.then(
    		function(response) {
    			$scope.alerts = response.data.alerts;
    			$scope.languages = response.data.metadata.languages;
    			$scope.fields = response.data.metadata.mods;
    			$scope.bag = response.data;
    			$scope.load_init();
    		}
    		,function(response) {
           		$scope.alerts = response.data.alerts;
           		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
           	}
    	);
    };

 $scope.save = function() {
    	$scope.form_disabled = true;
    	var promise = MetadataService.saveModsToBag($scope.bagid, $scope.fields)
    	$scope.loadingTracker.addPromise(promise);
    	promise.then(
        	function(response) {
        		$scope.alerts = response.data.alerts;
        		$scope.form_disabled = false;
        	}
        	,function(response) {
           		$scope.alerts = response.data.alerts;
           		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
           		$scope.form_disabled = false;
           	}
        );

 };

 $scope.saveTemplate = function() {
	 $scope.form_disabled = true;
     var promise = MetadataService.saveModsTemplate($scope.tid, $scope.fields);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.form_disabled = false;
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      		$scope.form_disabled = false;
      	}
     );
 };

 $scope.loadTemplateToBag = function() {
	 $scope.form_disabled = true;
     var promise = MetadataService.loadTemplateToBag(this.selectedtemplate._id);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.fields = response.data.mods;
      		$scope.templatetitle = response.data.title;      		
      		$scope.languages = response.data.languages;
			$scope.vocs = response.data.vocabularies;
			$scope.vocsmap = response.data.vocabularies_mapping;
      		$scope.form_disabled = false;
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      		$scope.form_disabled = false;
      	}
     );
 };

  $scope.loadTemplate = function() {
	 $scope.form_disabled = true;
     var promise = MetadataService.loadTemplate($scope.tid);
     $scope.loadingTracker.addPromise(promise);
     promise.then(
      	function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.fields = response.data.mods;
      		$scope.templatetitle = response.data.title;
      		$scope.languages = response.data.languages;
			$scope.vocs = response.data.vocabularies;
			$scope.vocsmap = response.data.vocabularies_mapping;
      		$scope.form_disabled = false;
      	}
      	,function(response) {
      		$scope.alerts = response.data.alerts;
      		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
      		$scope.form_disabled = false;
      	}
     );
 };


$scope.saveTemplateAs = function () {

    var templateModalInstance = $modal.open({
      templateUrl: 'save_template_modal.html',
      controller: TemplateModalInstanceCtrl,
      resolve: {
        currenttitle: function () {
          return $scope.templatetitle;
        }
      }
    });

    templateModalInstance.result.then(function (title) {
      $scope.templatetitle = title;

      // save template
      $scope.form_disabled = true;
      var promise = MetadataService.saveModsTemplateAs($scope.templatetitle, $scope.fields);
      $scope.loadingTracker.addPromise(promise);
      promise.then(
       	function(response) {
       		$scope.alerts = response.data.alerts;
       		$scope.tid = response.data.tid;
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

    // used to filter array of elements: if 'hidden' is set, the field will not be included in the array
    $scope.filterHidden = function(e)
    {
        return $scope.mode == 'template' ? !e.hidden : !e.hidden && !e.hide;
    };


    $scope.canDelete = function(child, parent){
    	var a = [];
    	if(parent){
    		a = parent.children;
    	}else{
    		a = $scope.fields;
    	}
    	
    	var cnt = 0;
    	for (i = 0; i < a.length; ++i) {
    		if(a[i].xmlns == child.xmlns && a[i].xmlname == child.xmlname){
    			cnt++;
    		}
    	}
    	return cnt > 1;
    }

    $scope.addNewElement = function(child, parent){
    	// array of elements to which we are going to insert
    	var arr = [];
    	if(parent){
    		arr = parent.children;
    	}else{
    		arr = $scope.fields;
    	}
    	// copy the element
    	var tobesistr = angular.copy(child);
    	// get index of the current element in this array
    	var idx = angular.element.inArray(child, arr); // we loaded jQuery before angular so angular.element should equal jQuery
    	// increment order of the new element (we are appending to the current one)
    	// and also all the next elements
    	// but only if the elements are actually ordered
    	if(child.ordered){
    		tobesistr.data_order++;
    		var i;
        	for (i = idx+1; i < arr.length; ++i) {
        		// update only elements of the same type
        		if(arr[i].xmlns == child.xmlns && arr[i].xmlname == child.xmlname){
        			arr[i].data_order++;
        		}
        	}
    	}
    	// insert into array at specified index, angular will sort the rest out
    	arr.splice(idx+1, 0, tobesistr);
    	
    }

    $scope.deleteElement = function(child, parent){
    	// array of elements where we are going to delete
    	var arr = [];
    	if(parent){
    		arr = parent.children;
    	}else{
    		arr = $scope.fields;
    	}
    	// get index of the current element in this array
    	var idx = angular.element.inArray(child, arr); // we loaded jQuery before angular so angular.element should equal jQuery
    	// decrement data_order of remaining elements
    	if(child.ordered){
	    	var i;
	    	for (i = idx+1; i < arr.length; ++i) {
	    		// update only elements of the same type
        		if(arr[i].xmlns == child.xmlns && arr[i].xmlname == child.xmlname){
        			arr[i].data_order--;
        		}
	    	}
    	}
    	// delete
    	arr.splice(idx, 1);
    }

    Array.prototype.move = function(from, to) {
        this.splice(to, 0, this.splice(from, 1)[0]);
    };

    $scope.upElement = function(child, parent){
    	// array of elements which we are going to rearrange
    	var arr = [];
    	if(parent){
    		arr = parent.children;
    	}else{
    		arr = $scope.fields;
    	}
    	// get index of the current element in this array
    	var idx = angular.element.inArray(child, arr);

    	// update the data_order property
    	if(child.ordered){
	    	child.data_order--;
	    	// only if it's the same type (should be always true
	    	// because we are checking this in canUpElement)
    		if(arr[idx-1].xmlns == child.xmlns && arr[idx-1].xmlname == child.xmlname){
    			arr[idx-1].data_order++;
    		}
    	}

    	// move to index--
    	if(idx > 0){
    		arr.move(idx, idx-1);
    	}
    }

    $scope.downElement = function(child, parent){
    	// array of elements which we are going to rearrange
    	var arr = [];
    	if(parent){
    		arr = parent.children;
    	}else{
    		arr = $scope.fields;
    	}
    	// get index of the current element in this array
    	var idx = angular.element.inArray(child, arr);

    	// update the data_order property
    	if(child.ordered){
	    	child.data_order++;
	    	// only if it's the same type (should be always true
	    	// because we are checking this in canDownElement)
    		if(arr[idx+1].xmlns == child.xmlns && arr[idx+1].xmlname == child.xmlname){
    			arr[idx+1].data_order--;
    		}
    	}

    	// move to index++
    	arr.move(idx, idx+1);
    }

    $scope.canUpElement = function(child, parent){
    	return child.ordered && (child.data_order > 0);
    }

    $scope.canDownElement = function(child, parent){

    	if(!child.ordered){ return false; }

    	// this array can contain also another type of elements
    	// but we only order the same type, so find if there is
    	// an element of the same type with higher data_ordered
    	var arr = [];
    	if(parent){
    		arr = parent.children;
    	}else{
    		arr = $scope.fields;
    	}
    	
	    var i;
	    for (i = 0; i < arr.length; ++i) {
	        if(arr[i].data_order > child.data_order){
	        	return true;
	        }
	    }

	    return false;

    }

    // hacky bullshit to make the map refresh on geo tab select
    // this var is watched in geo controller
    $scope.geoTabActivated = false;
    $scope.triggerGeoTabActivated = function (){
    	$scope.geoTabActivated = true;
    }

    $scope.hasLangAttr = function(child){
    	return $scope.getLangAttrNodeIdx == -1 ? false : true;
    }
    
    $scope.getLangAttrNodeIdx = function(child){
    	if(child.attributes){
    		for (var i = 0; i < child.attributes.length; ++i) {
    			if(child.attributes[i].xmlname == 'lang'){
    				return i;
    			}
    		}
    	}
    	return -1;
    }
    
    $scope.getVocLabel = function(value){
    	return value;
    	//return value.charAt(0).toUpperCase() + value.slice(1);
    }
});

var TemplateModalInstanceCtrl = function ($scope, $modalInstance, currenttitle) {

  $scope.currenttitle = currenttitle;

  $scope.newtemplatetitle = { value: currenttitle };

  $scope.ok = function () {
	  $modalInstance.close($scope.newtemplatetitle.value);
  };

  $scope.cancel = function () {
	  $modalInstance.dismiss('cancel');
  };
};


// lazy binding
(function($){
    $.fn.lazybind = function(event, fn, timeout, abort){
        var timer = null;
        $(this).bind(event, function(e){
            var ev = e;
            timer = setTimeout(function(){
                fn(ev);
            }, timeout);
        });
        if(abort == undefined){
            return;
        }
        $(this).bind(abort, function(){
            if(timer != null){
                clearTimeout(timer);
            }
        });
    };
})(jQuery);

// load tooltip content on demand
app.directive('phaidraHelp', function($http, $timeout) {
	 return {
	  restrict: 'A',

	  link: function(scope, element, attr) {

	      // the tooltip is shown after some delay
	      // and we also don't want to load the content
		  // when user just crossed the field with a mouse
		  // so we are going to load it on mouseover, but only
		  // if user stays hier a while (see, if mouseout before, it will be cancelled)
		  // BUT, we want the content to be loaded before the tooltip shows
		  // otherwise it will be wrong positioned because of the changed content
		  // (and correctly positioned only on second hover)
		  // + we need to call $scope.$apply
		  element.lazybind('mouseover',function(e) {

			  // this will make the tooltip realize it has a new content
			  // so if the new content is already there, it will be correctly positioned
			  scope.$apply(function(e) {

				  if(attr['loaded']){
					  return;
				  }

		          var promise = $http({
			          method  : 'GET',
			          url     : $('head base').attr('href')+'proxy/get_help_tooltip',
			          params  : { id: attr['phaidraHelpId']  }
			      });
			      scope.loadingTracker.addPromise(promise);
			      promise.then(
			  		function(response) {

			  			attr.$set('tooltipHtmlUnsafe', response.data.content);
			  			attr.$set('loaded', true);

			   		}
			   		,function(response) {
			   			attr.$set('tooltipHtmlUnsafe', "Failed to load tooltip");
			       	}
			   	  );

			  });
		  }, 1000, 'mouseout' );
	   }
	 }
});
