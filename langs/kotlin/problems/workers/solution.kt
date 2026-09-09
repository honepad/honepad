class WorkSession(val start: Int, val end: Int, val rate: Int, val position: String)

class Promo(val position: String, val compensation: Int, val startTimestamp: Int)

class Worker(val workerId: String, var position: String, var compensation: Int) {
    var inOffice = false
    var enteredAt: Int? = null
    val finished = ArrayList<WorkSession>()
    var pendingPromo: Promo? = null
    val doublePay = ArrayList<IntArray>()

    fun totalTime(): Int {
        var sum = 0
        for (session in finished) {
            sum += session.end - session.start
        }
        return sum
    }

    fun positionTime(pos: String): Int {
        var sum = 0
        for (session in finished) {
            if (session.position == pos) {
                sum += session.end - session.start
            }
        }
        return sum
    }

    fun applyPromoOnEnter(timestamp: Int) {
        val promo = pendingPromo ?: return
        if (timestamp >= promo.startTimestamp) {
            position = promo.position
            compensation = promo.compensation
            pendingPromo = null
        }
    }
}

class Simulation {
    private val workers = LinkedHashMap<String, Worker>()

    fun addWorker(workerId: String, position: String, compensation: Int): String {
        if (workers.containsKey(workerId)) {
            return "false"
        }
        workers[workerId] = Worker(workerId, position, compensation)
        return "true"
    }

    fun register(workerId: String, timestamp: Int): String {
        val worker = workers[workerId] ?: return "invalid_request"
        if (worker.inOffice) {
            worker.finished.add(
                WorkSession(worker.enteredAt!!, timestamp, worker.compensation, worker.position),
            )
            worker.inOffice = false
            worker.enteredAt = null
            return "registered"
        }
        worker.applyPromoOnEnter(timestamp)
        worker.inOffice = true
        worker.enteredAt = timestamp
        return "registered"
    }

    fun get(workerId: String): String {
        val worker = workers[workerId] ?: return ""
        return worker.totalTime().toString()
    }

    fun topNWorkers(n: Int, position: String): String {
        val matched = ArrayList<Worker>()
        for (worker in workers.values) {
            if (worker.position == position) {
                matched.add(worker)
            }
        }
        matched.sortWith { a, b ->
            val d = b.positionTime(position).compareTo(a.positionTime(position))
            if (d != 0) d else a.workerId.compareTo(b.workerId)
        }
        val cut = if (n < matched.size) matched.subList(0, n) else matched
        val parts = ArrayList<String>()
        for (worker in cut) {
            parts.add(worker.workerId + "(" + worker.positionTime(position) + ")")
        }
        return parts.joinToString(", ")
    }

    fun promote(
        workerId: String,
        newPosition: String,
        newCompensation: Int,
        startTimestamp: Int,
    ): String {
        val worker = workers[workerId]
        if (worker == null || worker.pendingPromo != null) {
            return "invalid_request"
        }
        worker.pendingPromo = Promo(newPosition, newCompensation, startTimestamp)
        return "success"
    }

    fun setDoublePay(workerId: String, intervalBegin: Int, intervalEnd: Int): String {
        val worker = workers[workerId]
        if (worker == null || intervalEnd <= intervalBegin) {
            return "invalid_request"
        }
        worker.doublePay.add(intArrayOf(intervalBegin, intervalEnd))
        return "true"
    }

    fun calcSalary(workerId: String, startTimestamp: Int, endTimestamp: Int): String {
        val worker = workers[workerId] ?: return ""
        var total = 0L
        for (session in worker.finished) {
            val lo = maxOf(session.start, startTimestamp)
            val hi = minOf(session.end, endTimestamp)
            if (hi > lo) {
                val bonus = bonusOverlap(lo, hi, worker.doublePay)
                total += (hi - lo - bonus).toLong() * session.rate + bonus.toLong() * session.rate * 2
            }
        }
        return total.toString()
    }
}

fun bonusOverlap(lo: Int, hi: Int, windows: List<IntArray>): Int {
    val segs = ArrayList<IntArray>()
    for (window in windows) {
        val start = maxOf(lo, window[0])
        val stop = minOf(hi, window[1])
        if (stop > start) {
            segs.add(intArrayOf(start, stop))
        }
    }
    segs.sortBy { it[0] }
    val merged = ArrayList<IntArray>()
    for (seg in segs) {
        if (merged.isEmpty() || seg[0] >= merged[merged.lastIndex][1]) {
            merged.add(intArrayOf(seg[0], seg[1]))
        } else {
            merged[merged.lastIndex][1] = maxOf(merged[merged.lastIndex][1], seg[1])
        }
    }
    var sum = 0
    for (seg in merged) {
        sum += seg[1] - seg[0]
    }
    return sum
}
