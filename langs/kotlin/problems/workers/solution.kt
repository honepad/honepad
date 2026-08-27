class WorkSession(val start: Int, val end: Int, val rate: Int, val position: String)

class Promo(val position: String, val compensation: Int, val startTimestamp: Int)

class Worker(val workerId: String, var position: String, var compensation: Int) {
    var inOffice = false
    var enteredAt: Int? = null
    val finished = ArrayList<WorkSession>()
    var pendingPromo: Promo? = null

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

    fun calcSalary(workerId: String, startTimestamp: Int, endTimestamp: Int): String {
        val worker = workers[workerId] ?: return ""
        var total = 0L
        for (session in worker.finished) {
            val lo = maxOf(session.start, startTimestamp)
            val hi = minOf(session.end, endTimestamp)
            if (hi > lo) {
                total += (hi - lo).toLong() * session.rate
            }
        }
        return total.toString()
    }
}
