angular.module('vocabularyService', [])
.factory('VocabularyService', function($http) {

	return {
		searchClassifications: function(query){
	    	return $http({
	    		method  : 'GET',
	    		url     : $('head base').attr('href')+'proxy/terms/search/',
	    		params: { q: query }
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
		},

		getTaxonPath: function(uri){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'proxy/terms/taxonpath',
				params: { uri: uri }
			});
		}

	}
});
