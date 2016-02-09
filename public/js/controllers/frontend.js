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
          console.log('loadSettings:',response.data);
          $scope.settings = response.data.settings;          
          
          delete $scope.settings.members;
          console.log('xxxxxxx', $scope.settings);
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

   
    console.log('saveSettings type',type);      
          
    console.log('aaaaa2',$scope.settings.project.members);
    //default_assignee
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
         
         console.log('default_template before save1',$scope.settings.project.default_template);
         console.log('default_template before save2',$scope.settings.user.default_template); 
            
         $scope.settings[type].visible_uwmfields = [];
         $scope.saveVisibleFieldsSettingsRec($scope.uwmfields[type], type);
         
         if($scope.settings.project.members){
                 if($scope.settings.project.members.selected){
                           $scope.settings[type].default_assignee = $scope.settings.project.members.selected.username;
                 }
         }
         console.log('settings before save',$scope.settings);
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
          
    if(typeof $scope.settings.project.members == 'undefined'){
         $scope.settings.project.members = [];
    }else{
         $scope.settings.project.members.splice(index, 1);      
    }
    $scope.saveSettings('members');

  }
   
  $scope.editMemberConfig = function(index, member_data){
    
       var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/edit_project_member.html',
            controller: EditMemberModalCtrl,
            scope: $scope,
            resolve: {
                            username: function(){
                                   return member_data.username;
                                  },
                            role: function(){
                                   return member_data.role;
                                  },
                            displayname: function(){
                                   return member_data.displayname;
                                  }
                    }
      });
  }
  
   $scope.addMemberConfig = function(){
    
        console.log('addMemberConfig:');
       var modalInstance = $modal.open({
            templateUrl: $('head base').attr('href')+'views/modals/add_project_member.html',
            controller: AddMemberModalCtrl,
            scope: $scope
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



var AddMemberModalCtrl = function ($scope, $modalInstance, $http, FrontendService, promiseTracker) {
       
        $scope.selected_role;
        $scope.new_displayname;
        $scope.searchMembers = [];
        $scope.selected_member = {};
        
        $scope.refreshMembers = function(query) {
               
             var promise = FrontendService.getUsers(query);
             $scope.loadingTracker.addPromise(promise);
             promise.then(
                   function(response) { 
                           $scope.alerts = response.data.alerts;
                           $scope.form_disabled = false;
                           console.log('refreshMembers', response.data);
                           if(response.data.accounts){
                                    if(response.data.accounts.constructor === Array){
                                            $scope.searchMembers = response.data.accounts;   
                                    }
                           }
                   }
                  ,function(response) {
                           console.log('refreshMembers', response.data); 
                           $scope.alerts = response.data.alerts;
                           $scope.alerts.unshift({type: 'danger', msg: "Error code "+response.status});
                           $scope.form_disabled = false;
                   }
             );
        }
       

        $scope.save = function (new_displayname) {
            
            console.log('new_displayname', new_displayname);
            console.log('selected_member', $scope.selected_member.selected.uid);
            console.log('selected_role', $scope.selected_role);

            if(!$scope.settings.project.members){
                   $scope.settings.project.members = []; 
            }
            var newMember = {};
            newMember.username = $scope.selected_member.selected.uid;
            newMember.displayname = new_displayname;
            newMember.role = $scope.selected_role;
            $scope.settings.project.members.push(newMember);
            
            $scope.saveSettings('members');
            $modalInstance.dismiss('OK');
            
        }
        
        $scope.setMembersRole = function (new_role) {
             $scope.selected_role = new_role;
        };
        
        $scope.cancel = function () {
            $modalInstance.dismiss('Save');
        };
    
        $scope.hitEnter = function(evt){
              if(angular.equals(evt.keyCode,13)){
                  //$scope.deleteAllBookmark();
                  $modalInstance.dismiss('OK');
              }
        }; 
        
}

var EditMemberModalCtrl = function ($scope, $modalInstance, promiseTracker, username, role, displayname) {
        
     
    $scope.selected_role = role;
    $scope.new_displayname = displayname;
    
    $scope.setMembersRole = function (new_role) {
             console.log('role username', new_role, username);
             for (var i = 0; i < $scope.settings.project.members.length; ++i) {
                  if(typeof $scope.settings.project.members[i].username != 'undefined' ){
                         if($scope.settings.project.members[i].username == username){
                               $scope.settings.project.members[i].role = new_role;
                               $scope.selected_role = new_role;
                         }
                  }
             }
             console.log('setMembersRole', $scope.settings);
             console.log('selected_role',$scope.selected_role);
    };

       
    
    $scope.save = function (new_displayname) {
            
            
            console.log('new_displayname', new_displayname);
            for (var i = 0; i < $scope.settings.project.members.length; ++i) {
                  if(typeof $scope.settings.project.members[i].username != 'undefined' ){
                         if($scope.settings.project.members[i].username == username){
                               $scope.settings.project.members[i].displayname = new_displayname;
                         }
                  }
            }
            $scope.saveSettings('members');
            $modalInstance.dismiss('OK');
    }
    
    $scope.cancel = function () {
        $modalInstance.dismiss('Save');
    };
    
    $scope.hitEnter = function(evt){
           if(angular.equals(evt.keyCode,13)){
                  //$scope.deleteAllBookmark();
                  $modalInstance.dismiss('OK');
           }
   }; 
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
