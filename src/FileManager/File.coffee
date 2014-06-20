angular.module('fileManager').
factory 'File', ($q, assert, crypto, session, User, storage, cache, $state) ->
  class File
    @TYPES:
      FOLDER: 0
      FILE:   1

    constructor: (pObj) ->
      if pObj
        @_id =       pObj._id
        @_rev =      pObj._rev
        @content =   pObj.content
        @metadata =  pObj.metadata
        #@contentId = pObj.contentId
        @keyId =     pObj.keyId
        if pObj.data?
          if assert.tests.isAnArray(pObj.data) and not(@content?)
            @content = pObj.data
          else
            if assert.tests.isAnObject(pObj.data) and not(@metadata?)
              @metadata = pObj.data

    #
    # Class methods
    #

    @_getDoc: (id, keyId) ->
      _funcName = "_getDoc"
      assert.defined(id, "id", _funcName)
      cacheValue = cache.get(id, "doc")
      if cacheValue?
        return $q.when(cacheValue)
      if keyId
        key = session.getKey(keyId)
      if not key? or not key.length
        key = session.getMasterKey()
      assert.defined(key, "key", _funcName)
      storage.get(id).then (doc) =>
        crypto.decryptDataField(key, doc).then =>
          doc.keyId = keyId
          cache.store(id, "doc", doc)
          return doc

    @getFile: (id, keyId) ->
      _funcName = "@getFile"
      console.log _funcName, id
      assert.defined id, "id",  _funcName
      File._getDoc(id, keyId)
      .then (doc) =>
        file = new File(doc)
        if file.metadata? and file.metadata.contentId?
          File._getDoc(file.metadata.contentId, keyId)
          .then (doc) =>
            file.content = doc.data
            file.contentRev = doc._rev
            return file
        else
          # it is a contentDoc
          console.log "no metadata but content", file
          return file

    @getMetadata: (id, keyId) ->
      console.log "@getMetadata", id
      assert.defined id, "id",  "getMetadata"
      File._getDoc(id, keyId).then(
        (doc) =>
          assert.defined doc.data, "doc.data", "getMetadata"
          return new File(doc)
      )

    @getLastRev: (_id, keyId) ->
      _funcName = "getLastRev"
      console.log _funcName, _id
      assert.defined _id, "_id", _funcName
      File.getMetadata(_id, keyId).then (content) =>
        return content._rev

    #
    # Private methods
    #

    _saveDoc: (doc) ->
      _funcName = "_saveDoc"
      console.log _funcName
      assert.defined(doc, "doc", _funcName)
      if @keyId?
        key = session.getKey(@keyId)
      unless key? or key? and key.length
        key = session.getMasterKey()
      assert.defined(key, "key", _funcName)
      crypto.encryptDataField(key, doc)
      .then =>
        storage.save(doc).then (retVal) =>
          cache.expire(doc._id, "doc")
          return retVal

    _deleteDoc: (doc) ->
      _funcName = "_deleteDoc"
      console.log _funcName
      assert.defined(doc, "doc", _funcName)
      storage.del(doc).then (retVal) =>
        cache.expire(doc._id, "doc")
        return retVal

    #
    # Public methods
    #

    getContent: () ->
      console.log "getContent", @_id
      assert.defined @_id, "@_id", "getContent"
      if @_id == "shares"
        return $q.when(@content)
      File.getFile(@_id, @keyId).then (file) =>
        assert.defined file.content, "file.content", "getContent"
        return file.content

    getParent: ->
      return File.getFile(@metadata.parentId, @keyId)

    isFolder: () ->
      if @content?
        return assert.tests.isAnArray(@content)
      if @metadata?
        return @metadata.type == File.TYPES.FOLDER

    addToFolder: (folderId, keyId) ->
      _funcName = "addToFolder"
      console.log _funcName, folderId
      assert.defined @_id,     "@_id",     _funcName
      assert.defined folderId, "folderId", _funcName
      File.getFile(folderId, keyId)
      .then (folder) =>
        assert.array folder.content, "folder.content", _funcName
        folder.content.push(@_id)
        folder.saveContent().then =>
          @metadata.parentId = folderId
          #TODO: change this to a triggered update via changes watcher
          cache.expire(folder._id, "content")
          folder.listContent()
          @saveMetadata()
      .catch (err) =>
        if err.status == 409
          cache.expire(folderId, "content")
          @addToFolder(folderId, keyId)

    save: () ->
      _funcName = "save"
      console.log _funcName
      if @content?
        @saveContent().then (contentResult) =>
          unless @metadata?
            @_id = contentResult.id
            @_rev = contentResult.rev
            return @
          assert.unchanged(contentResult.id, @metadata.contentId,
            "contentResult.id", "@metadata.contentId", _funcName)
          @metadata.contentId = contentResult.id
          @saveMetadata()
      else
        if @metadata?
          @saveMetadata().then =>
            return @

    saveMetadata: () ->
      _funcName = "saveMetadata"
      console.log _funcName
      metadataDoc = {
        _id: @_id
        _rev: @_rev
        data: @metadata
      }
      @_saveDoc(metadataDoc).then (result) =>
        @_id = result.id
        @_rev = result.rev
        return @

    saveContent: () ->
      _funcName = "saveContent"
      console.log _funcName
      content = {
        data: @content
      }
      if @metadata?
        if @metadata.contentId?
          content._id = @metadata.contentId
        if @contentRev?
          content._rev = @contentRev
      else
        if @_id
          content._id = @_id
        if @_rev
          content._rev = @_rev
      @_saveDoc(content)

    listContent: () ->
      _funcName = "listContent"
      console.log _funcName, @_id
      assert.defined @_id, "@_id", _funcName
      deferred = $q.defer()
      inProgess = []
      #list = cache.get(@_id, "content")
      #if list?
      #  deferred.resolve(list)
      #else
      @getContent().then (content) =>
        assert.array content, "content", _funcName
        list = []
        atLeastOne = false
        for element in content
          if element?
            atLeastOne = true
            inProgess.push(null)
            if angular.isObject(element)
              keyId = element.keyId
              element = element._id
            else
              keyId = undefined
            File.getMetadata(element, keyId).then(
              (file) =>
                if file.isFolder()
                  file.content = []
                list.push(file)
                inProgess.pop()
              (err) =>
                inProgess.pop()
            )
            .then =>
              if inProgess.length == 0
                # if all deferred are terminated #
                console.debug "list", list
                #cache.store(@_id, "content", list)
                deferred.resolve(list)
        unless atLeastOne
          deferred.resolve([])
      .catch (err) =>
        deferred.reject(err)
      return deferred.promise

    rename: (newName) ->
      _funcName = 'rename'
      console.log _funcName, newName
      assert.defined newName, "newName", _funcName
      File.getLastRev(@_id).then (_rev) =>
        @_rev = _rev
        @metadata.name = newName
        @saveMetadata()

    share: (user) ->
      _funcName = "share"
      console.log _funcName, user
      assert.defined user, "user", _funcName
      #TMP: later share would have a "user" parameter
      console.log "user", user
      shareDoc = {
        "_id": crypto.hash(user._id + @_id, 32)
        "data": {
          "docId": @_id
          "key":   session.getMasterKey()
        }
        "userId": user._id
      }
      crypto.asymEncrypt user.publicKey, shareDoc.data
      .then (encData) =>
        shareDoc.data = encData
        storage.save(shareDoc).then =>
          unless @metadata.sharedWith
            @metadata.sharedWith = []
          @metadata.sharedWith.push user.name
          @saveMetadata()

    remove: ->
      _funcName = 'remove'
      console.log _funcName
      if @metadata.contentId?
        @_deleteDoc(@metadata.contentId)
      @_deleteDoc(@_id)

