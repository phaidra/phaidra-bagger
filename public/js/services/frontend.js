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

		getClassifications: function(){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'classifications'
			});
		},
                searchSolr: function(query, field, from, limit, filter, ranges, sortvalue, sortfield, allowedStatuses){
                        return $http({
                                method  : 'GET',
                                url     : $('head base').attr('href')+'search_solr',
                                params  : { query: query, field: field, from: from, limit: limit, filter: filter, ranges: ranges, sortvalue: sortvalue, sortfield: sortfield, allowedStatuses: allowedStatuses}
                        });
                },
                search_solr_all: function(query, field, filter, ranges, sortvalue, sortfield, allowedStatuses){
                        return $http({
                                method  : 'GET',
                                url     : $('head base').attr('href')+'search_solr_all',
                                params  : { query: query, field: field, filter: filter, ranges: ranges, sortvalue: sortvalue, sortfield: sortfield, allowedStatuses: allowedStatuses }
                        });
                }
	}
});
