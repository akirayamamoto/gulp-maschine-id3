# gulp coffee && gulp write-riff

# gulp list-riff-wav
# gulp list-riff-dist

gulp        = require 'gulp'
coffeelint  = require 'gulp-coffeelint'
coffee      = require 'gulp-coffee'
del         = require 'del'
watch       = require 'gulp-watch'

gulp.task 'coffeelint', ->
  gulp.src ['./*.coffee', './src/*.coffee']
    .pipe coffeelint './coffeelint.json'
    .pipe coffeelint.reporter()

gulp.task 'coffee', ['coffeelint'], ->
  gulp.src ['./src/*.coffee']
    .pipe coffee()
    .pipe gulp.dest './lib'

gulp.task 'default', ['coffee']

gulp.task 'watch', ->
  gulp.watch './**/*.coffee', ['default']

gulp.task 'clean', (cb) ->
  del ['./lib/*.js', './**/*~'], force: true, cb





####### TESTING #######

path = require 'path'
id3 = require './lib/gulp-wav-id3'

gulp.task 'write-riff', ->
  gulp.src ["wav/**/*.wav"]
    .pipe id3 (file, chunks) ->
      # do something to create data
      name: path.basename file.path, '.wav'
      removeUnnecessaryChunks: false

      APIC: '/mnt/s3temp/gulp-wav-id3/wav/apic.jpg'
      TIT2: 'Akira TIT2 408'
      TALB: 'Akira TALB 407'
      TCOM: 'Akira TCOM 231'
      TCON: 'Akira TCON 232'

      vendor: 'Hahaha'
      author: 'Hehehe'
      comment: 'uniuni'
      bankchain: ['Fugafuga', 'Fugafuga 1.1 Library']
      types: [
         ['Bass', 'Synth Bass']
       ]
    .pipe gulp.dest 'dist'

gulp.task 'list-riff-wav', ->
  gulp.src ['wav/**/*.wav']
    .pipe id3 (file, chunks) ->
      console.info (chunk.id for chunk in chunks)
      # if return null or undefined, file will not be changed.
      undefined

gulp.task 'list-riff-dist', ->
  gulp.src ['dist/**/*.wav']
    .pipe id3 (file, chunks) ->
      console.info (chunk.id for chunk in chunks)
      # if return null or undefined, file will not be changed.
      undefined
