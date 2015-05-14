gulp = require 'gulp'

fs = require 'fs'
path = require 'path'
mergeStream = require 'merge-stream'
merge = require 'gulp-merge'

del = require 'del'
concat = require 'gulp-concat'
rename = require 'gulp-rename'
size = require 'gulp-size'

stylus = require 'gulp-stylus'
coffee = require 'gulp-coffee'
minify = require 'gulp-minify-css'
uglify = require 'gulp-uglify'


getFolders = (dir) ->
    fs.readdirSync(dir).filter (file) -> fs.statSync(path.join(dir, file)).isDirectory()


gulp.task 'initial', ->
    del ['public/js', 'public/css']
    

gulp.task 'views', ['initial'], ->
    gulp.src 'views/*.*'
        .pipe size title: 'views', showFiles: true
        .pipe size title: 'views_gzip', gzip: true
        
        
gulp.task 'styl', ['initial'], ->
    merge(
        gulp.src 'source/styl/*.styl'
            .pipe concat 'style.styl'
            .pipe stylus()

        gulp.src 'source/css/*.css'
    )
        .pipe size title: 'css', showFiles: true
        .pipe concat 'style.css'
        .pipe minify()
        .pipe size title: 'css_min', gzip: true
        .pipe gulp.dest 'public/css'
        
gulp.task 'coffee_initial', ->
    folders = getFolders 'source/coffee'
    
    coffeeTasks = folders.map (folder) ->
        gulp.src path.join 'source/coffee', folder, '/*.coffee'
            .pipe concat "#{folder}.coffee"
            .pipe gulp.dest 'temp/coffee'
            
    mergeStream coffeeTasks
    
gulp.task 'coffee', ['initial', 'coffee_initial'], ->
    merge(
        gulp.src ['temp/coffee/*.coffee']
            .pipe coffee()

        gulp.src 'source/js/*.js'
            .pipe concat 'libs.js'
    )
        .pipe size title: 'js', showFiles: true
        .pipe size title: 'js_min', gzip: true
        .pipe gulp.dest 'public/js'
            
            
gulp.task 'final', ['initial', 'views', 'styl', 'coffee'], ->
    gulp.src 'public/**'
        .pipe size title: 'all'
        .pipe size title: 'all_gzip', gzip: true
        
    del ['temp']
        
gulp.task 'default', ['initial', 'views', 'styl', 'coffee_initial', 'coffee', 'final']