// File: ui/2FastTelemetry/app.js
(function(){
  var app = angular.module('fastTelemetry', []);

  app.controller('HudCtrl', ['$scope', function($scope){
    var vm = this;
    vm.lapTimeMs = 0;
    vm.bestLapMs = null;
    vm.deltaMs = null;
    vm.sectorSplits = [];
    vm.lapCounter = '--';
    vm.standings = [];
    vm.startLights = 0;

    vm.formatMs = function(ms){
      if(ms === null || ms === undefined) return '--';
      var total = ms/1000;
      var minutes = Math.floor(total/60);
      var seconds = total - minutes*60;
      return minutes + ':' + ('00' + seconds.toFixed(3)).slice(-6);
    };

    function updateFromTick(data){
      vm.lapTimeMs = data.lapTimeMs;
      vm.deltaMs = data.delta;
      $scope.$applyAsync();
    }

    function onLapCompleted(data){
      vm.bestLapMs = data.bestLapMs;
      vm.deltaMs = data.delta;
      vm.sectorSplits = [];
      $scope.$applyAsync();
    }

    function onSectorUpdate(data){
      vm.sectorSplits.push({id: data.sector, time: data.splitMs});
      $scope.$applyAsync();
    }

    function onRaceStart(data){
      vm.lapCounter = '1 / ' + (data.event.laps || '?');
      vm.standings = (data.field || []).map(function(pid, idx){
        return { pos: idx+1, name: 'P' + pid, gap: idx === 0 ? 'Leader' : '+--' };
      });
      vm.startLights = 5;
      var interval = setInterval(function(){
        vm.startLights--; if(vm.startLights <= 0){ clearInterval(interval); } $scope.$applyAsync();
      }, 700);
    }

    function onRaceFinished(){
      vm.standings = [];
      vm.lapCounter = '--';
      $scope.$applyAsync();
    }

    // BeamMP client event bridges (pseudo; actual binding done via MP.RegisterEvent on client side)
    if(typeof MP !== 'undefined' && MP.RegisterEvent){
      MP.RegisterEvent('2fast:tick', function(data){ updateFromTick(JSON.parse(data)); });
      MP.RegisterEvent('2fast:lapCompleted', function(data){ onLapCompleted(JSON.parse(data)); });
      MP.RegisterEvent('2fast:sectorUpdate', function(data){ onSectorUpdate(JSON.parse(data)); });
      MP.RegisterEvent('2fast:raceStart', function(data){ onRaceStart(JSON.parse(data)); });
      MP.RegisterEvent('2fast:raceFinished', function(data){ onRaceFinished(JSON.parse(data)); });
    }
  }]);
})();
