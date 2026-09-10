Object subclass: Simulation [
    | buf pos undoStack redoStack selStart selEnd clip |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        buf := ''.
        pos := 0.
        undoStack := OrderedCollection new.
        redoStack := OrderedCollection new.
        selStart := -1.
        selEnd := -1.
        clip := ''
    ]

    sliceFrom: start to: last [
        (last < start or: [last < 1 or: [start > buf size]]) ifTrue: [^''].
        ^buf copyFrom: start to: last
    ]

    push [
        undoStack add: (Array with: buf with: pos).
        redoStack := OrderedCollection new.
        selStart := -1.
        selEnd := -1
    ]

    insert: at with: text [
        (at < 0 or: [at > buf size]) ifTrue: [^'invalid_request'].
        self push.
        buf := (self sliceFrom: 1 to: at), text, (self sliceFrom: at + 1 to: buf size).
        ^buf size printString
    ]

    erase: at with: n [
        | deleted |
        (n <= 0 or: [at < 0 or: [at + n > buf size]]) ifTrue: [^'invalid_request'].
        self push.
        deleted := self sliceFrom: at + 1 to: at + n.
        buf := (self sliceFrom: 1 to: at), (self sliceFrom: at + n + 1 to: buf size).
        pos > buf size ifTrue: [pos := buf size].
        ^deleted
    ]

    getText [
        ^buf
    ]

    length [
        ^buf size printString
    ]

    move: at [
        (at < 0 or: [at > buf size]) ifTrue: [^'invalid_request'].
        pos := at.
        ^'true'
    ]

    typeText: text [
        | at |
        self push.
        at := pos.
        buf := (self sliceFrom: 1 to: at), text, (self sliceFrom: at + 1 to: buf size).
        pos := at + text size.
        ^buf size printString
    ]

    cursor [
        ^pos printString
    ]

    undo [
        | snap |
        undoStack isEmpty ifTrue: [^'false'].
        redoStack add: (Array with: buf with: pos).
        snap := undoStack removeLast.
        buf := snap at: 1.
        pos := snap at: 2.
        selStart := -1.
        selEnd := -1.
        ^'true'
    ]

    redo [
        | snap |
        redoStack isEmpty ifTrue: [^'false'].
        undoStack add: (Array with: buf with: pos).
        snap := redoStack removeLast.
        buf := snap at: 1.
        pos := snap at: 2.
        selStart := -1.
        selEnd := -1.
        ^'true'
    ]

    select: start with: end [
        (start < 0 or: [end < 0 or: [start > end or: [end > buf size]]]) ifTrue: [^'invalid_request'].
        selStart := start.
        selEnd := end.
        ^'true'
    ]

    cut [
        | text |
        (selStart < 0 or: [selStart = selEnd]) ifTrue: [^'invalid_request'].
        text := self sliceFrom: selStart + 1 to: selEnd.
        buf := (self sliceFrom: 1 to: selStart), (self sliceFrom: selEnd + 1 to: buf size).
        clip := text.
        pos := selStart.
        selStart := -1.
        selEnd := -1.
        ^text
    ]

    copySel [
        (selStart < 0 or: [selStart = selEnd]) ifTrue: [^'invalid_request'].
        clip := self sliceFrom: selStart + 1 to: selEnd.
        ^clip
    ]

    paste [
        | at |
        clip isEmpty ifTrue: [^'invalid_request'].
        at := pos.
        buf := (self sliceFrom: 1 to: at), clip, (self sliceFrom: at + 1 to: buf size).
        pos := at + clip size.
        ^buf size printString
    ]
]
