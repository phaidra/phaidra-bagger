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
                searchSolr: function(from, limit, filter, ranges, sortvalue, sortfield, allowedStatuses, project){
                        return $http({
                                method  : 'GET',
                                url     : $('head base').attr('href')+'search_solr',
                                params  : {from: from, limit: limit, filter: filter, ranges: ranges, sortvalue: sortvalue, sortfield: sortfield, allowedStatuses: allowedStatuses, project: project}
                        });
                },
                search_solr_all: function(filter, ranges, sortvalue, sortfield, allowedStatuses, project){
                        return $http({
                                method  : 'GET',
                                url     : $('head base').attr('href')+'search_solr_all',
                                params  : {filter: filter, ranges: ranges, sortvalue: sortvalue, sortfield: sortfield, allowedStatuses: allowedStatuses, project: project }
                        });
                }
	}
});
