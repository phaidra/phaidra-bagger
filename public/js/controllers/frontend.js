var app = angular.module('frontendApp', ['ngAnimate', 'ngSanitize', 'ui.bootstrap', 'ui.bootstrap.modal', 'ui.bootstrap.datepicker', 'ui.bootstrap.timepicker', 'ui.sortable', 'ui.select', 'ajoslin.promise-tracker', 'directoryService', 'vocabularyService', 'metadataService', 'frontendService', 'bagService', 'jobService', 'Url', 'uiGmapgoogle-maps', 'pascalprecht.translate', 'pasvaz.bindonce']);


app.config(function(uiGmapGoogleMapApiProvider) {
    uiGmapGoogleMapApiProvider.configure({
  //      key: <%= $config->{google_maps_api_key} %>,
        key:'AIzaSyBWE_bAtgkm1RuWkrW7jBrYV1JBiPUZDAs',
        v: '3.17',
        libraries: 'weather,geometry,visualization'
    });
});

app.config(['$translateProvider', function($translateProvider){
  
  // [prefix][langKey][suffix]
  $translateProvider.useStaticFilesLoader({
    prefix: 'i18n/',
    suffix: '.json'
  });

  // Tell the module what language to use by default
  $translateProvider.preferredLanguage('en_US');
}]);

app.controller('FrontendCtrl', function($scope, $window, $modal, $log, $translate, DirectoryService, MetadataService, FrontendService, promiseTracker) {

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

  $scope.projectclasses = [];

  
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
          //console.log('loadSettings:',response.data);
          $scope.settings = response.data.settings;
          if($scope.settings.project['included_classifications']){
            var included_classifications = {};
            for (var i = 0; i < $scope.settings.project.included_classifications.length; ++i) {
              included_classifications[$scope.settings.project.included_classifications[i]] = true;
            }
            $scope.settings.project['included_classifications'] = included_classifications;
          }
          $scope.settings.templates.push({title:'None',_id:''});
          if($scope.settings.user == null){
              $scope.settings.user = {};
          }
          console.log('int settings:', $scope.settings);
          $scope.getProjectClasses();
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
          console.log('uwmfields:',$scope.uwmfields);
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

   
    console.log('aaaaa2',$scope.settings.project.members);
    if(type == 'members'){
            
            //$scope.settings[type] =  $scope.settings.project.members;
         //$scope.settings[type].visible_uwmfields = [];
         //console.log('uwmfields111:',$scope.uwmfields[type]);
         //$scope.saveVisibleFieldsSettingsRec($scope.uwmfields[type], type);
            
         console.log('aaaaa11',$scope.settings.project.members);
         $scope.form_disabled = true;
         var promise = FrontendService.saveSettings(type, $scope.settings.project.members);
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
       
    }else{
         console.log('aaaaa',$scope.settings[type]);
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
      
    }
  };

  $scope.addClassToConfig = function(uri){
    if(typeof $scope.settings.project.classifications == 'undefined'){
      $scope.settings.project['classifications'] = [];
    }
    $scope.settings.project.classifications.push(uri);
    $scope.saveSettings('project');
    $scope.getProjectClasses();
  }

  $scope.removeClassFromConfig = function(index){
    if(typeof $scope.settings.project.classifications == 'undefined'){
      $scope.settings.project['classifications'] = [];
    }else{
      $scope.settings['project'].classifications.splice(index, 1);
    }
    $scope.saveSettings('project');
    $scope.getProjectClasses();
  }

  $scope.removeMemberFromConfig = function(index){
     console.log('removeMemberFromConfig before',$scope.settings.project.members);
     console.log('removeMemberFromConfig before',$scope.settings.members);
     console.log('removeMemberFromConfig index',index);
    
    if(typeof $scope.settings.members == 'undefined'){
      console.log('removeMemberFromConfig not deleting');
      $scope.settings['members'] = [];
    }else{
      console.log('removeMemberFromConfig deleting');
      $scope.settings.project.members.splice(index, 1);
      if(typeof $scope.settings.members !== 'undefined'){
           $scope.settings.members.splice(index, 1);
      }
      
    }
    $scope.saveSettings('members');
     console.log('removeMemberFromConfig after',$scope.settings.members);
     console.log('removeMemberFromConfig after',$scope.settings.project.members);
    //$scope.getProjectClasses();
  }
  
  $scope.editMemberConfig = function(index){
    
      var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/edit_project_member.html',
            controller: EditMemberModalCtrl
      });
  }
  
  $scope.getProjectClasses = function(index){
    $scope.form_disabled = true;
    var promise = FrontendService.getClassifications();
    $scope.loadingTracker.addPromise(promise);
    promise.then(
      function(response) {
        $scope.form_disabled = false;
        $scope.projectclasses = [];
        for (var i = 0; i < response.data.classifications.length; ++i) {
            if(response.data.classifications[i].type == 'project'){
              $scope.projectclasses.push(response.data.classifications[i]);
            }
        }
        $scope.alerts = response.data.alerts;
      }
      ,function(response) {
        $scope.form_disabled = false;
        $scope.alerts = response.data.alerts;
        }
    );
  }

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

     $scope.setLang = function(langKey) {
            $translate.use(langKey);
         };
});


var EditMemberModalCtrl = function ($scope, $modalInstance, FrontendService, promiseTracker) {
  
};

var SigninModalCtrl = function ($scope, $modalInstance, DirectoryService, FrontendService, promiseTracker) {

  $scope.user = {username: '', password: ''};
  $scope.alerts = [];

  $scope.baseurl = $('head base').attr('href');

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
            window.location = $scope.baseurl;
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
