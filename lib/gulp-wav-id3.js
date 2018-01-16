(function() {
  var BufferBuilder, PLUGIN_NAME, TEXT_FRAMES, _, _build_comment_frame, _build_id3_chunk, _build_picture_frame, _build_text_frame, _filter_prop, _id3, _parseSourceWavChunks, _validate, assert, fs, gutil, iconv, path, riffBuilder, riffReader, through,
    indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

  assert = require('assert');

  path = require('path');

  through = require('through2');

  gutil = require('gulp-util');

  _ = require('underscore');

  riffReader = require('riff-reader');

  riffBuilder = require('./riff-builder');

  fs = require('fs');

  iconv = require('iconv-lite');

  PLUGIN_NAME = 'wav-id3';

  TEXT_FRAMES = ["TALB", "TBPM", "TCOM", "TCON", "TCOP", "TDAT", "TDLY", "TENC", "TEXT", "TFLT", "TIME", "TIT1", "TIT2", "TIT3", "TKEY", "TLAN", "TLEN", "TMED", "TOAL", "TOFN", "TOLY", "TOPE", "TORY", "TOWN", "TPE1", "TPE2", "TPE3", "TPE4", "TPOS", "TPUB", "TRCK", "TRDA", "TRSN", "TRSO", "TSIZ", "TSRC", "TSSE", "TYER"];

  module.exports = function(data) {
    return through.obj(function(file, enc, cb) {
      var alreadyCalled, chunks, error, id3, providedData;
      alreadyCalled = false;
      id3 = (function(_this) {
        return function(err, data) {
          var error;
          if (alreadyCalled) {
            _this.emit('error', new gutil.PluginError(PLUGIN_NAME, 'duplicate callback calls.'));
            return;
          }
          alreadyCalled = true;
          if (err) {
            _this.emit('error', new gutil.PluginError(PLUGIN_NAME, err));
            return cb();
          }
          try {
            if (data) {
              _id3(file, data);
            }
            _this.push(file);
          } catch (error1) {
            error = error1;
            _this.emit('error', new gutil.PluginError(PLUGIN_NAME, error));
          }
          return cb();
        };
      })(this);
      if (!file) {
        id3('File can not be empty');
        return;
      }
      if (file.isStream()) {
        id3('Streaming not supported');
        return;
      }
      if (_.isFunction(data)) {
        try {
          chunks = _parseSourceWavChunks(file);
          providedData = data.call(this, file, chunks, id3);
        } catch (error1) {
          error = error1;
          id3(error);
        }
        if (data.length <= 2) {
          return id3(void 0, providedData);
        }
      } else {
        try {
          _parseSourceWavChunks(file);
        } catch (error1) {
          error = error1;
          return error;
        }
        return id3(void 0, data);
      }
    });
  };

  _parseSourceWavChunks = function(file) {
    var chunks, ids, json, src;
    chunks = [];
    src = file.isBuffer() ? file.contents : file.path;
    json = void 0;
    riffReader(src, 'WAVE').readSync(function(id, data) {
      return chunks.push({
        id: id,
        data: data
      });
    });
    ids = chunks.map(function(chunk) {
      return chunk.id;
    });
    assert.ok((indexOf.call(ids, 'fmt ') >= 0), "[fmt ] chunk is not contained in file.");
    assert.ok((indexOf.call(ids, 'data') >= 0), "[data] chunk is not contained in file.");
    return file.chunks = chunks;
  };

  _id3 = function(file, data) {
    var basename, chunk, chunks, dirname, extname, i, len, wav;
    extname = path.extname(file.path);
    basename = path.basename(file.path, extname);
    dirname = path.dirname(file.path);
    data = _.defaults(data, {
      name: basename,
      syncFilename: true,
      removeUnnecessaryChunks: false
    });
    chunks = data.removeUnnecessaryChunks ? file.chunks.filter(function(c) {
      var ref;
      return (ref = c.id) === 'fmt ' || ref === 'data';
    }) : file.chunks.filter(function(c) {
      return c.id !== 'ID3 ';
    });
    if (data.syncFilename) {
      file.path = path.join(dirname, data.name + extname);
    }
    wav = riffBuilder('WAVE');
    for (i = 0, len = chunks.length; i < len; i++) {
      chunk = chunks[i];
      wav.pushChunk(chunk.id, chunk.data);
    }
    wav.pushChunk('ID3 ', _build_id3_chunk(data));
    return file.contents = wav.buffer();
  };

  _build_id3_chunk = function(data) {
    var f, frames, framesLength, header, i, id3frames, key, len, ref, ref1, textFrames, value;
    textFrames = _filter_prop(data, TEXT_FRAMES);
    console.info('textFrames', textFrames);
    id3frames = [];
    if ((ref = data.APIC) != null ? ref.length : void 0) {
      id3frames.push(_build_picture_frame(data.APIC));
    }
    if ((ref1 = data.COMM) != null ? ref1.length : void 0) {
      id3frames.push(_build_comment_frame({
        text: data.COMM
      }));
    }
    for (key in textFrames) {
      value = textFrames[key];
      if (!(value != null ? value.length : void 0)) {
        continue;
      }
      console.info('key', key);
      id3frames.push(_build_text_frame(key, value));
    }
    console.info('id3frames.length', id3frames.length);
    framesLength = 0;
    for (i = 0, len = id3frames.length; i < len; i++) {
      f = id3frames[i];
      framesLength += f.length;
    }
    console.info('framesLength', framesLength);
    header = new BufferBuilder().push('ID3').push([0x03, 0x00]).push(0x00).pushSyncsafeInt(framesLength + 1024);
    frames = [header.buf].concat(id3frames).concat(Buffer.alloc(1024, 0));
    return Buffer.concat(frames);
  };

  _build_text_frame = function(specName, text) {
    var buffer, contentBuffer, encBuffer, encoded;
    if (!specName || !text) {
      return null;
    }
    encoded = iconv.encode(text, 'utf16');
    buffer = new Buffer(10);
    buffer.fill(0);
    buffer.write(specName, 0);
    buffer.writeUInt32BE(encoded.length + 1, 4);
    encBuffer = new Buffer(1);
    encBuffer.fill(1);
    contentBuffer = new Buffer(encoded, 'binary');
    return Buffer.concat([buffer, encBuffer, contentBuffer]);
  };

  _build_picture_frame = function(pic) {
    var apicData, bContent, bHeader, mime_type;
    apicData = pic instanceof Buffer ? new Buffer(pic) : new Buffer(fs.readFileSync(pic, 'binary'), 'binary');
    bHeader = new Buffer(10);
    bHeader.fill(0);
    bHeader.write('APIC', 0);
    mime_type = 'image/png';
    if (apicData[0] === 0xff && apicData[1] === 0xd8 && apicData[2] === 0xff) {
      mime_type = 'image/jpeg';
    }
    bContent = new Buffer(mime_type.length + 4);
    bContent.fill(0);
    bContent[mime_type.length + 2] = 0x03;
    bContent.write(mime_type, 1);
    bHeader.writeUInt32BE(apicData.length + bContent.length, 4);
    return Buffer.concat([bHeader, bContent, apicData]);
  };

  _build_comment_frame = function(comment) {
    var buffer, commentOptions, commentShortText, commentText;
    comment = comment || {};
    if (!comment.text) {
      return null;
    }
    buffer = new Buffer(10);
    buffer.fill(0);
    buffer.write('COMM', 0);
    commentOptions = new Buffer(4);
    commentOptions.fill(0);
    commentOptions[0] = 0x01;
    comment.language = comment.language || 'eng';
    commentOptions.write(comment.language, 1);
    commentText = new Buffer(iconv.encode(comment.text, 'utf16'));
    comment.shortText = comment.shortText || '';
    commentShortText = iconv.encode(comment.shortText, 'utf16');
    commentShortText = Buffer.concat([commentShortText, comment.shortText === '' ? new Buffer(2).fill(0) : new Buffer(1).fill(0)]);
    buffer.writeUInt32BE(commentOptions.length + commentShortText.length + commentText.length, 4);
    return Buffer.concat([buffer, commentOptions, commentShortText, commentText]);
  };

  _filter_prop = function(validate, filter) {
    var filtered, key, value;
    filtered = {};
    for (key in validate) {
      value = validate[key];
      if (indexOf.call(filter, key) >= 0) {
        filtered[key] = value;
      }
    }
    return filtered;
  };

  _validate = function(data) {
    var key, value;
    for (key in data) {
      value = data[key];
      if (indexOf.call(TEXT_FRAMES, key) < 0 && (key !== 'APIC' && key !== 'COMM' && key !== 'name' && key !== 'syncFilename' && key !== 'removeUnnecessaryChunks')) {
        throw new Error("Unknown data property: [" + key + "]");
      }
      return;
    }
  };

  BufferBuilder = (function() {
    function BufferBuilder() {
      this.buf = new Buffer(0);
    }

    BufferBuilder.prototype.push = function(value) {
      switch (false) {
        case !_.isNumber(value):
          this.buf = Buffer.concat([this.buf, new Buffer([value])]);
          break;
        default:
          this.buf = Buffer.concat([this.buf, new Buffer(value)]);
      }
      return this;
    };

    BufferBuilder.prototype.pushUInt32LE = function(value) {
      var b;
      b = new Buffer(4);
      b.writeUInt32LE(value);
      this.buf = Buffer.concat([this.buf, b]);
      return this;
    };

    BufferBuilder.prototype.pushSyncsafeInt = function(size) {
      var b;
      b = [];
      b.push((size >> 21) & 0x0000007f);
      b.push((size >> 14) & 0x0000007f);
      b.push((size >> 7) & 0x0000007f);
      b.push(size & 0x0000007f);
      this.push(b);
      return this;
    };

    BufferBuilder.prototype.pushHex = function(value) {
      this.buf = Buffer.concat([this.buf, new Buffer(value, 'hex')]);
      return this;
    };

    BufferBuilder.prototype.pushUcs2String = function(value) {
      var l;
      l = value && value.length ? value.length : 0;
      this.pushUInt32LE(l);
      if (l) {
        this.buf = Buffer.concat([this.buf, new Buffer(value, 'ucs2')]);
      }
      return this;
    };

    BufferBuilder.prototype.pushUcs2StringArray = function(value) {
      var i, len, v;
      if ((_.isArray(value)) && value.length) {
        this.pushUInt32LE(value.length);
        for (i = 0, len = value.length; i < len; i++) {
          v = value[i];
          this.pushUcs2String(v);
        }
      } else {
        this.pushUInt32LE(0);
      }
      return this;
    };

    BufferBuilder.prototype.pushKeyValuePairs = function(value) {
      var i, len, pair;
      if ((_.isArray(value)) && value.length) {
        this.pushUInt32LE(value.length);
        for (i = 0, len = value.length; i < len; i++) {
          pair = value[i];
          this.pushUcs2String("\\@" + pair[0]);
          this.pushUcs2String(pair[1]);
        }
      } else {
        this.pushUInt32LE(0);
      }
      return this;
    };

    return BufferBuilder;

  })();

}).call(this);
