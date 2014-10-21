# Modules
redis = require('then-redis')

# Use the same RSVP instance that then-redis does so we can install
# catch-all logic. Re-export the module so that callers can use 'all'
RSVP = require('then-redis/node_modules/rsvp')
RSVP.on 'error', (reason) -> console.log "RSVP uncaught error", reason, reason.stack
exports.all = RSVP.all

# Main entry point
exports.connect = (options) ->
    switch options?.type
        when 'redis'
        then new RedisDb options
        else new Db

# Bootstrap data
exports.example_battles = example_battles = [
    ['lakers', 'warriors'],
    ['giants', 'cardinals'],
    ['emacs', 'vim']
]

# Wrap a value in a promise
wrap = (value) -> new RSVP.Promise (resolve, reject) -> resolve value

class Db
    # This is the base / dummy implementation
    # All query methods return promises
    constructor: -> @reset()
    reset: ->
        @counts = {}
        @recent = {}
    disconnect: ->
    top_battles: -> wrap example_battles
    recent_tweets: (hashtag) -> wrap @recent[hashtag] || []
    count: (hashtag) -> wrap @counts[hashtag] || 0
    add_battle: (hashtag1, hashtag2) ->
    add_tweet: (hashtag, tweet) ->
        # Update a counter and store recent tweets
        if list = @recent[hashtag]
            list.push(tweet)
            @counts[hashtag]++
        else
            @recent[hashtag] = [tweet]
            @counts[hashtag] = 1

errorfunc = (msg) ->
    (err) -> console.log "#{msg}:", err

class RedisDb extends Db
    constructor: (redis_params, @max_battles = 25, @max_tweets = 100) ->
        @cli = redis.createClient redis_params
        @cli.connect()
    reset: ->
        @cli.del("top_battles", "count")
        p = @cli.keys("tweets.*")
        p.then (keys) => @cli.del(keys).catch()
    disconnect: ->
        @cli.disconnect()
    top_battles: ->
        p = @cli.zrevrange 'top_battles', 0, @max_battles - 1
        p.then (top) -> top.map JSON.parse
    add_battle: (hashtag1, hashtag2) ->
        @cli.zincrby 'top_battles', 1, JSON.stringify([hashtag1, hashtag2])
    add_tweet: (hashtag, tweet) ->
        # Update a counter and store recent tweets
        @cli.zincrby 'count', 1, hashtag
        @cli.lpush 'tweets.' + hashtag, tweet
        @cli.ltrim 'tweets.' + hashtag, 0, @max_tweets
    recent_tweets: (hashtag) ->
        @cli.lrange 'tweets.' + hashtag, 0, @max_tweets - 1
    count: (hashtag) ->
        p = @cli.zscore 'count', hashtag
        p.then (count) -> count || 0
