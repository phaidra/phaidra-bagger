app.controller('BaginfoCtrl',  function($scope) {

	$scope.initdata = '';

	$scope.init = function (initdata) {
		$scope.initdata = angular.fromJson(initdata);
  };

});
