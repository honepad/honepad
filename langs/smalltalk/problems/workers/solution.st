Object subclass: Worker [
    | workerId position compensation inOffice enteredAt finished pendingPromo |

    Worker class >> id: anId position: aPos compensation: aComp [
        ^(self new)
            setId: anId position: aPos compensation: aComp;
            yourself
    ]

    setId: anId position: aPos compensation: aComp [
        workerId := anId.
        position := aPos.
        compensation := aComp.
        inOffice := false.
        enteredAt := nil.
        finished := OrderedCollection new.
        pendingPromo := nil
    ]

    workerId [ ^workerId ]
    position [ ^position ]
    inOffice [ ^inOffice ]
    enteredAt [ ^enteredAt ]
    pendingPromo [ ^pendingPromo ]
    pendingPromo: promo [ pendingPromo := promo ]

    totalTime [
        | sum |
        sum := 0.
        finished do: [:row | sum := sum + ((row at: 2) - (row at: 1))].
        ^sum
    ]

    positionTime: aPos [
        | sum |
        sum := 0.
        finished do: [:row |
            (row at: 4) = aPos ifTrue: [sum := sum + ((row at: 2) - (row at: 1))]
        ].
        ^sum
    ]

    applyPromoOnEnter: timestamp [
        | newPos newComp startTs |
        pendingPromo isNil ifTrue: [^self].
        newPos := pendingPromo at: 1.
        newComp := pendingPromo at: 2.
        startTs := pendingPromo at: 3.
        timestamp >= startTs ifTrue: [
            position := newPos.
            compensation := newComp.
            pendingPromo := nil
        ]
    ]

    clockOut: timestamp [
        finished add: {enteredAt. timestamp. compensation. position}.
        inOffice := false.
        enteredAt := nil
    ]

    clockIn: timestamp [
        self applyPromoOnEnter: timestamp.
        inOffice := true.
        enteredAt := timestamp
    ]

    calcSalaryFrom: startTs to: endTs [
        | total |
        total := 0.
        finished do: [:row |
            | lo hi |
            lo := (row at: 1) max: startTs.
            hi := (row at: 2) min: endTs.
            hi > lo ifTrue: [total := total + ((hi - lo) * (row at: 3))]
        ].
        ^total
    ]
]

Object subclass: Simulation [
    | workers |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        workers := Dictionary new
    ]

    addWorker: workerId with: position with: compensation [
        (workers includesKey: workerId) ifTrue: [^'false'].
        workers at: workerId put: (Worker id: workerId position: position compensation: compensation).
        ^'true'
    ]

    register: workerId with: timestamp [
        | worker |
        worker := workers at: workerId ifAbsent: [^'invalid_request'].
        worker inOffice ifTrue: [
            worker clockOut: timestamp.
            ^'registered'
        ].
        worker clockIn: timestamp.
        ^'registered'
    ]

    get: workerId [
        | worker |
        worker := workers at: workerId ifAbsent: [^''].
        ^worker totalTime printString
    ]

    join: parts [
        | s |
        parts isEmpty ifTrue: [^''].
        s := parts first.
        2 to: parts size do: [:idx | s := s, ', ', (parts at: idx)].
        ^s
    ]

    topNWorkers: n with: position [
        | matched sorted limit parts |
        matched := OrderedCollection new.
        workers do: [:w |
            w position = position ifTrue: [matched add: w]
        ].
        sorted := matched asSortedCollection: [:a :b |
            | ta tb |
            ta := a positionTime: position.
            tb := b positionTime: position.
            ta = tb ifTrue: [a workerId <= b workerId] ifFalse: [ta > tb]
        ].
        limit := n min: sorted size.
        parts := OrderedCollection new.
        1 to: limit do: [:idx |
            | w |
            w := sorted at: idx.
            parts add: w workerId, '(', (w positionTime: position) printString, ')'
        ].
        ^self join: parts
    ]

    promote: workerId with: newPosition with: newCompensation with: startTimestamp [
        | worker |
        worker := workers at: workerId ifAbsent: [^'invalid_request'].
        worker pendingPromo isNil ifFalse: [^'invalid_request'].
        worker pendingPromo: {newPosition. newCompensation. startTimestamp}.
        ^'success'
    ]

    calcSalary: workerId with: startTimestamp with: endTimestamp [
        | worker |
        worker := workers at: workerId ifAbsent: [^''].
        ^(worker calcSalaryFrom: startTimestamp to: endTimestamp) printString
    ]
]
