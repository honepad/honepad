Object subclass: Backend [
    | backendId health weight inflight |

    Backend class >> id: anId [
        ^(self new)
            setId: anId;
            yourself
    ]

    setId: anId [
        backendId := anId.
        health := true.
        weight := 1.
        inflight := 0
    ]

    backendId [ ^backendId ]
    health [ ^health ]
    health: value [ health := value ]
    weight [ ^weight ]
    weight: value [ weight := value ]
    inflight [ ^inflight ]
    inflight: value [ inflight := value ]
]

Object subclass: Simulation [
    | backends byId cursor stickyMap useLeast |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        backends := OrderedCollection new.
        byId := Dictionary new.
        cursor := 0.
        stickyMap := Dictionary new.
        useLeast := false
    ]

    resetCycle [
        cursor := 0.
        useLeast := false.
        backends do: [:item | item inflight: 0]
    ]

    tickets: items [
        | out |
        out := OrderedCollection new.
        items do: [:item |
            1 to: item weight do: [:i | out add: item]
        ].
        ^out
    ]

    pick [
        | healthy pool tickets chosen |
        healthy := backends select: [:item | item health].
        healthy isEmpty ifTrue: [^nil].
        pool := healthy.
        useLeast ifTrue: [
            | least |
            least := (healthy collect: [:item | item inflight]) inject: (healthy first inflight) into: [:a :b | a min: b].
            pool := healthy select: [:item | item inflight = least]
        ].
        tickets := self tickets: pool.
        tickets isEmpty ifTrue: [^nil].
        chosen := tickets at: (cursor \\ tickets size) + 1.
        cursor := cursor + 1.
        ^chosen
    ]

    take [
        | item |
        item := self pick.
        item isNil ifTrue: [^''].
        item inflight: item inflight + 1.
        ^item backendId
    ]

    addBackend: backendId [
        (byId includesKey: backendId) ifTrue: [^'false'].
        backends add: (Backend id: backendId).
        byId at: backendId put: backends last.
        ^'true'
    ]

    setHealth: backendId with: flag [
        | item |
        item := byId at: backendId ifAbsent: [^'invalid_request'].
        (flag = 0 or: [flag = 1]) ifFalse: [^'invalid_request'].
        item health: flag = 1.
        self resetCycle.
        ^'true'
    ]

    setWeight: backendId with: weight [
        | item |
        item := byId at: backendId ifAbsent: [^'invalid_request'].
        weight <= 0 ifTrue: [^'invalid_request'].
        item weight: weight.
        self resetCycle.
        ^'true'
    ]

    route [
        ^self take
    ]

    sticky: clientId [
        | bound item chosen |
        bound := stickyMap at: clientId ifAbsent: [nil].
        item := bound isNil ifTrue: [nil] ifFalse: [byId at: bound ifAbsent: [nil]].
        (item notNil and: [item health]) ifTrue: [
            item inflight: item inflight + 1.
            ^item backendId
        ].
        chosen := self take.
        chosen isEmpty ifFalse: [stickyMap at: clientId put: chosen].
        ^chosen
    ]

    done: backendId [
        | item |
        item := byId at: backendId ifAbsent: [^'invalid_request'].
        item inflight <= 0 ifTrue: [^'invalid_request'].
        item inflight: item inflight - 1.
        useLeast := true.
        ^'true'
    ]
]
