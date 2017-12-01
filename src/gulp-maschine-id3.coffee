# Gulp plugin for adding maschine metadata to wav file
#
# - API
#  - id3(data)
#   - data
#     object or function to provide data
#   - data.name          String Optional default: source filename
#   - data.author        String
#   - data.vendor        String
#   - data.comment       String
#   - data.bankchain     Array of String
#   - data.types         2 dimensional Array of String
#   - data.modes         Array of String (currently unsupported)
#   - data.syncFilename  bool - use data.name as filenam. default: true
#   - data.removeUnnecessaryChunks bool - remove all chunks except 'fmt ' or 'data' chunk. default: true
#   - function(file, chunks[,callback])
#     function to provide data
#     - file instance of vinyl file
#     - chunks Array of object
#        RIFF chunks of source file
#        element properties
#          - id    String chunk id
#          - data  Buffer contents of chunk
#     - callback function(err, data)
#       callback function to support non-blocking call.
#
# - Usage
#     id3 = require 'gulp-maschine-id3'
#     gulp.task 'hoge', ->
#       gulp.src ["src/**/*.wav"]
#         .pipe id3 (file, chunks) ->
#           name: "Hogehoge"
#           vendor: "Hahaha"
#           author: "Hehehe"
#           comment: "uniuni"
#           bankchain: ['Fugafuga', 'Fugafuga 1.1 Library']
#           types: [
#             ['Bass', 'Synth Bass']
#           ]
#         .pipe gulp.dest "dist"
#
assert       = require 'assert'
path         = require 'path'
through      = require 'through2'
gutil        = require 'gulp-util'
_            = require 'underscore'
riffReader   = require 'riff-reader'
riffBuilder  = require './riff-builder'
fs           = require 'fs'

PLUGIN_NAME  = 'maschine-id3'

module.exports = (data) ->
  through.obj (file, enc, cb) ->
    alreadyCalled = off
    id3 = (err, data) =>
      if alreadyCalled
        @emit 'error', new gutil.PluginError PLUGIN_NAME, 'duplicate callback calls.'
        return
      alreadyCalled = on
      if err
        @emit 'error', new gutil.PluginError PLUGIN_NAME, err
        return cb()
      try
        if data
          _id3 file, data
        @push file
      catch error
        @emit 'error', new gutil.PluginError PLUGIN_NAME, error
      cb()

    unless file
      id3 'Files can not be empty'
      return

    if file.isStream()
      id3 'Streaming not supported'
      return

    if _.isFunction data
      try
        chunks = _parseSourceWavChunks file
        providedData = data.call @, file, chunks, id3
      catch error
        id3 error
      if data.length <= 2
        id3 undefined, providedData
    else
      try
        _parseSourceWavChunks file
      catch error
        return error
      id3 undefined, data

# replace or append ID3 chunk to file
#
# @data    object  - metadata
# @wreturn Array   - chunks in source file
# ---------------------------------
_parseSourceWavChunks = (file) ->
  chunks = []
  src = if file.isBuffer() then file.contents else file.path
  json = undefined
  riffReader(src, 'WAVE').readSync (id, data) ->
    chunks.push
      id: id
      data: data
  ids = chunks.map (chunk) -> chunk.id
  assert.ok ('fmt ' in ids), "[fmt ] chunk is not contained in file."
  assert.ok ('data' in ids), "[data] chunk is not contained in file."
  file.chunks = chunks

# replace or append ID3 chunk to file
#
# @data    Object - metadata
# @wreturn Buffer - contents of ID3 chunk
# ---------------------------------
_id3 = (file, data) ->
  extname = path.extname file.path
  basename = path.basename file.path, extname
  dirname = path.dirname file.path
  # default value
  data = _.defaults data,
    name: basename
    syncFilename: on
    removeUnnecessaryChunks: on
  # validate
  _validate data
  chunks = if data.removeUnnecessaryChunks
    file.chunks.filter (c) -> c.id in ['fmt ', 'data']
  else
    # remove 'ID3 ' chunk if already exits.
    file.chunks.filter (c) -> c.id isnt 'ID3 '
  # rename
  if data.syncFilename
    file.path = path.join dirname, (data.name + extname)
  # build wav file
  wav = riffBuilder 'WAVE'
  wav.pushChunk chunk.id, chunk.data for chunk in chunks
  wav.pushChunk 'ID3 ', _build_id3_chunk data
  file.contents =  wav.buffer()

# build ID3 chunk contents
#
# @data    Object - metadata
# @wreturn Buffer - contents of ID3 chunk
# ---------------------------------
_build_id3_chunk = (data) ->
  # Akira: create more frames here according to data
  apicFrame = _build_apic_frame data.APIC
  geobFrame = _build_geob_frame data

  header = new BufferBuilder()
    .push 'ID3'            # magic
    .push [0x03,0x00]      # id3 version 2.3.0
    .push 0x00             # flags

    # Akira: sum all frame lengths here
    .pushSyncsafeInt apicFrame.length + geobFrame.length + 1024  # size
  # return buffer

  Buffer.concat [
    header.buf             # ID3v2 header 10 byte
    # Akira list other frames here
    apicFrame
    geobFrame              # GEOB frame
    Buffer.alloc 1024, 0   # end-mark 4 byte  + reserve area
  ]

# build ID3 GEOB frame
#
# @data    Object - metadata
# @wreturn Buffer - contents of GEOB frame
# ---------------------------------
_build_geob_frame = (data) ->
  contents = new BufferBuilder()
    # unknown, It seems all expansions sample are same.
    .pushHex '000000'
    .push 'com.native-instruments.nisound.soundinfo\u0000'
    # unknown, It seems all expansions sample are same.
    .pushHex '020000000100000000000000'
    # sample name
    .pushUcs2String data.name
    # author name
    .pushUcs2String data.author
    # vendor name
    .pushUcs2String data.vendor
    # comment
    .pushUcs2String data.comment
    # unknown, It seems all expansions sample are same.
    .pushHex '00000000ffffffffffffffff000000000000000000000000000000000000000001000000'
    # bankchain
    .pushUcs2StringArray data.bankchain
    # types (category)
    .pushUcs2StringArray _types data.types
    # maybe modes ?
    # .pushUcs2StringArray data.modes
    .pushHex '00000000'
    # properties, It seems all expansions sample are same.
    .pushKeyValuePairs [
       ['color',           '0']
       ['devicetypeflags', '0']
       ['soundtype',       '0']
       ['tempo',           '0']
       ['verl',            '1.7.13']
       ['verm',            '1.7.13']
       ['visib',           '0']
    ]
   # header
  header = new BufferBuilder()
    .push 'GEOB'                          # frame Id
    .pushSyncsafeInt contents.buf.length  # data size
    .push [0x00, 0x00]                    # flags
  # return buffer
  Buffer.concat [header.buf, contents.buf]

_build_apic_frame = (pic) ->
  try
    apicData = if pic instanceof Buffer == true then new Buffer(pic) else new Buffer(fs.readFileSync(pic, 'binary'), 'binary')
    bHeader = new Buffer(10)
    bHeader.fill 0
    bHeader.write 'APIC', 0
    mime_type = 'image/png'
    if apicData[0] == 0xff and apicData[1] == 0xd8 and apicData[2] == 0xff
      mime_type = 'image/jpeg'
    bContent = new Buffer(mime_type.length + 4)
    bContent.fill 0
    bContent[mime_type.length + 2] = 0x03
    #  Front cover
    bContent.write mime_type, 1
    bHeader.writeUInt32BE apicData.length + bContent.length, 4
    #  Size of frame
    return Buffer.concat([
      bHeader
      bContent
      apicData
    ])
  catch e
    return e
  return

_types = (types) ->
  list = []
  for t in types
    if t and t.length and t[0]
      list.push "\\:#{t[0]}"
  for t in types
    if t and t.length > 1 and t[0] and t[1]
      list.push "\\:#{t[0]}\\:#{t[1]}"
  for t in types
    if t and t.length > 2 and t[0] and t[1] and t[2]
      list.push "\\:#{t[0]}\\:#{t[1]}\\:#{t[2]}"
  _.uniq list

_validate = (data) ->
  for key, value of data
    throw new Error "Unknown data property: [#{key}]" unless key in [
      'APIC'
      'name'
      'author'
      'vendor'
      'comment'
      'bankchain'
      'types'
      'modes'
      'syncFilename'
      'removeUnnecessaryChunks'
    ]
    switch key
      when 'name'
        assert.ok _.isString value, "data.name should be String. #{value}"
      when 'author'
        assert.ok _.isString value, "data.author should be String. #{value}"
      when 'vendor'
        assert.ok _.isString value, "data.vendor should be String. #{value}"
      when 'comment'
        if value
          assert.ok _.isString value, "data.vendor should be String. #{value}"
      when 'bankchain'
        if value
          assert.ok _.isArray value, "data.bankchain should be Array of String. #{value}"
          for v in value
            assert.ok _.isString v, "data.bankchain should be Array of String. #{value}"
      when 'types'
        if  value
          assert.ok _.isArray value, "data.types should be 2 dimensional Array of String. #{value}"
          for v in value
            assert.ok _.isArray v, "data.types should be Array of String. #{value}"
            assert.ok v.length > 0 and v.length <= 3, "data.types lenth of inner array should be 1 - 3. #{value}"
            for i in v
              assert.ok _.isString i, "data.types should be 2 dimensional Array of String. #{value}"
      when 'modes'
        # optional (currently unused)
        if  value
          assert.ok _.isArray value, "data.modess should be Array of String. #{value}"
          for v in value
            assert.ok _.isString v, "data.modes should be Array of String. #{value}"

# helper class for building buffer
# ---------------------------------
class BufferBuilder
  constructor: ->
    @buf = new Buffer 0
  #
  # @value byte or byte array or string
  push: (value) ->
    switch
      when _.isNumber value
        # byte
        @buf = Buffer.concat [@buf, new Buffer [value]]
      else
        # string or byte array
        @buf = Buffer.concat [@buf, new Buffer value]
    @

  pushUInt32LE: (value) ->
    b = new Buffer 4
    b.writeUInt32LE value
    @buf = Buffer.concat [@buf, b]
    @

  # 7bit * 4 = 28 bit
  pushSyncsafeInt: (size) ->
    b = []
    b.push ((size >> 21) & 0x0000007f)
    b.push ((size >> 14) & 0x0000007f)
    b.push ((size >>  7) & 0x0000007f)
    b.push (size & 0x0000007f)
    @push b
    @

  pushHex: (value) ->
    @buf = Buffer.concat [@buf, (new Buffer value, 'hex') ]
    @

  pushUcs2String: (value) ->
    l = if value and value.length then value.length else 0
    @pushUInt32LE l
    @buf = Buffer.concat [@buf, (new Buffer value, 'ucs2')] if l
    @

  pushUcs2StringArray: (value) ->
    if (_.isArray value) and value.length
      @pushUInt32LE value.length
      @pushUcs2String v for v in value
    else
      @pushUInt32LE 0
    @

  pushKeyValuePairs: (value) ->
    if (_.isArray value) and value.length
      @pushUInt32LE value.length
      for pair in value
        @pushUcs2String "\\@#{pair[0]}"
        @pushUcs2String pair[1]
    else
      @pushUInt32LE 0
    @
