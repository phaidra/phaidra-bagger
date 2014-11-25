app.controller('GeoCtrl', function($scope, $modal, $location, MetadataService, promiseTracker, uiGmapGoogleMapApi) {

	// we will use this to track running ajax requests to show spinner
	$scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

	$scope.alerts = [];

	$scope.initdata = '';
	$scope.current_user = '';
	$scope.bagid = '';
		
	$scope.placemarks = [];
	
	var placemark_options = { draggable: true, labelContent: '' };
	
	$scope.getMarkerOptions = function (placemark){
		
		var lat = parseFloat(placemark.point.coordinates.latitude).toFixed(5);
		var lng = parseFloat(placemark.point.coordinates.longitude).toFixed(5);
		placemark_options.labelContent = placemark.name + ' (' + lat + ', ' + lng + ')';
		
		return placemark_options;
	}

	$scope.marker_events = {
        dragend: function (marker, eventName, args) {

          $scope.placemarks[marker.key].point.coordinates.latitude = marker.getPosition().lat();
          $scope.placemarks[marker.key].point.coordinates.longitude = marker.getPosition().lng();
          
          marker.options = {
            draggable: true,
            labelContent: marker.getPosition().lat() + ', ' + marker.getPosition().lng(),
          };
        }
    };
    
	
    // uiGmapGoogleMapApi is a promise.
    // The "then" callback function provides the google.maps object.
    uiGmapGoogleMapApi.then(function(maps) {    	
    	$scope.getGeo();
    });    
	
	$scope.addPoint = function (){
		var lat = 48.2;
		var lng = 16.3667;
		var pl =  {	
		    id: $scope.placemarks.length+1,
		    name: '',
		    description: '',
			point: {
				coordinates: {
					latitude: lat,
					longitude: lng
				}															
			},	
			map: {
				center: { latitude: lat, longitude: lng },
				zoom: 8
			}
			
		};
		$scope.placemarks.push(pl);
	}
	
	$scope.addBoundingbox = function (){
		var bb = {
			polygon: {
				outerboundaryis: {
			    	coordinates: [
		  				 {		    	  				
		  					 latitude: '',
		  					 longitude: ''
		  				 },
		   	  			 {		    	  				
		  					 latitude: '',
		  					 longitude: ''
		  				 },
		  				 {		    	  				
		  					 latitude: '',
		  					 longitude: ''
		  				 },
		  				 {		    	  						    	  				 
		  					 latitude: '',
		  					 longitude: ''
		  				 }
		  			]		    						
				}	
			}
		}
		$scope.placemarks.push(bb);
	}

	$scope.initgeo = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
    	$scope.current_user = $scope.initdata.current_user;
    	$scope.bagid = $scope.initdata.bagid;
    	
    };
    
    $scope.refreshMaps = function() {
    	for (i = 0; i < $scope.placemarks.length; ++i) {
			var p = $scope.placemarks[i];
			p.map.refresh(p.point.coordinates);
		} 
    }
    
    $scope.$parent.$watch('geoTabActivated', function(newValue, oldValue) {
    	if(newValue){
    		$scope.refreshMaps();
    	}    	
    });
    
    $scope.getGeo = function() {    	
    	var promise = MetadataService.getGeo($scope.bagid);
        $scope.loadingTracker.addPromise(promise);
        promise.then(
    		function(response) {
    			if(response.data.alerts){
    				$scope.alerts = response.data.alerts;
    			}    			
    			$scope.placemarks = response.data.geo.kml.document.placemark;	
    			for (i = 0; i < $scope.placemarks.length; ++i) {
    				var p = $scope.placemarks[i];
    				p.id = i;
    				if(!p['map']){
	    				p['map'] = { 
	    					center: { latitude: $scope.placemarks[i].point.coordinates.latitude, longitude: $scope.placemarks[i].point.coordinates.longitude },
	    					zoom: 8
	    				}
    				}
    			}    			
    		}
    		,function(response) {
    			if(response.data.alerts){
    				$scope.alerts = response.data.alerts;
           		}           		
           		$scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
           	}
    	);
    }
    

    $scope.removeClassFromObject = function(index){
    	$scope.selectBagClassificationNode().children.splice(index,1);
		$scope.save();
	};

	$scope.save = function() {
    	$scope.form_disabled = true;
    	var geo = {
    		kml: {
    			document: {
    				placemark: $scope.placemarks
    			}    	
    		}    	
    	};
    	
    	var promise = MetadataService.saveGeo($scope.bagid, geo)
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

});
