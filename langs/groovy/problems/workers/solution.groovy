class Simulation {
    private final Map<String, Worker> workers = new LinkedHashMap<>()

    String addWorker(String workerId, String position, long compensation) {
        if (workers.containsKey(workerId)) {
            return 'false'
        }
        workers[workerId] = new Worker(workerId, position, compensation)
        return 'true'
    }

    String register(String workerId, long timestamp) {
        Worker worker = workers[workerId]
        if (worker == null) {
            return 'invalid_request'
        }
        if (worker.inOffice) {
            worker.finished.add(new WorkSession(
                worker.enteredAt,
                timestamp,
                worker.compensation,
                worker.position,
            ))
            worker.inOffice = false
            worker.enteredAt = null
            return 'registered'
        }
        worker.applyPromoOnEnter(timestamp)
        worker.inOffice = true
        worker.enteredAt = timestamp
        return 'registered'
    }

    String get(String workerId) {
        Worker worker = workers[workerId]
        if (worker == null) {
            return ''
        }
        return String.valueOf(worker.totalTime())
    }

    String topNWorkers(long n, String position) {
        List<Worker> matched = workers.values().findAll { it.position == position }
        matched.sort { a, b ->
            int d = Long.compare(b.positionTime(position), a.positionTime(position))
            d != 0 ? d : a.workerId <=> b.workerId
        }
        int limit = Math.min(n as int, matched.size())
        matched.subList(0, limit).collect { worker ->
            "${worker.workerId}(${worker.positionTime(position)})"
        }.join(', ')
    }

    String promote(String workerId, String newPosition, long newCompensation, long startTimestamp) {
        Worker worker = workers[workerId]
        if (worker == null || worker.pendingPromo != null) {
            return 'invalid_request'
        }
        worker.pendingPromo = new Promo(newPosition, newCompensation, startTimestamp)
        return 'success'
    }

    String setDoublePay(String workerId, long intervalBegin, long intervalEnd) {
        Worker worker = workers[workerId]
        if (worker == null || intervalEnd <= intervalBegin) {
            return 'invalid_request'
        }
        worker.doublePay.add([intervalBegin, intervalEnd] as long[])
        return 'true'
    }

    String calcSalary(String workerId, long startTimestamp, long endTimestamp) {
        Worker worker = workers[workerId]
        if (worker == null) {
            return ''
        }
        long total = 0
        worker.finished.each { session ->
            long lo = Math.max(session.start, startTimestamp)
            long hi = Math.min(session.end, endTimestamp)
            if (hi > lo) {
                long bonus = bonusOverlap(lo, hi, worker.doublePay)
                total += (hi - lo - bonus) * session.rate + bonus * session.rate * 2
            }
        }
        return String.valueOf(total)
    }

    static long bonusOverlap(long lo, long hi, List<long[]> windows) {
        List<long[]> segs = []
        windows.each { win ->
            long start = Math.max(lo, win[0])
            long stop = Math.min(hi, win[1])
            if (stop > start) {
                segs.add([start, stop] as long[])
            }
        }
        segs.sort { a, b -> Long.compare(a[0], b[0]) }
        List<long[]> merged = []
        segs.each { seg ->
            if (merged.isEmpty() || seg[0] >= merged[-1][1]) {
                merged.add([seg[0], seg[1]] as long[])
            } else {
                merged[-1][1] = Math.max(merged[-1][1], seg[1])
            }
        }
        long sum = 0
        merged.each { seg ->
            sum += seg[1] - seg[0]
        }
        return sum
    }
}

class WorkSession {
    long start
    long end
    long rate
    String position

    WorkSession(long start, long end, long rate, String position) {
        this.start = start
        this.end = end
        this.rate = rate
        this.position = position
    }
}

class Promo {
    String position
    long compensation
    long startTimestamp

    Promo(String position, long compensation, long startTimestamp) {
        this.position = position
        this.compensation = compensation
        this.startTimestamp = startTimestamp
    }
}

class Worker {
    String workerId
    String position
    long compensation
    boolean inOffice = false
    Long enteredAt = null
    List<WorkSession> finished = []
    Promo pendingPromo = null
    List<long[]> doublePay = []

    Worker(String workerId, String position, long compensation) {
        this.workerId = workerId
        this.position = position
        this.compensation = compensation
    }

    long totalTime() {
        long sum = 0
        finished.each { session ->
            sum += session.end - session.start
        }
        return sum
    }

    long positionTime(String pos) {
        long sum = 0
        finished.each { session ->
            if (session.position == pos) {
                sum += session.end - session.start
            }
        }
        return sum
    }

    void applyPromoOnEnter(long timestamp) {
        if (pendingPromo == null) {
            return
        }
        if (timestamp >= pendingPromo.startTimestamp) {
            position = pendingPromo.position
            compensation = pendingPromo.compensation
            pendingPromo = null
        }
    }
}
