angular.module('metadataService', [])
.factory('MetadataService', function($http) {

	return {
		getUwmetadataFromObject: function(pid) {
	         //return the promise directly.
	         return $http({
	             method  : 'GET',
	             url     : $('head base').attr('href')+'proxy/get_object_uwmetadata/'+pid
	         	//headers : are by default application/json
	         });
	    },

	    loadBag: function(bagid) {
	        return $http({
	            method  : 'GET',
	            url     : $('head base').attr('href')+'bag/'+bagid
	        });
	    },

		getUwmetadataTree: function() {
	        return $http({
	            method  : 'GET',
	            url     : $('head base').attr('href')+'bag/uwmetadata/tree'
	        });
	    },
	    
	    getModsTree: function() {
	        return $http({
	            method  : 'GET',
	            url     : $('head base').attr('href')+'bag/mods/tree'
	        });
	    },

	    getGeo: function(bagid) {
	        return $http({
	            method  : 'GET',
	            url     : $('head base').attr('href')+'bag/'+bagid+'/geo'
	        });
	    },

		saveGeo: function(bagid, geo){
			   return $http({
				   method  : 'POST',
				   url     : $('head base').attr('href')+'bag/'+bagid+'/geo/',
				   data    : { geo: geo }
			   });
		},

		getLanguages: function() {
	        return $http({
	            method  : 'GET',
	            url     : $('head base').attr('href')+'proxy/get_uwmetadata_languages'
	        });
	    },

	    saveUwmetadataToObject: function(pid, uwmetadata){
		   return $http({
			   method  : 'POST',
	           url     : $('head base').attr('href')+'proxy/save_object_uwmetadata/'+pid,
	           data    : { uwmetadata: uwmetadata }
		   });
	    },

		saveUwmetadataToBag: function(bagid, uwmetadata){
			   return $http({
				   method  : 'POST',
		        url     : $('head base').attr('href')+'bag/'+bagid+'/uwmetadata/',
		        data    : { uwmetadata: uwmetadata }
			   });
		 },
		 
		saveModsToBag: function(bagid, mods){
			   return $http({
				   method  : 'POST',
		     url     : $('head base').attr('href')+'bag/'+bagid+'/mods/',
		     data    : { mods: mods }
			   });
		},

	    saveTemplateAs: function(title, uwmetadata){
		   return $http({
			   method  : 'PUT',
	           url     : $('head base').attr('href')+'template',
	           data    : { title: title, uwmetadata: uwmetadata }
		   });
	    },

	    saveTemplate: function(tid, uwmetadata){
	    	return $http({
	    		method  : 'POST',
	    		url     : $('head base').attr('href')+'template/'+tid,
	    		data    : { uwmetadata: uwmetadata }
	    	});
	    },
	    
		saveModsTemplateAs: function(title, mods){
			   return $http({
				   method  : 'PUT',
		        url     : $('head base').attr('href')+'template',
		        data    : { title: title, mods: mods }
			   });
		 },
		
		 saveModsTemplate: function(tid, mods){
		 	return $http({
		 		method  : 'POST',
		 		url     : $('head base').attr('href')+'template/'+tid,
		 		data    : { mods: mods }
		 	});
		 },


		deleteTemplate: function(tid){
			return $http({
				method  : 'DELETE',
				url     : $('head base').attr('href')+'template/'+tid
			});
		},

		loadTemplate: function(tid){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'template/'+tid
			});
	    },

		loadTemplateToBag: function(tid){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'bag/template/'+tid
			});
		},

		getMyTemplates: function(){
			return $http({
				method  : 'GET',
				url     : $('head base').attr('href')+'templates/my'
			});
		},

		toggleSharedTemplate: function(tid){
			return $http({
				method  : 'POST',
				url     : $('head base').attr('href')+'template/'+tid+'/shared/toggle'
			});
		},

		getModsBagClassifications: function(bagid) {
		    return $http({
		        method  : 'GET',
		        url     : $('head base').attr('href')+'bag/'+bagid+'/mods/classifications'
		    });
		}
	}
});
