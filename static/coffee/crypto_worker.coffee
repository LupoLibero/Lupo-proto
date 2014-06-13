@window = @
importScripts('../vendor/jsencrypt/bin/jsencrypt.js')
importScripts('../vendor/sjcl/sjcl.js')
importScripts('crypto.js')

@addEventListener 'message',
  (e) ->
    result = crypto.call(e.data.method, e.data.args)
    self.postMessage {
        id: e.data.id
        result: result
      }
  false