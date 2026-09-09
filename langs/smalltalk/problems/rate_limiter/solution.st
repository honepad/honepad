Object subclass: KeyState [
    | limit window windowId used |

    KeyState class >> new [
        ^(self basicNew) initialize
    ]

    initialize [
        limit := 3.
        window := 10.
        windowId := nil.
        used := 0
    ]

    limit [ ^limit ]
    window [ ^window ]
    windowId [ ^windowId ]
    used [ ^used ]

    limit: value [ limit := value ]
    window: value [ window := value ]
    windowId: value [ windowId := value ]
    used: value [ used := value ]
]

Object subclass: Simulation [
    | keys |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        keys := Dictionary new
    ]

    state: key [
        ^keys at: key ifAbsentPut: [KeyState new]
    ]

    usedAt: item timestamp: timestamp persist: persist [
        | windowId |
        windowId := timestamp // item window.
        (item windowId isNil or: [windowId ~= item windowId]) ifTrue: [
            persist ifTrue: [
                item windowId: windowId.
                item used: 0
            ].
            ^0
        ].
        ^item used
    ]

    allow: key with: timestamp [
        ^self allowWeighted: key with: 1 with: timestamp
    ]

    configure: key with: limit with: window [
        | item |
        (limit <= 0 or: [window <= 0]) ifTrue: [^'invalid_request'].
        item := self state: key.
        item limit: limit.
        item window: window.
        item windowId: nil.
        item used: 0.
        ^'true'
    ]

    remaining: key with: timestamp [
        | item used |
        item := self state: key.
        used := self usedAt: item timestamp: timestamp persist: false.
        ^(item limit - used) printString
    ]

    allowWeighted: key with: cost with: timestamp [
        | item |
        cost <= 0 ifTrue: [^'invalid_request'].
        item := self state: key.
        self usedAt: item timestamp: timestamp persist: true.
        (item used + cost > item limit) ifTrue: [^'false'].
        item used: item used + cost.
        ^'true'
    ]
]
