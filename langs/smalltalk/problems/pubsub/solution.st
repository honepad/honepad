Object subclass: Simulation [
    | subs inboxMap retained |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        subs := Dictionary new.
        inboxMap := Dictionary new.
        retained := Dictionary new
    ]

    join: parts [
        | s |
        parts isEmpty ifTrue: [^''].
        s := parts first.
        2 to: parts size do: [:idx | s := s, ', ', (parts at: idx)].
        ^s
    ]

    subscribe: topic with: client [
        | clients items |
        clients := subs at: topic ifAbsentPut: [OrderedCollection new].
        (clients includes: client) ifTrue: [^'false'].
        clients add: client.
        (retained includesKey: topic) ifTrue: [
            items := inboxMap at: client ifAbsentPut: [OrderedCollection new].
            items add: topic, ':', (retained at: topic)
        ].
        ^'true'
    ]

    unsubscribe: topic with: client [
        | clients |
        clients := subs at: topic ifAbsent: [^'false'].
        (clients includes: client) ifFalse: [^'false'].
        clients remove: client.
        clients isEmpty ifTrue: [subs removeKey: topic].
        ^'true'
    ]

    publish: topic with: message [
        | clients payload items |
        clients := subs at: topic ifAbsent: [OrderedCollection new].
        payload := topic, ':', message.
        clients do: [:client |
            items := inboxMap at: client ifAbsentPut: [OrderedCollection new].
            items add: payload
        ].
        ^clients size printString
    ]

    inbox: client [
        | items |
        items := inboxMap at: client ifAbsent: [^''].
        ^self join: items
    ]

    listTopics [
        ^self join: subs keys asSortedCollection
    ]

    subscribers: topic [
        | clients |
        clients := subs at: topic ifAbsent: [^''].
        ^self join: clients asSortedCollection
    ]

    peek: client [
        | items |
        items := inboxMap at: client ifAbsent: [^''].
        items isEmpty ifTrue: [^''].
        ^items first
    ]

    ack: client with: n [
        | items |
        (n <= 0) ifTrue: [^'invalid_request'].
        items := inboxMap at: client ifAbsent: [^'invalid_request'].
        (n > items size) ifTrue: [^'invalid_request'].
        n timesRepeat: [items removeFirst].
        ^items size printString
    ]

    retain: topic with: message [
        retained at: topic put: message.
        ^''
    ]
]
