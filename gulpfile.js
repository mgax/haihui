require('coffee-script/register');

var gulp = require('gulp'),
    coffee = require('gulp-coffee'),
    less = require('gulp-less'),
    sourcemaps = require('gulp-sourcemaps'),
    concat = require('gulp-concat'),
    Q = require('q'),
    http = require('http'),
    express = require('express'),
    async = require('async'),
    data = require('./src/data.coffee');


gulp.task('serve', function() {
  var host = '0.0.0.0';
  var port = +(process.env.PORT || 5000);
  var app = express().use('/', express.static(__dirname + '/build'));
  http.createServer(app).listen(port, host, function() {
    console.log('devel server listening on ' + host + ':' + port);
  });

  return Q.defer().promise;
});


var regionList = Object.keys(data.REGION).sort();

regionList.forEach(function(region) {
  gulp.task('data-' + region, function() {
    return data.build(region);
  });

  gulp.task('err-' + region, function() {
    return data.err(region);
  });
});


gulp.task('data', regionList.map(function(region) { return 'data-' + region }));
gulp.task('data', function() {
  var done = Q.defer();
  async.eachLimit(regionList, 1, function(region, cb) {
    data.build(region).done(function() { cb() });
  }, function(err) { if(err) done.reject(err); else done.resolve(); });
  return done.promise;
});


gulp.task('html', function() {
  return data.html();
});


gulp.task('assets', function() {
  gulp.src('media/**/*').pipe(gulp.dest('./build'));

  var done = Q.defer();
  var request = require('request');
  var fs = require('fs');
  var cdnjs = 'http://cdnjs.cloudflare.com/ajax/libs/';
  request(cdnjs + 'd3/3.5.3/d3.min.js', function(err, res, body) {
    fs.writeFileSync('build/d3.min.js', body);
    request(cdnjs + 'topojson/1.6.9/topojson.min.js', function(err, res, body) {
      fs.writeFileSync('build/topojson.min.js', body);
      request(cdnjs + 'twitter-bootstrap/3.3.2/css/bootstrap.min.css', function(err, res, body) {
        fs.writeFileSync('build/bootstrap.min.css', body);
        request(cdnjs + 'proj4js/2.3.3/proj4.js', function(err, res, body) {
          fs.writeFileSync('build/proj4.js', body);
          done.resolve();
        });
      });
    });
  });
  return done.promise;
});


gulp.task('js', function() {
  return gulp.src('src/ui/**/*.coffee')
    .pipe(sourcemaps.init())
    .pipe(coffee())
    .pipe(concat('ui.js'))
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest('./build'));
});


gulp.task('css', function() {
  return gulp.src('src/ui/region.less')
    .pipe(less())
    .pipe(gulp.dest('./build'))
});

gulp.task('ui', ['js', 'css'], function() {
  gulp.start('html');
});

gulp.task('auto', function() {
  gulp.start('ui');
  gulp.watch('src/ui/**/*', ['ui']);
  gulp.watch('templates/**/*', ['ui']);
});


gulp.task('devel', ['auto', 'serve']);
gulp.task('default', ['data', 'ui', 'assets']);
