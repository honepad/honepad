import java.util.{ArrayList, LinkedHashMap, List => JList, Map => JMap}

class WorkSession(val start: Int, val end: Int, val rate: Int, val position: String)

class Promo(val position: String, val compensation: Int, val startTimestamp: Int)

class Worker(val workerId: String, var position: String, var compensation: Int) {
  var inOffice: Boolean = false
  var enteredAt: Integer = null
  val finished: JList[WorkSession] = new ArrayList[WorkSession]()
  var pendingPromo: Promo = null

  def totalTime(): Int = {
    var sum = 0
    var i = 0
    while (i < finished.size()) {
      val session = finished.get(i)
      sum += session.end - session.start
      i += 1
    }
    sum
  }

  def positionTime(pos: String): Int = {
    var sum = 0
    var i = 0
    while (i < finished.size()) {
      val session = finished.get(i)
      if (session.position == pos) {
        sum += session.end - session.start
      }
      i += 1
    }
    sum
  }

  def applyPromoOnEnter(timestamp: Int): Unit = {
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

class Simulation {
  private val workers: JMap[String, Worker] = new LinkedHashMap[String, Worker]()

  def addWorker(workerId: String, position: String, compensation: Int): String = {
    if (workers.containsKey(workerId)) {
      return "false"
    }
    workers.put(workerId, new Worker(workerId, position, compensation))
    "true"
  }

  def register(workerId: String, timestamp: Int): String = {
    val worker = workers.get(workerId)
    if (worker == null) {
      return "invalid_request"
    }
    if (worker.inOffice) {
      worker.finished.add(
        new WorkSession(worker.enteredAt.intValue(), timestamp, worker.compensation, worker.position)
      )
      worker.inOffice = false
      worker.enteredAt = null
      return "registered"
    }
    worker.applyPromoOnEnter(timestamp)
    worker.inOffice = true
    worker.enteredAt = Int.box(timestamp)
    "registered"
  }

  def get(workerId: String): String = {
    val worker = workers.get(workerId)
    if (worker == null) {
      return ""
    }
    String.valueOf(worker.totalTime())
  }

  def topNWorkers(n: Int, position: String): String = {
    val matched = new ArrayList[Worker]()
    val it = workers.values().iterator()
    while (it.hasNext) {
      val worker = it.next()
      if (worker.position == position) {
        matched.add(worker)
      }
    }
    matched.sort((a: Worker, b: Worker) => {
      val d = Integer.compare(b.positionTime(position), a.positionTime(position))
      if (d != 0) d else a.workerId.compareTo(b.workerId)
    })
    val sliced = if (n < matched.size()) matched.subList(0, n) else matched
    val parts = new ArrayList[String]()
    val sit = sliced.iterator()
    while (sit.hasNext) {
      val worker = sit.next()
      parts.add(worker.workerId + "(" + worker.positionTime(position) + ")")
    }
    String.join(", ", parts)
  }

  def promote(
      workerId: String,
      newPosition: String,
      newCompensation: Int,
      startTimestamp: Int
  ): String = {
    val worker = workers.get(workerId)
    if (worker == null || worker.pendingPromo != null) {
      return "invalid_request"
    }
    worker.pendingPromo = new Promo(newPosition, newCompensation, startTimestamp)
    "success"
  }

  def calcSalary(workerId: String, startTimestamp: Int, endTimestamp: Int): String = {
    val worker = workers.get(workerId)
    if (worker == null) {
      return ""
    }
    var total: Long = 0
    var i = 0
    while (i < worker.finished.size()) {
      val session = worker.finished.get(i)
      val lo = Math.max(session.start, startTimestamp)
      val hi = Math.min(session.end, endTimestamp)
      if (hi > lo) {
        total += (hi.toLong - lo.toLong) * session.rate
      }
      i += 1
    }
    String.valueOf(total)
  }
}
