var app = angular.module('frontendApp', ['ngAnimate', 'ngSanitize', 'ui.bootstrap', 'ui.bootstrap.modal', 'ui.bootstrap.datepicker', 'ui.bootstrap.timepicker', 'ui.sortable', 'ui.select', 'ajoslin.promise-tracker', 'directoryService', 'vocabularyService', 'metadataService', 'frontendService', 'bagService', 'jobService', 'Url']);

app.filter("nl2br", function($filter) {
 return function(data) {
   if (!data) return data;
   return data.replace(/\n\r?/g, '<br />');
 };
});

app.controller('FrontendCtrl', function($scope, $window, $modal, $log, DirectoryService, MetadataService, FrontendService, promiseTracker) {

  // we will use this to track running ajax requests to show spinner
  $scope.loadingTracker = promiseTracker.register('loadingTrackerFrontend');

    $scope.alerts = [];
    $scope.query = '';

  $scope.initdata = '';
  $scope.current_user = '';

  $scope.uwmfields = {
      user: [],
      project: []
  };

  $scope.default_template = {
      user: '',
      project: ''
  };

  $scope.settings = {
    user: {},
    project: {}
  };

  $scope.init = function (initdata) {
    $scope.initdata = angular.fromJson(initdata);
    $scope.current_user = $scope.initdata.current_user;
    $scope.baseurl = $('head base').attr('href');
    };

    $scope.initSettings = function (initdata_settings) {
      $scope.baseurl = $('head base').attr('href');
      var d = angular.fromJson(initdata_settings);
      $scope.initdata = d;
      $scope.current_user = d.current_user;
      $scope.loadSettings();
    };

    $scope.loadSettings = function() {
      var promise = FrontendService.loadSettings();
    $scope.loadingTracker.addPromise(promise);
    promise.then(
        function(response) {
          $scope.alerts = response.data.alerts;
          $scope.settings = response.data.settings;
          $scope.settings.templates.push({title:'None',_id:''});
          if($scope.settings.user == null){
              $scope.settings.user = {};
          }
          $scope.getUwmfields();
          $scope.form_disabled = false;
        }
        ,function(response) {
          $scope.alerts = response.data.alerts;
          $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
           $scope.form_disabled = false;
         }
    );
    }

    $scope.getUwmfields = function () {
      var promise = MetadataService.getUwmetadataTree();
    $scope.loadingTracker.addPromise(promise);
    promise.then(
        function(response) {
          $scope.alerts = response.data.alerts;
          $scope.uwmfields.user = response.data.tree;
          angular.copy(response.data.tree, $scope.uwmfields.project);
          $scope.applyVisibleFieldsSettings();
          $scope.form_disabled = false;
        }
        ,function(response) {
          $scope.alerts = response.data.alerts;
          $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
           $scope.form_disabled = false;
         }
    );
  };

  $scope.applyVisibleFieldsSettings = function(){
    if($scope.settings['user'].visible_uwmfields){
      $scope.applyVisibleFieldsSettingsRec($scope.uwmfields['user'], $scope.settings['user'].visible_uwmfields);
    }
    if($scope.settings['project'].visible_uwmfields){
      $scope.applyVisibleFieldsSettingsRec($scope.uwmfields['project'], $scope.settings['project'].visible_uwmfields);
    }
  }

  $scope.saveSettings = function(type){

    $scope.settings[type].visible_uwmfields = [];
    $scope.saveVisibleFieldsSettingsRec($scope.uwmfields[type], type);

    $scope.form_disabled = true;
    var promise = FrontendService.saveSettings(type, $scope.settings[type]);
    $scope.loadingTracker.addPromise(promise);
    promise.then(
      function(response) {
        $scope.form_disabled = false;
        $scope.alerts = response.data.alerts;
      }
      ,function(response) {
        $scope.form_disabled = false;
        $scope.alerts = response.data.alerts;
        }
    );
  };

  $scope.saveVisibleFieldsSettingsRec = function(children, type){
    for (var i = 0; i < children.length; ++i) {
      if(children[i].include){
        var uri;
        if(children[i].help_id == "helpmeta_37"){
          uri = children[i].xmlns+'/rights#'+children[i].xmlname;
        }else{
          uri = children[i].xmlns+'#'+children[i].xmlname;
        }
      $scope.settings[type].visible_uwmfields.push(uri);
      }
      if(children[i].children){
        $scope.saveVisibleFieldsSettingsRec(children[i].children, type);
      }
    }
  };

  $scope.applyVisibleFieldsSettingsRec = function(children, visible){
    for (var i = 0; i < children.length; ++i) {
      var uri;
      if(children[i].help_id == "helpmeta_37"){
        uri = children[i].xmlns+'/rights#'+children[i].xmlname;
      }else{
        uri = children[i].xmlns+'#'+children[i].xmlname;
      }

      for(var j = 0; j < visible.length; ++j) {
        if(visible[j] == uri){
          children[i].include = true;
        }
      }

      if(children[i].children){
        $scope.applyVisibleFieldsSettingsRec(children[i].children, visible);
      }
    }
  }

  $scope.checkTreeSanity = function (field, type) {
    if(field.children){
      // if parent is unchecked then all the children should be unchecked
      $scope.setIncludeRec(field.children, field.include);
    }

    // if some child is checked, then parent have to be checked
    // if no child is checked, then parent have to be unchecked
    $scope.checkParents($scope.uwmfields[type]);
  };

  $scope.checkParents = function(children){
    for (var i = 0; i < children.length; ++i) {
      if(children[i].children){
        if($scope.hasCheckedChild(children[i].children)){
          children[i].include = true;
        }else{
          children[i].include = false;
        }
        $scope.checkParents(children[i].children);
      }
    }
  };

  $scope.hasCheckedChild = function(children){
    for (var i = 0; i < children.length; ++i) {
      if(children[i].include){
        return true;
      }
      if(children[i].children){
        return $scope.hasCheckedChild(children[i].children)
      }
    }
  };

  $scope.setIncludeRec = function (children, include){
    for (var i = 0; i < children.length; ++i) {
      children[i].include = include;
      if(children[i].children){
        $scope.setIncludeRec(children[i].children, include);
      }
    }
  };

  // used to filter array of elements: if 'hidden' is set, the field will not be included in the array
    $scope.filterHidden = function(e)
    {
        return !e.hidden;
    };

  $scope.defaultAssigneeDisplayName = function() {
    if($scope.settings.project.members){
      for (var i = 0; i < $scope.settings.project.members.length; ++i) {
        if($scope.settings.project.members[i].username == $scope.settings.project.default_assignee){
          return $scope.settings.project.members[i].displayname;
        }
      }
    }
  }

    $scope.forceLoadPage = function(link) {
      $window.location = link;
    };

    $scope.hitEnterSearch = function(evt){
      if(angular.equals(evt.keyCode,13) && !(angular.equals($scope.query,null) || angular.equals($scope.query,''))){
        window.location = $('head base').attr('href')+'search?q='+encodeURIComponent($scope.query);
      }
    };

    $scope.search = function(){
      if(!(angular.equals($scope.query,null) || angular.equals($scope.query,''))){
        window.location = $('head base').attr('href')+'search?q='+encodeURIComponent($scope.query);
      }
    };

    $scope.closeAlert = function(index) {
      $scope.alerts.splice(index, 1);
    };

    $scope.signin_open = function () {

      var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/loginform.html',
            controller: SigninModalCtrl
      });
    };

    $scope.init = function () {
      if($('#signin').attr('data-open') == 1){
        $scope.signin_open();
      }
    };

});

var SigninModalCtrl = function ($scope, $modalInstance, DirectoryService, FrontendService, promiseTracker) {

  $scope.user = {username: '', password: ''};
  $scope.alerts = [];

  // we will use this to track running ajax requests to show spinner
  $scope.loadingTracker = promiseTracker('loadingTrackerFrontend');

  $scope.closeAlert = function(index) {
      $scope.alerts.splice(index, 1);
    };

    $scope.hitEnterSignin = function(evt){
      if(angular.equals(evt.keyCode,13)
          && !(angular.equals($scope.user.username,null) || angular.equals($scope.user.username,''))
          && !(angular.equals($scope.user.password,null) || angular.equals($scope.user.password,''))
          )
      $scope.signin();
    };

  $scope.signin = function () {

    $scope.form_disabled = true;

    var promise = DirectoryService.signin($scope.user.username, $scope.user.password);
      $scope.loadingTracker.addPromise(promise);
      promise.then(
        function(response) {
          $scope.form_disabled = false;
          $scope.alerts = response.data.alerts;
          $modalInstance.close();
          var red = $('#signin').attr('data-redirect');
          if(red){
            window.location = red;
          }else{
            window.location.reload();
          }
        }
        ,function(response) {
          $scope.form_disabled = false;
          $scope.alerts = response.data.alerts;
            }
        );
    return;

  };

  $scope.cancel = function () {
    $modalInstance.dismiss('cancel');
  };
};


/*
app.run(function(editableOptions) {
  editableOptions.theme = 'bs3';
});
*/
