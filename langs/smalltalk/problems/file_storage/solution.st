Object subclass: StoredFile [
    | name size owner |

    StoredFile class >> name: aName size: aSize owner: anOwner [
        ^(self new)
            setName: aName size: aSize owner: anOwner;
            yourself
    ]

    setName: aName size: aSize owner: anOwner [
        name := aName.
        size := aSize.
        owner := anOwner
    ]

    name [ ^name ]
    size [ ^size ]
    owner [ ^owner ]
    owner: anOwner [ owner := anOwner ]
]

Object subclass: Simulation [
    | files capacity backups |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        files := Dictionary new.
        capacity := Dictionary new.
        capacity at: 'admin' put: nil.
        backups := Dictionary new
    ]

    used: userId [
        | sum |
        sum := 0.
        files do: [:item |
            item owner = userId ifTrue: [sum := sum + item size]
        ].
        ^sum
    ]

    remaining: userId [
        | cap |
        cap := capacity at: userId ifAbsent: [^nil].
        cap isNil ifTrue: [^nil].
        ^cap - (self used: userId)
    ]

    addFile: name with: size [
        (files includesKey: name) ifTrue: [^'false'].
        files at: name put: (StoredFile name: name size: size owner: 'admin').
        ^'true'
    ]

    getFileSize: name [
        | item |
        item := files at: name ifAbsent: [^''].
        ^item size printString
    ]

    deleteFile: name [
        | item |
        item := files at: name ifAbsent: [^''].
        files removeKey: name.
        ^item size printString
    ]

    copyFile: source with: dest [
        | src destItem owner extra remaining |
        src := files at: source ifAbsent: [^''].
        source = dest ifTrue: [^src size printString].
        destItem := files at: dest ifAbsent: [nil].
        destItem isNil
            ifTrue: [
                owner := src owner.
                extra := src size
            ]
            ifFalse: [
                owner := destItem owner.
                extra := src size - destItem size
            ].
        remaining := self remaining: owner.
        (remaining notNil and: [extra > remaining]) ifTrue: [^''].
        destItem isNil
            ifTrue: [
                files at: dest put: (StoredFile name: dest size: src size owner: owner)
            ]
            ifFalse: [
                files at: dest put: (StoredFile name: dest size: src size owner: destItem owner)
            ].
        ^src size printString
    ]

    join: parts [
        | s |
        parts isEmpty ifTrue: [^''].
        s := parts first.
        2 to: parts size do: [:idx | s := s, ', ', (parts at: idx)].
        ^s
    ]

    getNLargest: prefix with: n [
        | matched sorted limit parts |
        matched := OrderedCollection new.
        files do: [:item |
            (item name startsWith: prefix) ifTrue: [matched add: item]
        ].
        sorted := matched asSortedCollection: [:a :b |
            a size = b size ifTrue: [a name <= b name] ifFalse: [a size > b size]
        ].
        limit := n min: sorted size.
        parts := OrderedCollection new.
        1 to: limit do: [:idx |
            | item |
            item := sorted at: idx.
            parts add: item name, '(', item size printString, ')'
        ].
        ^self join: parts
    ]

    addUser: userId with: cap [
        (capacity includesKey: userId) ifTrue: [^'false'].
        capacity at: userId put: cap.
        ^'true'
    ]

    addFileBy: userId with: name with: size [
        | left |
        (capacity includesKey: userId) ifFalse: [^''].
        (files includesKey: name) ifTrue: [^''].
        left := self remaining: userId.
        (left notNil and: [size > left]) ifTrue: [^''].
        files at: name put: (StoredFile name: name size: size owner: userId).
        left := self remaining: userId.
        left isNil ifTrue: [^''].
        ^left printString
    ]

    mergeUser: userId1 with: userId2 [
        | cap1 cap2 left |
        userId1 = userId2 ifTrue: [^''].
        (capacity includesKey: userId1) ifFalse: [^''].
        (capacity includesKey: userId2) ifFalse: [^''].
        cap1 := capacity at: userId1.
        cap2 := capacity at: userId2.
        (cap1 isNil or: [cap2 isNil]) ifTrue: [^''].
        capacity at: userId1 put: cap1 + cap2.
        files do: [:item |
            item owner = userId2 ifTrue: [item owner: userId1]
        ].
        capacity removeKey: userId2 ifAbsent: [].
        backups removeKey: userId2 ifAbsent: [].
        left := self remaining: userId1.
        left isNil ifTrue: [^''].
        ^left printString
    ]

    backupUser: userId [
        | snap |
        (capacity includesKey: userId) ifFalse: [^''].
        snap := Dictionary new.
        files do: [:item |
            item owner = userId ifTrue: [snap at: item name put: item size]
        ].
        backups at: userId put: snap.
        ^snap size printString
    ]

    restoreUser: userId [
        | names snap restored |
        (capacity includesKey: userId) ifFalse: [^''].
        names := OrderedCollection new.
        files keysAndValuesDo: [:name :item |
            item owner = userId ifTrue: [names add: name]
        ].
        names do: [:name | files removeKey: name].
        snap := backups at: userId ifAbsent: [^'0'].
        restored := 0.
        snap keysAndValuesDo: [:name :size |
            | left |
            (files includesKey: name) ifFalse: [
                left := self remaining: userId.
                (left notNil and: [size > left]) ifFalse: [
                    files at: name put: (StoredFile name: name size: size owner: userId).
                    restored := restored + 1
                ]
            ]
        ].
        ^restored printString
    ]
]
