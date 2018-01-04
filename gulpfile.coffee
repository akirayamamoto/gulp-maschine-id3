# gulp coffee && gulp write-wav-id3 --json "/home/ubuntu/json/WOM_SOO_0001_01001.mp3.json" --wav "/var/www/html/s3temp/gulp-wav-id3/wav/WOM_NRF_0001_00101.wav"
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
fs = require 'fs'
id3 = require './lib/gulp-wav-id3'

gulp.task 'write-wav-id3', ->
  jsonPath = undefined
  i = process.argv.indexOf '--json'
  if i < 0
    throw new Error "JSON path not specified."
  jsonPath = process.argv[i + 1]
  console.info 'jsonPath', jsonPath
  jsonContent = JSON.parse (fs.readFileSync jsonPath, 'utf8')
  # console.info 'jsonContent', jsonContent

  wavPath = undefined
  i = process.argv.indexOf '--wav'
  if i < 0
    throw new Error "JSON path not specified."
  wavPath = process.argv[i + 1]
  console.info 'wavPath', wavPath

  gulp.src wavPath
    .pipe id3 (file, chunks) ->
      jsonContent
    .pipe gulp.dest (f) -> f.base

gulp.task 'write-riff', ->
  gulp.src ["wav/**/*.wav"]
    .pipe id3 (file, chunks) ->
      APIC: '/mnt/s3temp/gulp-wav-id3/wav/apic.jpg'
      TIT2: 'Akira TIT2 408'
      TALB: 'Akira TALB 407'
      TCOM: 'Akira TCOM 231'
      TCON: 'Akira TCON 232'
      COMM: 'Industrial glitched-up dubstep with tough beats, clubby synths and vocal samples.'
    .pipe gulp.dest (f) -> f.base

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
