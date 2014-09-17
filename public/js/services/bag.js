angular.module('bagService', [])
.factory('BagService', function($http) {
	
	return {
		
		updateSelection: function(selection){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'selection',
				data    : { selection: selection }
			});	        
		},

		search: function(filter, from, limit, sortfield, sortvalue){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'bags/search',
			    data    : { query: { filter: filter, from: from, limit: limit, sortfield: sortfield, sortvalue: sortvalue } }
			});	        
		},

		setAttribute: function(bagid, attribute, value){
			return $http({
				method  : 'PUT',
				url     : $('head base').attr('href')+'bag/'+bagid+'/'+attribute+'/'+value 
			});	        
		},
		
		unsetAttribute: function(bagid, attribute, value){
			return $http({
				method  : 'DELETE',
				url     : $('head base').attr('href')+'bag/'+bagid+'/'+attribute+'/'+value 
			});	        
		},
		
		setAttributeMass: function(selection, attribute, value){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'bags/set/'+attribute+'/'+value,
				data    : { selection: selection }
			});	        
		},
		
		unsetAttributeMass: function(selection, attribute, value){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'bags/unset/'+attribute+'/'+value,
				data    : { selection: selection }
			});	        
		}
	}
});