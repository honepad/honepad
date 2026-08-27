Object subclass: Account [
    | accountId balance outgoing payments createdAt balanceHistory |

    Account class >> id: anId createdAt: ts [
        ^(self new)
            setId: anId createdAt: ts;
            yourself
    ]

    setId: anId createdAt: ts [
        accountId := anId.
        balance := 0.
        outgoing := 0.
        payments := Dictionary new.
        createdAt := ts.
        balanceHistory := OrderedCollection with: {ts. 0}
    ]

    outgoing [ ^outgoing ]
    balance [ ^balance ]
    payments [ ^payments ]
    createdAt [ ^createdAt ]
    createdAt: ts [ createdAt := ts ]
    balanceHistory [ ^balanceHistory ]
    balanceHistory: rows [ balanceHistory := rows ]

    addOutgoing: n [ outgoing := outgoing + n ]
    addBalance: n [ balance := balance + n ]

    recordBalance: timestamp [
        balanceHistory add: {timestamp. balance}
    ]

    deposit: amount [
        balance := balance + amount.
        ^balance
    ]

    withdraw: amount [
        balance < amount ifTrue: [^false].
        balance := balance - amount.
        outgoing := outgoing + amount.
        ^true
    ]

    getBalanceAt: timeAt [
        | result |
        timeAt < createdAt ifTrue: [^nil].
        result := nil.
        balanceHistory do: [:pair |
            (pair at: 1) <= timeAt
                ifTrue: [result := pair at: 2]
                ifFalse: [^result]
        ].
        ^result
    ]
]

Object subclass: Simulation [
    | accounts paymentCounter pendingCashbacks cashbackDelay |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        accounts := Dictionary new.
        paymentCounter := 0.
        pendingCashbacks := OrderedCollection new.
        cashbackDelay := 24 * 60 * 60 * 1000
    ]

    processCashbacks: timestamp [
        [pendingCashbacks notEmpty and: [(pendingCashbacks first at: 1) <= timestamp]]
            whileTrue: [
                | row account |
                row := pendingCashbacks removeFirst.
                account := accounts at: (row at: 2) ifAbsent: [nil].
                account isNil ifFalse: [
                    account deposit: (row at: 3).
                    account payments at: (row at: 4) put: 'CASHBACK_RECEIVED'.
                    account recordBalance: (row at: 1)
                ]
            ]
    ]

    createAccount: timestamp with: accountId [
        self processCashbacks: timestamp.
        (accounts includesKey: accountId) ifTrue: [^false].
        accounts at: accountId put: (Account id: accountId createdAt: timestamp).
        ^true
    ]

    deposit: timestamp with: accountId with: amount [
        | account result |
        self processCashbacks: timestamp.
        account := accounts at: accountId ifAbsent: [^nil].
        result := account deposit: amount.
        account recordBalance: timestamp.
        ^result
    ]

    transfer: timestamp with: sourceId with: targetId with: amount [
        | source target |
        self processCashbacks: timestamp.
        source := accounts at: sourceId ifAbsent: [^nil].
        target := accounts at: targetId ifAbsent: [^nil].
        sourceId = targetId ifTrue: [^nil].
        (source withdraw: amount) ifFalse: [^nil].
        target deposit: amount.
        source recordBalance: timestamp.
        target recordBalance: timestamp.
        ^source balance
    ]

    topSpenders: timestamp with: n [
        | keys sorted limit out |
        self processCashbacks: timestamp.
        keys := accounts keys asArray.
        sorted := keys asSortedCollection: [:a :b |
            | oa ob |
            oa := (accounts at: a) outgoing.
            ob := (accounts at: b) outgoing.
            oa = ob ifTrue: [a <= b] ifFalse: [oa > ob]
        ].
        limit := n min: sorted size.
        out := OrderedCollection new.
        1 to: limit do: [:idx |
            | accId |
            accId := sorted at: idx.
            out add: accId, '(', (accounts at: accId) outgoing printString, ')'
        ].
        ^out asArray
    ]

    pay: timestamp with: accountId with: amount [
        | account paymentId cashback |
        self processCashbacks: timestamp.
        account := accounts at: accountId ifAbsent: [^nil].
        (account withdraw: amount) ifFalse: [^nil].
        paymentCounter := paymentCounter + 1.
        paymentId := 'payment', paymentCounter printString.
        account payments at: paymentId put: 'IN_PROGRESS'.
        account recordBalance: timestamp.
        cashback := amount * 2 // 100.
        pendingCashbacks add: {timestamp + cashbackDelay. accountId. cashback. paymentId}.
        ^paymentId
    ]

    getPaymentStatus: timestamp with: accountId with: payment [
        | account |
        self processCashbacks: timestamp.
        account := accounts at: accountId ifAbsent: [^nil].
        ^account payments at: payment ifAbsent: [nil]
    ]

    mergeAccounts: timestamp with: keepId with: dropId [
        | keep drop |
        self processCashbacks: timestamp.
        keepId = dropId ifTrue: [^false].
        keep := accounts at: keepId ifAbsent: [^false].
        drop := accounts at: dropId ifAbsent: [^false].
        keep addBalance: drop balance.
        keep addOutgoing: drop outgoing.
        drop payments keysAndValuesDo: [:k :v | keep payments at: k put: v].
        keep balanceHistory addAll: drop balanceHistory.
        keep balanceHistory: ((keep balanceHistory asSortedCollection: [:a :b |
            (a at: 1) <= (b at: 1)
        ]) asOrderedCollection).
        keep createdAt: (keep createdAt min: drop createdAt).
        keep recordBalance: timestamp.
        pendingCashbacks := pendingCashbacks collect: [:row |
            (row at: 2) = dropId
                ifTrue: [{row at: 1. keepId. row at: 3. row at: 4}]
                ifFalse: [row]
        ].
        accounts removeKey: dropId.
        ^true
    ]

    getBalance: timestamp with: accountId with: timeAt [
        | account |
        self processCashbacks: timestamp.
        account := accounts at: accountId ifAbsent: [^nil].
        ^account getBalanceAt: timeAt
    ]
]
