" argv: gst -q adapter.st -a src class cases.json "
" File in the solution, instantiate Simulation or InMemoryDatabase. "
" Map snake_case traces to camelCase:with: selectors, compare JSON. "
" Bank booleans are JSON true/false. "

Object subclass: HonepadJsonParser [
    | text i n |

    on: aString [
        text := aString.
        i := 1.
        n := aString size
    ]

    peek [
        i > n ifTrue: [^nil].
        ^text at: i
    ]

    bump [
        | c |
        c := self peek.
        c isNil ifFalse: [i := i + 1].
        ^c
    ]

    skipWs [
        | c |
        [
            c := self peek.
            c notNil and: [
                c = $  or: [
                    c = Character tab or: [
                        c = Character nl or: [c = Character cr]]]]
        ] whileTrue: [self bump]
    ]

    startsWith: token [
        | end |
        end := i + token size - 1.
        end > n ifTrue: [^false].
        ^(text copyFrom: i to: end) = token
    ]

    isDigit: c [
        c isNil ifTrue: [^false].
        ^c >= $0 and: [c <= $9]
    ]

    parseString [
        | out c |
        self bump = $" ifFalse: [self error: 'expected string'].
        out := WriteStream on: String new.
        [
            c := self bump.
            c isNil ifTrue: [self error: 'unterminated string'].
            c = $" ifTrue: [^out contents].
            c = $\ ifTrue: [self writeEscapeOn: out] ifFalse: [out nextPut: c]
        ] repeat
    ]

    writeEscapeOn: out [
        | e hex |
        e := self bump.
        e = $" ifTrue: [^out nextPut: $"].
        e = $\ ifTrue: [^out nextPut: $\].
        e = $/ ifTrue: [^out nextPut: $/].
        e = $b ifTrue: [^out nextPut: Character backspace].
        e = $f ifTrue: [^out nextPut: Character newPage].
        e = $n ifTrue: [^out nextPut: Character nl].
        e = $r ifTrue: [^out nextPut: Character cr].
        e = $t ifTrue: [^out nextPut: Character tab].
        e = $u ifTrue: [
            hex := String new: 4.
            1 to: 4 do: [:k |
                hex at: k put: (self bump ifNil: [self error: 'bad unicode'])
            ].
            ^out nextPut: (Character codePoint: (self parseHex: hex))
        ].
        self error: 'bad escape'
    ]

    parseHex: hex [
        | v d |
        v := 0.
        hex do: [:ch |
            d := ch asLowercase.
            v := v * 16.
            (d >= $0 and: [d <= $9]) ifTrue: [
                v := v + (d codePoint - $0 codePoint)
            ].
            (d >= $a and: [d <= $f]) ifTrue: [
                v := v + (d codePoint - $a codePoint + 10)
            ]
        ].
        ^v
    ]

    parseNumber [
        | start s num |
        start := i.
        self peek = $- ifTrue: [self bump].
        [self isDigit: self peek] whileTrue: [self bump].
        self peek = $. ifTrue: [
            self bump.
            [self isDigit: self peek] whileTrue: [self bump]
        ].
        (self peek = $e or: [self peek = $E]) ifTrue: [
            self bump.
            (self peek = $+ or: [self peek = $-]) ifTrue: [self bump].
            [self isDigit: self peek] whileTrue: [self bump]
        ].
        s := text copyFrom: start to: i - 1.
        num := s asNumber.
        num isInteger ifTrue: [^num].
        num = num rounded ifTrue: [^num rounded].
        ^num
    ]

    parseArray [
        | acc |
        self bump.
        self skipWs.
        self peek = $] ifTrue: [self bump. ^OrderedCollection new].
        acc := OrderedCollection new.
        [
            acc add: self parseValue.
            self skipWs.
            self bump = $, ifTrue: [self skipWs] ifFalse: [
                self peek isNil ifFalse: [].
                ^acc
            ]
        ] repeat
    ]

    parseObject [
        | acc key c |
        self bump.
        self skipWs.
        acc := Dictionary new.
        self peek = $} ifTrue: [self bump. ^acc].
        [
            self skipWs.
            key := self parseString.
            self skipWs.
            self bump = $: ifFalse: [self error: 'expected colon'].
            self skipWs.
            acc at: key put: self parseValue.
            self skipWs.
            c := self bump.
            c = $} ifTrue: [^acc].
            c = $, ifFalse: [self error: 'expected comma or }']
        ] repeat
    ]

    parseValue [
        | c |
        self skipWs.
        c := self peek.
        c isNil ifTrue: [self error: 'unexpected end'].
        (self startsWith: 'null') ifTrue: [i := i + 4. ^nil].
        (self startsWith: 'true') ifTrue: [i := i + 4. ^true].
        (self startsWith: 'false') ifTrue: [i := i + 5. ^false].
        c = $" ifTrue: [^self parseString].
        c = $[ ifTrue: [^self parseArray].
        c = ${ ifTrue: [^self parseObject].
        (c = $- or: [self isDigit: c]) ifTrue: [^self parseNumber].
        self error: 'unexpected json char'
    ]

    parse [
        | value |
        value := self parseValue.
        self skipWs.
        i <= n ifTrue: [self error: 'trailing json'].
        ^value
    ]
]

Object subclass: HonepadJson [
    HonepadJson class >> decode: aString [
        ^(HonepadJsonParser new)
            on: aString;
            parse
    ]

    HonepadJson class >> encode: value [
        | out |
        out := WriteStream on: String new.
        self write: value on: out.
        ^out contents
    ]

    HonepadJson class >> write: value on: out [
        value == true ifTrue: [^out nextPutAll: 'true'].
        value == false ifTrue: [^out nextPutAll: 'false'].
        value isNil ifTrue: [^out nextPutAll: 'null'].
        value isInteger ifTrue: [^value printOn: out].
        value isString ifTrue: [^self writeString: value on: out].
        (value isKindOf: Dictionary) ifTrue: [^self writeObject: value on: out].
        (value isKindOf: SequenceableCollection) ifTrue: [^self writeArray: value on: out].
        value isNumber ifTrue: [
            | rounded |
            rounded := value rounded.
            rounded = value ifTrue: [^rounded printOn: out].
            ^value printOn: out
        ].
        self writeString: value printString on: out
    ]

    HonepadJson class >> writeString: s on: out [
        out nextPut: $".
        s do: [:c | self writeChar: c on: out].
        out nextPut: $"
    ]

    HonepadJson class >> writeChar: c on: out [
        c = $" ifTrue: [^out nextPutAll: '\"'].
        c = $\ ifTrue: [^out nextPutAll: '\\'].
        c = Character nl ifTrue: [^out nextPutAll: '\n'].
        c = Character cr ifTrue: [^out nextPutAll: '\r'].
        c = Character tab ifTrue: [^out nextPutAll: '\t'].
        c = Character backspace ifTrue: [^out nextPutAll: '\b'].
        c = Character newPage ifTrue: [^out nextPutAll: '\f'].
        c codePoint < 32 ifTrue: [
            out nextPutAll: '\u'.
            ^self writeHex4: c codePoint on: out
        ].
        out nextPut: c
    ]

    HonepadJson class >> writeHex4: n on: out [
        | v digits |
        v := n.
        digits := String new: 4.
        4 to: 1 by: -1 do: [:k |
            digits at: k put: ('0123456789abcdef' at: (v \\ 16) + 1).
            v := v // 16
        ].
        out nextPutAll: digits
    ]

    HonepadJson class >> writeArray: arr on: out [
        | first |
        out nextPut: $[.
        first := true.
        arr do: [:item |
            first ifFalse: [out nextPut: $,].
            first := false.
            self write: item on: out
        ].
        out nextPut: $]
    ]

    HonepadJson class >> writeObject: dict on: out [
        | first |
        out nextPut: ${.
        first := true.
        dict keysAndValuesDo: [:k :v |
            first ifFalse: [out nextPut: $,].
            first := false.
            self write: k asString on: out.
            out nextPut: $:.
            self write: v on: out
        ].
        out nextPut: $}
    ]
]

Object subclass: HonepadAdapter [
    HonepadAdapter class >> toCamel: snake [
        | parts out p |
        (snake includes: $_) ifFalse: [^snake].
        parts := snake subStrings: $_.
        out := parts first.
        2 to: parts size do: [:idx |
            p := parts at: idx.
            p isEmpty ifFalse: [
                out := out, (p copyFrom: 1 to: 1) asUppercase.
                p size > 1 ifTrue: [out := out, (p copyFrom: 2 to: p size)]
            ]
        ].
        ^out
    ]

    HonepadAdapter class >> selectorFor: camel argc: argc [
        | sel |
        argc = 0 ifTrue: [^camel asSymbol].
        sel := camel, ':'.
        2 to: argc do: [:idx | sel := sel, 'with:'].
        ^sel asSymbol
    ]

    HonepadAdapter class >> coerce: value [
        value isNumber ifTrue: [
            value isInteger ifTrue: [^value].
            value = value rounded ifTrue: [^value rounded].
            ^value
        ].
        (value isKindOf: SequenceableCollection) ifTrue: [
            value isString ifTrue: [^value].
            ^value collect: [:each | self coerce: each]
        ].
        ^value
    ]

    HonepadAdapter class >> failRow: caseId index: index method: method expected: expected actual: actual [
        | row |
        row := Dictionary new.
        row at: 'case' put: caseId asString.
        row at: 'index' put: index.
        row at: 'method' put: method.
        row at: 'expected' put: expected.
        row at: 'actual' put: actual.
        ^row
    ]

    HonepadAdapter class >> readFile: path [
        ^(File name: path) contents
    ]

    HonepadAdapter class >> fileIn: path [
        (File name: path) fileIn
    ]

    HonepadAdapter class >> emit: payload code: code [
        stdout nextPutAll: (HonepadJson encode: payload); nl; flush.
        ObjectMemory quit: code
    ]

    HonepadAdapter class >> run [
        | argv src className casesPath cls cases failed passed |
        argv := Smalltalk arguments.
        argv size = 3 ifFalse: [
            stderr nextPutAll: 'usage: gst adapter.st -a <src> <class> <cases.json>'; nl.
            ObjectMemory quit: 2
        ].
        src := argv at: 1.
        className := argv at: 2.
        casesPath := argv at: 3.
        [
            self fileIn: src
        ] on: Error do: [:ex |
            | payload failed0 |
            failed0 := OrderedCollection new.
            failed0 add: (self failRow: 'load' index: 0 method: 'load' expected: nil
                actual: 'exc:', ex class name asString).
            payload := Dictionary new.
            payload at: 'passed' put: 0.
            payload at: 'failed' put: failed0.
            self emit: payload code: 2
        ].
        cls := Smalltalk at: className asSymbol ifAbsent: [nil].
        cls isNil ifTrue: [
            | payload failed0 |
            failed0 := OrderedCollection new.
            failed0 add: (self failRow: 'load' index: 0 method: 'load' expected: nil
                actual: 'exc:missing').
            payload := Dictionary new.
            payload at: 'passed' put: 0.
            payload at: 'failed' put: failed0.
            self emit: payload code: 2
        ].
        cases := HonepadJson decode: (self readFile: casesPath).
        failed := OrderedCollection new.
        passed := 0.
        cases do: [:row |
            | obj caseId calls ok |
            obj := cls new.
            caseId := (row at: 'id') asString.
            calls := row at: 'calls' ifAbsent: [OrderedCollection new].
            ok := true.
            1 to: calls size do: [:idx |
                | call methodSnake args expected actual camel sel |
                ok ifTrue: [
                    call := calls at: idx.
                    methodSnake := (call at: 'm') asString.
                    args := self coerce: (call at: 'a' ifAbsent: [OrderedCollection new]).
                    args := args asArray.
                    expected := self coerce: (call at: 'e' ifAbsent: [nil]).
                    camel := self toCamel: methodSnake.
                    sel := self selectorFor: camel argc: args size.
                    [
                        actual := obj perform: sel withArguments: args
                    ] on: Error do: [:ex |
                        failed add: (self failRow: caseId index: idx - 1 method: methodSnake
                            expected: expected actual: 'exc:', ex class name asString).
                        ok := false
                    ].
                    ok ifTrue: [
                        (HonepadJson encode: actual) = (HonepadJson encode: expected) ifFalse: [
                            failed add: (self failRow: caseId index: idx - 1 method: methodSnake
                                expected: expected actual: actual).
                            ok := false
                        ]
                    ]
                ]
            ].
            ok ifTrue: [passed := passed + 1]
        ].
        [
            | payload |
            payload := Dictionary new.
            payload at: 'passed' put: passed.
            payload at: 'failed' put: failed.
            self emit: payload code: (failed isEmpty ifTrue: [0] ifFalse: [1])
        ] value
    ]
]

Eval [
    [
        HonepadAdapter run
    ] on: Error do: [:ex |
        | payload failed |
        failed := OrderedCollection new.
        failed add: (HonepadAdapter failRow: 'load' index: 0 method: 'load' expected: nil
            actual: 'exc:', ex class name asString).
        payload := Dictionary new.
        payload at: 'passed' put: 0.
        payload at: 'failed' put: failed.
        HonepadAdapter emit: payload code: 2
    ]
]
