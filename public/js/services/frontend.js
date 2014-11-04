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
		
		loadSettings: function(){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'settings/my'
			});	        
		},
		
		saveSettings: function(type, settings){
			var data = {};
			data[type+'_settings'] = settings;			
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'settings/',
				data    : data
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