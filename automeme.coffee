console.log "Starting automeme..."

@get_user = () ->
  user = Session.get('user')
  if not user
    user =
      _id: Math.random().toString()
    Session.set 'user', user

  return user

@default_settings =
  private:
    domain: "gmail.com"
    sendBroadcastEmail: false
    admins: [
    ]
    whitelist:
      emails: []
      twitter: ['wbbradley']
  public:
    title: "automeme"
    server: "http://automeme.co/"
    karma: true
    pageSize: 10

log = (level, msg) ->
  if typeof console != 'undefined'
    console.log "automeme : #{level} : #{msg}"

Invites = new Meteor.Collection 'invites'
Messages = new Meteor.Collection 'messages'
Beers = new Meteor.Collection 'beers'
Comments = new Meteor.Collection 'comments'
Rooms = new Meteor.Collection 'rooms'
Items = new Meteor.Collection 'items'
WeatherReports = new Meteor.Collection 'weather_reports'
Globals = new Meteor.Collection 'globals'

subscribeList =
  'messages': Messages
  'beers': Beers
  'comments': Comments
  'rooms': Rooms
  'items': Items
  'weather_reports': WeatherReports
  'globals': Globals

@getGlobal = (name, _default) ->
  _default or= null
  global = Globals.findOne {name: name}
  if global
    return global.value
  else
    if typeof(_default) is 'function'
      _default = _default()
    return _default

@upsertGlobal = (name, value) ->
  console.log "globals - upserting #{name}"
  console.log value
  global = Globals.findOne {name: name}
  if global
    if typeof(value) is 'object'
      if typeof(global.value) is 'object'
        value = _.extend global.value, value
    Globals.update {_id: global._id},
      $set:
        value: value
        timestamp: Date.now()
  else
    Globals.insert
      name: name
      value: value
      timestamp: Date.now()
    return
  
findThing = (things, name) ->
  if not name
    throw new Error 'No name passed to findRoom'
  thing = things.findOne {lcname: (name or '').toLowerCase()}, {sort: {timestamp: -1}}
  return thing

findRoom = (name) ->
  findThing Rooms, name
findItem = (name) ->
  findThing Items, name

userEmailAddress = (user) ->
  return user?.services?.google?.email or user?.services?.facebook?.email

##################################################################
if Meteor.isClient
  if not Session.get('user')
    Session.set 'user',
      _id: Math.random().toString()

  Meteor.settings = Meteor.settings or {}
  Meteor.settings.public = _.defaults Meteor.settings.public or {}, default_settings.public

  @goToFirstPage = ->
      Session.set 'skipAhead', 0

  @currentRoom = () ->
    Rooms.findOne {}, {sort: {timestamp: -1}}

  Session.set 'pageSize', Meteor.settings.public.pageSize

  goToFirstPage()

  @pickFile = () ->
    filepicker.pick (InkBlob) ->
      switch InkBlob.mimetype
        when 'image/gif' then addImageByUrl InkBlob.url
        else addImageByUrl "#{InkBlob.url}/convert?w=640&fit=clip&format=jpg&quality=95"

  document.title = Meteor.settings.public.title
  dumpColl = (coll) ->
    coll.find().forEach (item) ->
      console.log item

  showNewerMessages = ->
    newSkip = Session.get('skipAhead') - Session.get('pageSize')
    if newSkip < 0
      newSkip = 0
    Session.set 'skipAhead', newSkip
    smoothScroll 'messages'

  showOlderMessages = ->
    Session.set 'skipAhead', Session.get('skipAhead') + Session.get('pageSize')
    smoothScroll 'messages'

  append_time_unit = (diff, unit_name, unit, ret) ->
    if diff > unit
      units = Math.floor diff / unit
      diff -= units * unit
      ret += "#{units} #{unit_name}"
      if units isnt 1
        ret += 's'
    if diff > 0 and units > 0
      ret += ', '
    else if units > 0
      ret += ' ago'
    [diff, ret]

  formatDate = (date) ->
    minute = 60
    hour = 60 * minute
    day = 24 * hour
    week = 7 * day
    moon = 28 * day
    diff = Math.round (Date.now() - date) / 1000.0
    orig_diff = diff
    ret = ''
    if diff >= 60
      diff = diff - (diff % 60)
      [diff, ret] = append_time_unit diff, 'moon', moon, ret
      [diff, ret] = append_time_unit diff, 'week', week, ret
      [diff, ret] = append_time_unit diff, 'day', day, ret
      [diff, ret] = append_time_unit diff, 'hour', hour, ret
      [diff, ret] = append_time_unit diff, 'minute', minute, ret
    else
      ret = 'just now'
    ret

  makeMeme = (_id) ->
    Messages.update {_id: _id},
      $set:
        meme: true
        memeTitle: 'title'
        memeSubtitle: 'subtitle'

  Template.header.helpers
    messagesReady: ->
      subscriptions.messages.ready()

  addComment = (_id) ->
    # Messages.update {_id: _id},
    #   $set:
    #     meme: true
    #     memeTitle: 'title'
    #     memeSubtitle: 'subtitle'

  Template.body.helpers
    background: ->
      @getGlobal('background') or ''
    messagesReady: ->
      subscriptions.messages.ready()

  Template.message.helpers
    'date-render': (timestamp) ->
      formatDate(timestamp)

  Template.message.ownerOrAdmin = ->
    userId = get_user()._id
    return userId is @authorId or isAdminUser userId

  Template.message.lovable = ->
    userId = get_user()._id
    userLoveIds = @userLoveIds or []
    return @authorId isnt userId and userLoveIds.indexOf(userId) is -1

  Template.message.comments = ->
    Comments.find {msgId: @_id}, {sort: {timestamp: 1}}
  
  captureAndSendComment = (message, el) ->
    $input = $(el).closest('[data-comment-form]').find('input[type=text]')
    text = $input.val()
    $input.val('')
    if text.length > 0
      if text[0] is '/'
        cmd = text.slice(1)

        Meteor.call 'messageCmd', message._id, cmd
      else
        Comments.insert
          text: text
          msgId: message._id
          authorId: get_user()._id
          timestamp: Date.now()

  Template.message.events
    'click .delete-btn': () ->
      Messages.update {_id: @_id},
        $set: {deleted: true}
    'click .next-btn': () ->
      if @images.length > 1
        images = @images.slice(1)
        images.push(@imageUrl)
        imageUrl = images[0]
        Messages.update {_id: @_id},
          $set:
            images: images
            imageUrl: imageUrl
    'keypress input[name="text"]': (event) ->
      if event.which is 13
        captureAndSendComment @, event.target
        return false
      return
    'click .comment-btn': () ->
      captureAndSendComment @, event.target
    'click .meme-btn': () ->
      makeMeme @_id
    'click .comment-btn': () ->
      addComment @_id
    'click .love-btn': () ->
      if get_user()._id?
        Messages.update {_id: @_id},
          $addToSet: {userLoveIds: get_user()._id}

  @getUserImage = (authorId) ->
    return "http://b.vimeocdn.com/ps/346/445/3464459_300.jpg"

  @isAdminUser = (userId) ->
    return false

  Template.message.helpers
    ifNotLoved: (context, options) ->
      userLoveIds = @['userLoveIds'] or []
      if userLoveIds.indexOf(get_user()._id) is -1
        return options.fn @
      else
        return options.inverse @
    ifOwner: (context, options) ->
      userId = get_user()._id
      if userId is @authorId or isAdminUser userId
        return options.fn @
      else
        return options.inverse @
    loveLoop: (context, options) ->
      count = @userLoveIds?.length or 0
      if count
        ret = "";
        while count > 0
          ret += options.fn @
          --count
        return ret
      else
        return options.inverse @

    say: (msg) ->
      # $.say msg
      msg


  Template.messages.helpers
    eachItem: (context, options) ->
      currentRoom = currentRoom()
      if currentRoom?._id
        items = Items.find {roomId: currentRoom._id}, {sort: {timestamp: 1}}

        if items.count()
          ret = "Items in this room: ["
          sep = ""
          items.forEach (item) ->
            ret += sep
            ret += options.fn item
            sep = " | "
          ret += ']'
        else
          ret = options.inverse @
        return ret
      else
        return options.inverse @

  Template.messages.roomName = ->
    room = Rooms.findOne {}, {sort: {timestamp: -1}}
    if not room
      return 'VOID'
    if room.name is 'lobby'
      return 'lobby'
    else
      return "#{room.name}"

  Deps.autorun ->
    Template.messages.messages = ->
      currentRoom = Rooms.findOne {}, {sort: {timestamp: -1}}
      if not currentRoom
        return []
      findCriteria =
        roomId: currentRoom._id
        deleted: null
      cursor_count = Messages.find findCriteria, {sort: {timestamp: -1}}
      queryParams =
        sort: timestamp: -1
        limit: Session.get('pageSize')
        skip: Session.get('skipAhead')
      cursor = Messages.find findCriteria, queryParams
      Template.messages.messageCount = cursor_count.count()
      return cursor

  Template.messages.newerMessagesExist = ->
    Template.messages.messageCount > 0 and Session.get('skipAhead') > 0

  Template.messages.olderMessagesExist = ->
    Template.messages.messageCount > Session.get('pageSize') + Session.get('skipAhead')

  Template.body.roomName = ->
    room = Rooms.findOne {}, {sort: {timestamp: -1}}
    if not room
      return ''
    if room.lcname is 'lobby'
      return 'lobby'
    else
      return "#{room.name} room"

  @balanceText = (event) ->
    $(event.target).parent().textfill
      maxFontPixels: 90
      maxWidth: $(event.target).parents('.meme-container').width() - 40

  @updateMeme = (_id) ->
    title = $("#meme-#{_id}-title")[0]?.innerHTML or ''
    subtitle = $("#meme-#{_id}-subtitle")[0]?.innerHTML or ''
      
    Messages.update {_id: _id},
      $set:
        memeTitle: title
        memeSubtitle: subtitle


  Template.memeDisplay.rendered = Template.memificator.rendered = ->
    $firstNode = $(@firstNode)
    maxWidth = $firstNode.width() - 40
    $firstNode.find('.meme-text').each ->
      $(@).parent().textfill
        maxFontPixels: 90
        maxWidth: maxWidth
    return

  Template.memificator.events
    'keyup .meme-text': @balanceText
    'blur .meme-text': (event) -> window.updateMeme $(event.target).data('msg-id')
      
  @getItemImage = (itemId) ->
    item = Items.findOne {_id: itemId}
    if not item
      return
    imageUrl = window.prompt "Enter an image url for #{item.name}:"
    console.log imageUrl
    if /^http/.test imageUrl
      Items.update {_id: itemId},
        $set: {imageUrl: imageUrl}
    return

  @switchToRoom = (roomName) ->
    room = findRoom roomName
    if room
      Rooms.update {_id: room._id},
        $set: {timestamp: Date.now()}
    else
      Rooms.insert
        name: roomName
        lcname: roomName.toLowerCase()
        timestamp: Date.now()

  @takeItem = (itemName, currentRoom) ->
    currentRoom or= currentRoom()
    item = findItem itemName
    if item
      if item.roomId is currentRoom._id
        if typeof item.holderId isnt 'string'
          if item.creatorId isnt get_user()._id
            Items.update {_id: item._id},
              $set:
                holderId: get_user()._id
                roomId: null
          else
            window.alert "You cannot hold your own creations."
        else
          window.alert "The #{item.name} already has a holder."
      else
        window.alert "The #{item.name} is not in this room."
    else
      window.alert "There is no such thing as the #{item.name}. Are you not familiar with /place?"
      
  @placeItem = (itemName, room) ->
    room or= currentRoom()
    item = findItem itemName
    if item
      if item.holderId is get_user()._id
        Items.update {_id: item._id},
          $set:
            holderId: null
            roomId: room._id
      else
        window.alert "You are not holding the #{item.name}"
    else
      Items.insert
        name: itemName
        lcname: itemName.toLowerCase()
        timestamp: Date.now()
        roomId: room._id
        creatorId: get_user()._id
        holderId: null

  @addImageByUrl = (imageUrl) ->
    if imageUrl
      Messages.insert
        imageUrl: imageUrl
        timestamp: Date.now()
        authorId: get_user()._id
        roomId: currentRoom()._id
      goToFirstPage()

  @hadBeers = (count) ->
    count = parseFloat(count)
    if count > 0
      Beers.insert
        timestamp: Date.now()
        userId: get_user()._id


  @search = (search) ->
    searchString = search
    Meteor.call 'search', search, get_user()._id, currentRoom()._id


  @addMemeByUrl = (imageUrl) ->
    if imageUrl
      Messages.insert
        imageUrl: imageUrl
        timestamp: Date.now()
        authorId: get_user()._id
        roomId: currentRoom()._id
        meme: true
        memeTitle: 'title'
        memeSubtitle: 'subtitle'
      goToFirstPage()

  @addYouTubePlaylist = (youtube) ->
    if youtube
      Messages.insert
        youtube: encodeURIComponent youtube
        timestamp: Date.now()
        authorId: get_user()._id
        roomId: currentRoom()._id
      goToFirstPage()

  captureAndSendMessage = ->
    msg = $('input[name="new-message"]').val()
    $('input[name="new-message"]').val('')
    if msg
      log 'info', msg

      cmdTable =
        room: switchToRoom
        place: placeItem
        take: takeItem
        image: addImageByUrl
        meme: addMemeByUrl
        youtube: addYouTubePlaylist
        beers: hadBeers
        search: search

      re = /^\/([^ ]+) (.*)$/
      match = re.exec msg
      if match
        cmd = match[1]
        arg = match[2]
        if cmd of cmdTable
          cmdTable[cmd] arg
      else
        # handle lone image urls
        reImage = /.*(http[s]?:\/\/.*(JPG|JPEG|GIF|PNG|jpg|jpeg|gif|png))(\s|$).*/
        match = msg.match reImage
        if match
          addImageByUrl match[1]
        else
          cmdTable.search msg

        Session.set 'skipAhead', 0

  Template['send-message'].helpers
    filepickerEnabled: ->
      return Boolean(getGlobal 'filepickerApiKey')

  Template['send-message'].events
    'keypress input[name="new-message"]': (event) ->
      if event.which is 13
        captureAndSendMessage()
        return false
      return
    'click [name=send]' : ->
      captureAndSendMessage()

  karmaCalc = () ->
    points = 0
    if get_user()
      userId = get_user()._id
      findCriteria =
        authorId: userId
        deleted: $ne: true
      cursor = Messages.find findCriteria
      cursor.forEach (message) ->
        if message.userLoveIds?
          points += message.userLoveIds.length
    return points: points

  for name, template of Template
    template.settings = Meteor.settings.public
    if Meteor.settings.public.karma is true
      template.karma = karmaCalc

  @subscriptions = {}
  for name, collection of subscribeList
    @subscriptions[name] = Meteor.subscribe name

  getMaxFontSize = (width) ->
    if width > 767
      return 180
    else
      return 90
  window.onresize = _.debounce((->
    $('.meme-text').each ->
      $(this).parent().textfill
        maxFontPixels: getMaxFontSize window.innerWidth
        maxWidth: $(this).parents('.meme-container').width() - 40
  ), 1000)

if Meteor.isServer
  """
  Meteor.Router.add '/boris/:state', (state) ->
    if state is 'in'
      upsertGlobal 'boris', true
    if state is 'out'
      upsertGlobal 'boris', false
  Meteor.Router.add '/boris', () ->
    if getGlobal('boris')
      return "boris is here"
    else
      return "boris is not here"
  """
  @throwPermissionDenied = ->
    throw new Meteor.Error 403, "We're sorry, #{Meteor.settings.private?.domain or '<domain>'} is not open to the public. Please contact your host for an invitation."

  @addToEmailWhitelist = (email) ->
    privateSettings = Meteor.settings.private
    if _.indexOf(privateSettings.whitelist.emails, email, true) is -1
      console.log "Adding invited user '#{email}' to whitelist"
      privateSettings.whitelist.emails.push email
      privateSettings.whitelist.emails = ([].concat privateSettings.whitelist.emails).sort()
    console.log "New whitelist is [#{privateSettings.whitelist.emails.join(', ')}]"

  Meteor.methods
    messageCmd: (message_id, cmd) ->
      console.log message_id
      tokens = cmd.split(' ')
      if tokens.length is 2
        if tokens[0] is 'rm' and ((tokens[1] is Meteor.settings?.private?.password) or not Meteor.settings.private?.password?)
          Messages.update {_id: message_id},
            $set: {deleted: true}

      return

    search: (searchString, user_id, room_id) ->
      url = "https://ajax.googleapis.com/ajax/services/search/images?v=1.0&as_filetype=gif&q=#{encodeURIComponent(searchString)}"
      Meteor.http.get url, (error, result) ->
        if error?
          console.dir error
        if result?.content?
          results = (JSON.parse result.content)?.responseData?.results
          if results and results.length > 0
            images = (item.unescapedUrl for item in results)
            images = _.uniq images
            imageUrl = images[0]
            if imageUrl
              words = searchString.split ' '
              half = Math.floor(words.length / 2)
              title = words.slice(0, half).join(' ')
              subTitle = words.slice(half).join(' ')
              Messages.insert
                imageUrl: imageUrl
                images: images
                timestamp: Date.now()
                authorId: user_id
                roomId: room_id
                meme: true
                memeTitle: title
                memeSubtitle: subTitle

  Meteor.settings = _.defaults Meteor.settings, default_settings

  @initWhitelist = ->
    # Sort the whitelists
    for list_name of Meteor.settings.private.whitelist
      Meteor.settings.private.whitelist[list_name] = ([].concat Meteor.settings.private.whitelist[list_name]).sort()

    Invites.find().forEach (invite) ->
      addToEmailWhitelist invite.emailInvited
  initWhitelist()
  endsWith = (string, suffix) ->
      string.indexOf(suffix, string.length - suffix.length) isnt -1

  publishCollection = (name, collection) ->
    Meteor.publish name, () ->
      return collection.find '$or': [{'deleted': $exists: false}, {'deleted': false}]

    collection.allow
      insert: (userId, doc) ->
        return true
      update: (userId, doc, fieldNames, modifier) ->
        return true
      remove: (userId, doc) ->
        return true

  for name, collection of subscribeList
    publishCollection name, collection

  Accounts.validateNewUser (user) ->
    if validUserByEmail user
      return true
    do @throwPermissionDenied

  collectWeatherReport = ->
    # http://www.wunderground.com/weather/api/d/docs?d=data/conditions
    weather_api_url = Meteor.settings.private.weather.url
    Meteor.http.get weather_api_url, (error, result) ->
      if result?.data?
        WeatherReports.insert result.data.current_observation, (obj, _id) ->
          log 'info', 'collected weather data'
          WeatherReports.remove _id: $ne: _id

  Meteor.startup ->
    if not Meteor.settings.public?.title
      throw new Error "Settings are uninitialized."
    console.log "Starting #{Meteor.settings.public.title}"
    if Meteor.settings.private?.weather
      collectWeatherReport()
      Meteor.setInterval collectWeatherReport, 5 * 60 * 1000

    lobby = findRoom 'lobby'
    if lobby
      lobbyId = lobby._id
    else
      lobbyId = Rooms.insert
        name: 'lobby'
        lcname: 'lobby'
        timestamp: Date.now()

@Rooms = Rooms
@Items = Items
@Messages = Messages
@Beers = Beers
@Globals = Globals
@WeatherReports = WeatherReports
@formatDate = formatDate
@makeMeme = makeMeme
@addComment = addComment
@dumpColl = dumpColl
@userEmailAddress = userEmailAddress
@showNewerMessages = showNewerMessages
@showOlderMessages = showOlderMessages
