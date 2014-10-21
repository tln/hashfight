# Modules
fs = require('fs')
Twit = require("twit")
redis = require('then-redis')
yargs = require('yargs')
DB = require('./DB')

# Process command line
yargs.usage('Usage: $0 [--serve] [--config config.json] [hashtag1 hashtag2]')
argv = yargs.argv
if argv._.length == 0
    cli = false
    web = true
else if argv._.length == 2
    cli = true
    hashtags = argv._
    web = argv.serve
else
    yargs.demand(2)

# Load/process config
configFile = argv.config || 'config.json'
data = fs.readFileSync configFile
params = JSON.parse data
T = new Twit params.twitter
db = DB.connect params.db

# Generic utils

# Shows status  (This will be overridden if the Text UI is used)
statusLine = (status) -> console.log(status)

# Creates an error handling function
errorfunc = (type) -> console.log.bind(console, type)

# Makes a setter, useful to chain with .then
set = (object, key) -> (value) -> object[key] = value


# Abstractions of our game
class Entrant
    constructor: (@hashtag, @data) ->
        @count = 0
    stream: (handler) ->
        @twitStream = T.stream("statuses/filter",
            track: @hashtag
        )
        @twitStream.on "tweet", (tweet) =>
            @count++
            db.add_tweet @hashtag, tweet.text
            handler @, tweet

        @twitStream.on 'error', (obj) -> console.log('Twitter error:', obj)
        @twitStream.on 'warning', (obj) -> console.log('Twitter warning:', obj)
        @twitStream.on 'disconnect', (obj) -> console.log('Twitter disconnect:', obj)
        @twitStream.on 'limit', (obj) -> console.log('Twitter limit:', obj)

    stop: ->
        @twitStream.stop()

class Battle
    constructor: (entrant1, entrant2) ->
        # Pass in entrant objects
        @entrants = [entrant1, entrant2]
        db.add_battle entrant1.hashtag, entrant2.hashtag
        # Update counts
        @upd = DB.all([
            db.count(entrant1.hashtag).then set entrant1, 'count'
            db.count(entrant2.hashtag).then set entrant2, 'count'
        ])
    start: (handler) ->
        @upd.finally =>
            handler e, null for e in @entrants
            e.stream handler for e in @entrants
    stop: ->
        e.stop() for e in @entrants


# Command line app state
if cli
    # Our text UI
    title = "{center}HASHFIGHT v0.1"
    blessed = require("blessed")
    screen = blessed.screen()
    border = type: "line"
    boxes = []
    screen.append boxes[0] = (blessed.box  top: 1, left: 0, width: "50%", bottom: 1, border: border)
    screen.append boxes[1] = (blessed.box  top: 1, left: "50%",  width: "50%", bottom: 1, border: border)
    screen.append blessed.box top: 0, left: 0, right: 0, height: 1, tags: true, content: title, bg: "green"
    screen.append footer = blessed.box bottom: 0, left: 0, right: 0, height: 1, tags: true, bg: "green"
    screen.key ['escape', 'q', 'C-c'], (ch, key) -> process.exit(0)
    statusLine = (status) ->
        footerbox.setContent "{center}#{status}"
        screen.render()

    # Stream the tweets!
    battle = new Battle(
        new Entrant(hashtags[0], boxes[0]),
        new Entrant(hashtags[1], boxes[1]))
    battle.start (entrant, tweet) ->
        box = entrant.data
        box.setLabel "#{entrant.hashtag}: #{entrant.count}"
        if tweet
            box.insertLine 1, tweet.text+"\n"
        screen.render()

# Our web UI
if web
    express = require('express')
    app = express().use('/', express.static(__dirname))
    io = require('socket.io').listen(app.listen(8080))
    serverInfo = "Listening on http://localhost:8080"
    statusLine(serverInfo)
    io.sockets.on 'connection', (socket) ->
        battle = null   # Per connection battle

        statusLine "#{serverInfo}: Connect!"

        db.top_battles().then (battles) ->
            console.log("top battles", typeof battles, battles.length, battles)
            socket.emit "setup-info", top_battles: battles

        socket.on 'battle-setup', (msg) ->
            # We have a battle to run!
            battle = new Battle(
                new Entrant(msg.entrant1, 'entrant1'),
                new Entrant(msg.entrant2, 'entrant2'))

            # Emit back an acknowledgement. Include the current counts
            # and recent tweets
            start_msg =
                entrant1:
                    hashtag: msg.entrant1
                entrant2:
                    hashtag: msg.entrant2
            p = []
            for k, entrant of start_msg
                p.push db.recent_tweets(entrant.hashtag).then set entrant, 'recent'
                p.push db.count(entrant.hashtag).then set entrant, 'count'
            DB.all(p).finally ->
                socket.emit 'battle-start', start_msg

                # Run the battle!
                battle.start (entrant, tweet) ->
                    statusLine "#{serverInfo}: #{entrant.hashtag} #{entrant.count}"
                    socket.emit 'tweet',
                        which: entrant.data
                        count: entrant.count
                        tweet: tweet?.text

        socket.on 'disconnect', ->
            statusLine "#{serverInfo}: disconnect"
            if battle
                battle.stop()

