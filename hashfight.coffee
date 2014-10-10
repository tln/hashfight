# Process command line
argv = require('yargs')
    .usage('Usage: $0 --config [config.json] hashtag1 hashtag2')
    .demand(2)
    .argv;

# Main state
hashtags = argv._
counts = [0, 0]

# Load config
fs = require('fs')
Twit = require("twit")
configFile = argv.config || 'config.json'
data = fs.readFileSync configFile
params = JSON.parse data
T = new Twit params

# Our text UI
title = "{center}HASH BATTLE"
footer = "{center}http://localhost:8080 (coming soon)"
blessed = require("blessed")
screen = blessed.screen()
border = type: "line"
boxes = []
screen.append boxes[0] = (blessed.box  top: 1, left: 0, width: "50%", bottom: 1, border: border)
screen.append boxes[1] = (blessed.box  top: 1, left: "50%",  width: "50%", bottom: 1, border: border)
screen.append blessed.box top: 0, left: 0, right: 0, height: 1, tags: true, content: title, bg: "green"
screen.append blessed.box bottom: 0, left: 0, right: 0, height: 1, tags: true, content: footer, bg: "green"
screen.key ['escape', 'q', 'C-c'], (ch, key) -> process.exit(0)
update = (ix, tweet) ->
    boxes[ix].setLabel "#{hashtags[ix]}: #{counts[ix]}"
    if tweet
        boxes[ix].insertLine 1, tweet.text+"\n"
    screen.render()

# Stream the tweets!
for ix in [0, 1]
    do (ix) ->
        update ix
        T.stream("statuses/filter",
            track: hashtags[ix]
        )
        .on "tweet", (tweet) ->
           counts[ix]++
           update ix, tweet

