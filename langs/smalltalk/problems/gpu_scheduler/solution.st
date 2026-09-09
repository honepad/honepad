Object subclass: Gpu [
    | gpuId mem jobId |

    Gpu class >> id: anId mem: aMem [
        ^(self new)
            setId: anId mem: aMem;
            yourself
    ]

    setId: anId mem: aMem [
        gpuId := anId.
        mem := aMem.
        jobId := nil
    ]

    gpuId [ ^gpuId ]
    mem [ ^mem ]
    jobId [ ^jobId ]
    jobId: value [ jobId := value ]
]

Object subclass: Job [
    | jobId mem seq priority state gpuId |

    Job class >> id: anId mem: aMem seq: aSeq [
        ^(self new)
            setId: anId mem: aMem seq: aSeq;
            yourself
    ]

    setId: anId mem: aMem seq: aSeq [
        jobId := anId.
        mem := aMem.
        seq := aSeq.
        priority := 0.
        state := 'queued'.
        gpuId := nil
    ]

    jobId [ ^jobId ]
    mem [ ^mem ]
    seq [ ^seq ]
    priority [ ^priority ]
    priority: value [ priority := value ]
    state [ ^state ]
    state: value [ state := value ]
    gpuId [ ^gpuId ]
    gpuId: value [ gpuId := value ]
]

Object subclass: Simulation [
    | gpus gpuOrder jobs nextSeq |

    Simulation class >> new [
        ^self basicNew initialize
    ]

    initialize [
        gpus := Dictionary new.
        gpuOrder := OrderedCollection new.
        jobs := Dictionary new.
        nextSeq := 0
    ]

    place: job on: gpu [
        job state: 'running'.
        job gpuId: gpu gpuId.
        gpu jobId: job jobId
    ]

    addGpu: gpuId with: mem [
        mem <= 0 ifTrue: [^'invalid_request'].
        (gpus includesKey: gpuId) ifTrue: [^'false'].
        gpus at: gpuId put: (Gpu id: gpuId mem: mem).
        gpuOrder add: gpuId.
        ^'true'
    ]

    submitJob: jobId with: mem [
        mem <= 0 ifTrue: [^'invalid_request'].
        (jobs includesKey: jobId) ifTrue: [^'false'].
        jobs at: jobId put: (Job id: jobId mem: mem seq: nextSeq).
        nextSeq := nextSeq + 1.
        ^'true'
    ]

    status: jobId [
        | job |
        job := jobs at: jobId ifAbsent: [^''].
        ^job state
    ]

    assign [
        | queued |
        queued := OrderedCollection new.
        jobs do: [:job |
            job state = 'queued' ifTrue: [queued add: job]
        ].
        queued := queued asSortedCollection: [:a :b |
            a priority = b priority ifTrue: [a seq < b seq] ifFalse: [a priority > b priority]
        ].
        queued do: [:job |
            gpuOrder do: [:gpuId |
                | gpu |
                gpu := gpus at: gpuId.
                (gpu jobId isNil and: [gpu mem >= job mem]) ifTrue: [
                    self place: job on: gpu.
                    ^job jobId
                ]
            ]
        ].
        ^''
    ]

    complete: jobId [
        | job |
        job := jobs at: jobId ifAbsent: [^'invalid_request'].
        (job state = 'running' and: [job gpuId notNil]) ifFalse: [^'invalid_request'].
        (gpus at: job gpuId) jobId: nil.
        job gpuId: nil.
        job state: 'done'.
        ^'true'
    ]

    cancel: jobId [
        | job |
        job := jobs at: jobId ifAbsent: [^'invalid_request'].
        job state = 'done' ifTrue: [^'invalid_request'].
        (job state = 'running' and: [job gpuId notNil]) ifTrue: [
            (gpus at: job gpuId) jobId: nil
        ].
        jobs removeKey: jobId.
        job state = 'running' ifTrue: [self assign].
        ^'true'
    ]

    setPriority: jobId with: priority [
        | job |
        job := jobs at: jobId ifAbsent: [^'invalid_request'].
        job state = 'queued' ifFalse: [^'invalid_request'].
        job priority: priority.
        ^'true'
    ]
]
