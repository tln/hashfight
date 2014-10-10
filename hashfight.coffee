fs = require('fs');
Twit = require("twit");
argv = require('yargs')
    .usage('Usage: $0 --config [config.json] hashtag1 hashtag2')
    .demand(2)
    .argv;

hashtags = argv._
counts = [0, 0]

configFile = argv.config || 'config.json'
data = fs.readFileSync configFile
params = JSON.parse data
T = new Twit params

# Our text UI
blessed = require("blessed")
screen = blessed.screen()
border = type: "line"
boxes = [
    blessed.box  top: "top", left: "left", width: "50%", height: "100%", border: border
    blessed.box  top: "top", left: "50%",  width: "50%", height: "100%", border: border
]
update = (ix, tweet) ->
    boxes[ix].setLabel "#{hashtags[ix]}: #{counts[ix]}"
    if tweet
        boxes[ix].insertLine 1, tweet.text+"\n"
    screen.render()

streams = []
for ix in [0, 1]
    do (ix) ->
        screen.append boxes[ix]
        update ix
        streams.push T.stream("statuses/filter",
            track: hashtags[ix]
        )
        .on "tweet", (tweet) ->
           counts[ix]++
           update ix, tweet

screen.key ['escape', 'q', 'C-c'], (ch, key) -> process.exit(0)
