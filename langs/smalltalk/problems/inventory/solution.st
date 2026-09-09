Object subclass: Item [
    | sku name qty reserved |

    Item class >> sku: aSku name: aName [
        ^(self new)
            setSku: aSku name: aName;
            yourself
    ]

    setSku: aSku name: aName [
        sku := aSku.
        name := aName.
        qty := 0.
        reserved := 0
    ]

    sku [ ^sku ]
    qty [ ^qty ]
    reserved [ ^reserved ]

    qty: value [ qty := value ]
    reserved: value [ reserved := value ]
]

Object subclass: Simulation [
    | items |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        items := Dictionary new
    ]

    createItem: sku with: name [
        (items includesKey: sku) ifTrue: [^'false'].
        items at: sku put: (Item sku: sku name: name).
        ^'true'
    ]

    stock: sku with: delta [
        | item nxt |
        item := items at: sku ifAbsent: [^''].
        nxt := item qty + delta.
        nxt < item reserved ifTrue: [^'invalid_request'].
        item qty: nxt.
        ^nxt printString
    ]

    getQty: sku [
        | item |
        item := items at: sku ifAbsent: [^''].
        ^item qty printString
    ]

    join: parts [
        | s |
        parts isEmpty ifTrue: [^''].
        s := parts first.
        2 to: parts size do: [:idx | s := s, ', ', (parts at: idx)].
        ^s
    ]

    listLow: threshold [
        | matched sorted parts |
        matched := OrderedCollection new.
        items do: [:item |
            item qty <= threshold ifTrue: [matched add: item]
        ].
        sorted := matched asSortedCollection: [:a :b |
            a qty = b qty ifTrue: [a sku <= b sku] ifFalse: [a qty < b qty]
        ].
        parts := OrderedCollection new.
        sorted do: [:item |
            parts add: item sku, '(', item qty printString, ')'
        ].
        ^self join: parts
    ]

    reserve: sku with: n [
        | item |
        item := items at: sku ifAbsent: [^'invalid_request'].
        (n <= 0 or: [item reserved + n > item qty]) ifTrue: [^'invalid_request'].
        item reserved: item reserved + n.
        ^'true'
    ]

    release: sku with: n [
        | item |
        item := items at: sku ifAbsent: [^'invalid_request'].
        (n <= 0 or: [n > item reserved]) ifTrue: [^'invalid_request'].
        item reserved: item reserved - n.
        ^'true'
    ]

    ship: sku with: n [
        | item |
        item := items at: sku ifAbsent: [^'invalid_request'].
        (n <= 0 or: [n > item reserved]) ifTrue: [^'invalid_request'].
        item reserved: item reserved - n.
        item qty: item qty - n.
        ^'true'
    ]
]
