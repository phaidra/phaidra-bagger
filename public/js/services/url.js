angular.module('Url', [])
.factory('Url', function() {
	 
 return {
	 forEachSorted: function (obj, iterator, context) {
	 	var keys = this.sortedKeys(obj);
	    for (var i = 0; i < keys.length; i++) {
	        iterator.call(context, obj[keys[i]], keys[i]);
	    }
	    return keys;
     },

     sortedKeys: function (obj) {
    	 var keys = [];
	    for (var key in obj) {
	        if (obj.hasOwnProperty(key)) {
	            keys.push(key);
	        }
	    }
	    return keys.sort();
     },
     
     buildUrl: function (url, params) {
		if (!params) return url;
	    var parts = [];
	    this.forEachSorted(params, function (value, key) {
	        if (value == null || value == undefined) return;
	        if (angular.isObject(value)) {
	            value = angular.toJson(value);
	        }
	        parts.push(encodeURIComponent(key) + '=' + encodeURIComponent(value));
	    });
	    return url + ((url.indexOf('?') == -1) ? '?' : '&') + parts.join('&');
     }
 };
});