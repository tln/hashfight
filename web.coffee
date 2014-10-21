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

    socket.on 'setup-info', (msg) ->
        $top_battles = $("#top_battles")
        debugger;
        for b in msg.top_battles
            do (b) ->
                $e = $("<a>#{b[0]} vs #{b[1]}</a>")
                $e.click ->
                    $entrant1input.val(b[0])
                    $entrant2input.val(b[1])
                    $form.submit()
                $top_battles.append $e
        $top_battles.show()

    socket.on 'battle-start', (msg) ->
        # In response to battle-setup
        $status.html("Battle started")
        for key in ['entrant1', 'entrant2']
            entrants[key].$name.html msg[key].hashtag
            entrants[key].$count.html msg[key].count
            # Add tweets -- animate?
            for tweet in msg[key].recent || []
                $newTweet = $ '<div class="tweet"></div>'
                entrants[key].$tweets.append $newTweet.text(tweet)
            #entrants[key].$name.html msg[key].hashtag
        $body.attr "class", "battling"


    socket.on 'tweet', (msg) ->
        # Whenever we get a tweet, update the count and add a tweet div
        console.log("tweet", msg)
        entrant = entrants[msg.which]
        entrant.$count.text msg.count
        $newTweet = $ '<div class="tweet"></div>'
        entrant.$tweets.prepend $newTweet.text(msg.tweet ? "Let the tweets begin!")


