var gulp = require('gulp'),
    coffee = require('gulp-coffee'),
    sourcemaps = require('gulp-sourcemaps'),
    Q = require('q'),
    http = require('http'),
    express = require('express');


gulp.task('serve', function() {
  var host = '0.0.0.0';
  var port = +(process.env.PORT || 5000);
  var app = express().use('/', express.static(__dirname));
  http.createServer(app).listen(port, host, function() {
    console.log('devel server listening on ' + host + ':' + port);
  })

  return Q.defer().promise;
});


gulp.task('data', function() {
  require('coffee-script/register');
  require('./src/data.coffee')();
});


gulp.task('ui', function() {
  gulp.src('./src/ui.coffee')
    .pipe(sourcemaps.init())
    .pipe(coffee())
    .pipe(sourcemaps.write('./'))
    .pipe(gulp.dest('./build'));
});


gulp.task('auto', function() {
  gulp.start('data');
  gulp.start('ui');
  gulp.watch('src/**/*', ['data', 'ui']);
});


gulp.task('devel', ['auto', 'serve']);
gulp.task('default', ['data', 'ui']);
