var gulp = require('gulp'),
    coffee = require('gulp-coffee'),
    less = require('gulp-less'),
    sourcemaps = require('gulp-sourcemaps'),
    Q = require('q'),
    http = require('http'),
    express = require('express');


gulp.task('serve', function() {
  var host = '0.0.0.0';
  var port = +(process.env.PORT || 5000);
  var app = express().use('/', express.static(__dirname + '/build'));
  http.createServer(app).listen(port, host, function() {
    console.log('devel server listening on ' + host + ':' + port);
  })

  return Q.defer().promise;
});


gulp.task('ciucas', function() {
  require('coffee-script/register');
  return require('./src/data.coffee').build('ciucas');
});


gulp.task('data', function() {
  require('coffee-script/register');
  return require('./src/data.coffee').buildAll();
});


gulp.task('html', function() {
  require('coffee-script/register');
  return require('./src/data.coffee').html();
});


gulp.task('libs', function() {
  var done = Q.defer();
  var request = require('request');
  var fs = require('fs');
  var cdnjs = 'http://cdnjs.cloudflare.com/ajax/libs/';
  request(cdnjs + 'd3/3.5.3/d3.min.js', function(err, res, body) {
    fs.writeFileSync('build/d3.min.js', body);
    request(cdnjs + 'topojson/1.6.9/topojson.min.js', function(err, res, body) {
      fs.writeFileSync('build/topojson.min.js', body);
      done.resolve();
    });
  });
  return done.promise;
});


gulp.task('ui', function() {
  gulp.src(['./src/symbol.coffee', './src/ui.coffee'])
    .pipe(sourcemaps.init())
    .pipe(coffee())
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest('./build'));

  gulp.src('src/ui.less')
    .pipe(less())
    .pipe(gulp.dest('./build'))
});


gulp.task('auto', function() {
  gulp.start('ui');
  gulp.watch('src/**/*', ['ui']);
});


gulp.task('devel', ['auto', 'serve']);
gulp.task('default', ['data', 'ui', 'html', 'libs']);
