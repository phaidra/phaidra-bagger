angular.module('bagService', [])
.factory('BagService', function($http) {
	
	return {
		
		updateSelection: function(selection){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'selection',
				data  : { selection: selection }
			});	        
		},
				
		getUserBags: function(){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'bags/my'
			});	        
		}
	}
});