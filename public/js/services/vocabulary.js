angular.module('vocabularyService', [])
.factory('VocabularyService', function($http) {
	
	return {
		searchClassifications: function(query){
	    	return $http({
	    		method  : 'POST',
	    		url     : $('head base').attr('href')+'voc/search/'+query
	    	});	        
	    },
	    
	    getMyClassifications: function(){
	    	return $http({
	    		method  : 'GET',
	    		url     : $('head base').attr('href')+'voc/myclasses'
	    	});	        
	    }

	}
});