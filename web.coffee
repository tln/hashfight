# Web client app
$ ->
    # Document ready
    $body = $.one "body"
    $status = $.one "#status"
    $form = $.one "#battle-setup"
    $entrant1input = $.one "#entrant1-input"
    $entrant2input = $.one "#entrant2-input"
    entrants =
        entrant1:
            $name: $.one "#entrant1 .name"
            $count: $.one "#entrant1 .count"
            $tweets: $.one "#entrant1 .tweets"
        entrant2:
            $name: $.one "#entrant2 .name"
            $count: $.one "#entrant2 .count"
            $tweets: $.one "#entrant2 .tweets"

    socket = io.connect()
    socket.on 'connect', ->
        $status.html("Connected")

    $form.submit ->
        $status.html("Starting battle")
        socket.emit 'battle-setup',
            entrant1: $entrant1input.val()
            entrant2: $entrant2input.val()
        return false

    socket.on 'battle-start', (msg) ->
        # In response to battle-setup
        $status.html("Battle started")
        entrants.entrant1.$name.html msg.entrant1
        entrants.entrant2.$name.html msg.entrant2
        $body.attr "class", "battling"

    socket.on 'tweet', (msg) ->
        # Whenever we get a tweet, update the count and add a tweet div
        console.log("tweet", msg)
        entrant = entrants[msg.which]
        entrant.$count.text msg.count
        $newTweet = $ '<div class="tweet"></div>'
        entrant.$tweets.prepend $newTweet.text(msg.tweet ? "Let the tweets begin!")


