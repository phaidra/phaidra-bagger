angular.module('frontendService', [])
.factory('FrontendService', function($http) {
	
	return {
		
		updateSelection: function(selection){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'selection',
				data    : { selection: selection }
			});	        
		},
		
		getSelection: function(selection){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'selection'
			});	        
		},
		
		loadSettings: function(type){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'settings/'+type
			});	        
		},
		
		saveSettings: function(type, settings){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'settings/'+type,
				data    : { settings: settings }
			});	        
		},
		
		toggleClassification: function(uri){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'classifications',
				data    : { uri: uri }
			});	        
		},

		getClassifications: function(terms){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'classifications'
			});	        
		}

	}
});