angular.module('vocabularyService', [])
.factory('VocabularyService', function($http) {
	
	return {
		searchClassifications: function(query){
	    	return $http({
	    		method  : 'POST',
	    		url     : $('head base').attr('href')+'terms/search/'+query
	    	});	        
	    },
	    
	    getMyClassifications: function(){
	    	return $http({
	    		method  : 'GET',
	    		url     : $('head base').attr('href')+'terms/myclasses'
	    	});	        
	    },

	    getClassifications: function(){
	    	return $http({
	    		method  : 'GET',
	    		url     : $('head base').attr('href')+'proxy/terms/children',
	    		params: { uri: 'http://phaidra.univie.ac.at/XML/metadata/lom/V1.0/classification'}	    		
	    	});	        
	    },

		getChildren: function(uri){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'proxy/terms/children',
				params: { uri: uri }	    		
			});	        
		}

	}
});