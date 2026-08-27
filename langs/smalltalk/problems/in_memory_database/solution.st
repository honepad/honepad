Object subclass: InMemoryDatabase [
    | database backupTimestamps backupStates |

    InMemoryDatabase class >> new [
        ^self basicNew initialize
    ]

    initialize [
        database := Dictionary new.
        backupTimestamps := OrderedCollection new.
        backupStates := OrderedCollection new
    ]

    setInternal: key field: field value: value expiry: expiry [
        (database at: key ifAbsentPut: [Dictionary new]) at: field put: {value. expiry}.
        ^''
    ]

    isAlive: key field: field timestamp: timestamp [
        | rec expiry |
        (database includesKey: key) ifFalse: [^false].
        rec := (database at: key) at: field ifAbsent: [^false].
        expiry := rec at: 2.
        expiry isNil ifTrue: [^true].
        ^timestamp < expiry
    ]

    set: key with: field with: value [
        ^self setInternal: key field: field value: value expiry: nil
    ]

    get: key with: field [
        | rec |
        (database includesKey: key) ifFalse: [^''].
        rec := (database at: key) at: field ifAbsent: [^''].
        ^rec at: 1
    ]

    delete: key with: field [
        | fields |
        (database includesKey: key) ifFalse: [^'false'].
        fields := database at: key.
        (fields includesKey: field) ifFalse: [^'false'].
        fields removeKey: field.
        ^'true'
    ]

    join: parts [
        | s |
        parts isEmpty ifTrue: [^''].
        s := parts first.
        2 to: parts size do: [:idx | s := s, ', ', (parts at: idx)].
        ^s
    ]

    scan: key [
        | fields names parts |
        (database includesKey: key) ifFalse: [^''].
        fields := database at: key.
        names := fields keys asSortedCollection.
        parts := names collect: [:field |
            field, '(', ((fields at: field) at: 1), ')'
        ].
        ^self join: parts
    ]

    scanByPrefix: key with: prefix [
        | fields names parts |
        (database includesKey: key) ifFalse: [^''].
        fields := database at: key.
        names := fields keys select: [:field | field startsWith: prefix].
        names := names asSortedCollection.
        parts := names collect: [:field |
            field, '(', ((fields at: field) at: 1), ')'
        ].
        ^self join: parts
    ]

    setAt: key with: field with: value with: timestamp [
        ^self setInternal: key field: field value: value expiry: nil
    ]

    setAtWithTtl: key with: field with: value with: timestamp with: ttl [
        ^self setInternal: key field: field value: value expiry: timestamp + ttl
    ]

    deleteAt: key with: field with: timestamp [
        | fields |
        (self isAlive: key field: field timestamp: timestamp) ifFalse: [^'false'].
        fields := database at: key.
        fields removeKey: field.
        ^'true'
    ]

    getAt: key with: field with: timestamp [
        | rec |
        (self isAlive: key field: field timestamp: timestamp) ifFalse: [^''].
        rec := (database at: key) at: field.
        ^rec at: 1
    ]

    scanAt: key with: timestamp [
        | fields names parts |
        (database includesKey: key) ifFalse: [^''].
        fields := database at: key.
        names := fields keys select: [:field |
            self isAlive: key field: field timestamp: timestamp
        ].
        names := names asSortedCollection.
        parts := names collect: [:field |
            field, '(', ((fields at: field) at: 1), ')'
        ].
        ^self join: parts
    ]

    scanByPrefixAt: key with: prefix with: timestamp [
        | fields names parts |
        (database includesKey: key) ifFalse: [^''].
        fields := database at: key.
        names := fields keys select: [:field |
            (field startsWith: prefix) and: [
                self isAlive: key field: field timestamp: timestamp]
        ].
        names := names asSortedCollection.
        parts := names collect: [:field |
            field, '(', ((fields at: field) at: 1), ')'
        ].
        ^self join: parts
    ]

    backup: timestamp [
        | state |
        state := Dictionary new.
        database keysAndValuesDo: [:key :fields |
            fields keysAndValuesDo: [:field :rec |
                (self isAlive: key field: field timestamp: timestamp) ifTrue: [
                    | remaining |
                    remaining := (rec at: 2) isNil ifTrue: [nil] ifFalse: [(rec at: 2) - timestamp].
                    (state at: key ifAbsentPut: [Dictionary new]) at: field put: {rec at: 1. remaining}
                ]
            ]
        ].
        backupTimestamps add: timestamp.
        backupStates add: state.
        ^state size printString
    ]

    restore: timestamp with: timestampToRestore [
        | idx backup |
        idx := 0.
        1 to: backupTimestamps size do: [:i |
            (backupTimestamps at: i) <= timestampToRestore ifTrue: [idx := i]
        ].
        backup := backupStates at: idx.
        database := Dictionary new.
        backup keysAndValuesDo: [:key :fields |
            fields keysAndValuesDo: [:field :rec |
                | remaining expiry |
                remaining := rec at: 2.
                expiry := remaining isNil ifTrue: [nil] ifFalse: [timestamp + remaining].
                self setInternal: key field: field value: (rec at: 1) expiry: expiry
            ]
        ].
        ^''
    ]
]
