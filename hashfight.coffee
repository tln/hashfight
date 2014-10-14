# Process command line
yargs = require('yargs')
    .usage('Usage: $0 [--serve] [--config config.json] [hashtag1 hashtag2]')
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

# Load config
fs = require('fs')
Twit = require("twit")
configFile = argv.config || 'config.json'
data = fs.readFileSync configFile
params = JSON.parse data
T = new Twit params

statusLine = (status) -> console.log(status)

class Entrant
    constructor: (@hashtag, @data) ->
        @count = 0
    stream: (handler) ->
        T.stream("statuses/filter",
            track: @hashtag
        )
        .on "tweet", (tweet) =>
            @count++
            handler @, tweet

class Battle
    constructor: (entrant1, entrant2) ->
        # Pass in entrant objects
        @entrants = [entrant1, entrant2]
    start: (handler) ->
        handler e, null for e in @entrants
        e.stream handler for e in @entrants

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
        statusLine "#{serverInfo}: Connect!"

        socket.on 'battle-setup', (msg) ->
            # We have a battle to run!
            battle = new Battle(
                new Entrant(msg.entrant1, 'entrant1'),
                new Entrant(msg.entrant2, 'entrant2'))

            # Emit back an acknowledgement. In the future
            # this might include additional info.
            socket.emit 'battle-start',
                entrant1: msg.entrant1
                entrant2: msg.entrant2

            # Run the battle!
            battle.start (entrant, tweet) ->
                statusLine "#{serverInfo}: #{entrant.hashtag} #{entrant.count}"
                socket.emit 'tweet',
                    which: entrant.data
                    count: entrant.count
                    tweet: tweet?.text

