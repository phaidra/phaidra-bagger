angular.module('jobService', [])
.factory('JobService', function($http) {
	
	return {
		save: function(jobid, jobdata){
	    	return $http({
	    		method  : 'POST',
	    		url     : $('head base').attr('href')+'job/'+jobid,
	    		data    : { jobdata: jobdata }
	    	});	        
	    },
	    
		'delete': function(jobid){
			return $http({
				method  : 'DELETE',
				url     : $('head base').attr('href')+'job/'+jobid
			});	        
		},
	    
		load: function(jobid){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'job/'+jobid
			});	        
	    },

		create: function(selection, jobdata){
			return $http({
				method  : 'PUT',
				url     : $('head base').attr('href')+'job',
				data    : { selection: selection, jobdata: jobdata }
			});	
		},
		
		getMyJobs: function(){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'jobs/my'
			});	        
		}

	}
});