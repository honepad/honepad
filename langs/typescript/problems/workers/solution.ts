class Worker {
  constructor(workerId, position, compensation) {
    this.workerId = workerId;
    this.position = position;
    this.compensation = compensation;
    this.inOffice = false;
    this.enteredAt = null;
    this.finished = [];
    this.pendingPromo = null;
  }

  totalTime() {
    return this.finished.reduce((sum, [start, end]) => sum + (end - start), 0);
  }

  positionTime(position) {
    return this.finished
      .filter(([, , , pos]) => pos === position)
      .reduce((sum, [start, end]) => sum + (end - start), 0);
  }

  applyPromoOnEnter(timestamp) {
    if (this.pendingPromo === null) return;
    const [newPos, newComp, startTs] = this.pendingPromo;
    if (timestamp >= startTs) {
      this.position = newPos;
      this.compensation = newComp;
      this.pendingPromo = null;
    }
  }
}

class Simulation {
  constructor() {
    this.workers = {};
  }

  addWorker(workerId, position, compensation) {
    if (Object.prototype.hasOwnProperty.call(this.workers, workerId)) return "false";
    this.workers[workerId] = new Worker(workerId, position, compensation);
    return "true";
  }

  register(workerId, timestamp) {
    const worker = this.workers[workerId];
    if (!worker) return "invalid_request";
    if (worker.inOffice) {
      worker.finished.push([
        worker.enteredAt,
        timestamp,
        worker.compensation,
        worker.position,
      ]);
      worker.inOffice = false;
      worker.enteredAt = null;
      return "registered";
    }
    worker.applyPromoOnEnter(timestamp);
    worker.inOffice = true;
    worker.enteredAt = timestamp;
    return "registered";
  }

  get(workerId) {
    const worker = this.workers[workerId];
    if (!worker) return "";
    return String(worker.totalTime());
  }

  topNWorkers(n, position) {
    const matched = Object.values(this.workers).filter((w) => w.position === position);
    matched.sort(
      (a, b) =>
        b.positionTime(position) - a.positionTime(position) ||
        (a.workerId < b.workerId ? -1 : a.workerId > b.workerId ? 1 : 0),
    );
    return matched
      .slice(0, n)
      .map((w) => `${w.workerId}(${w.positionTime(position)})`)
      .join(", ");
  }

  promote(workerId, newPosition, newCompensation, startTimestamp) {
    const worker = this.workers[workerId];
    if (!worker || worker.pendingPromo !== null) return "invalid_request";
    worker.pendingPromo = [newPosition, newCompensation, startTimestamp];
    return "success";
  }

  calcSalary(workerId, startTimestamp, endTimestamp) {
    const worker = this.workers[workerId];
    if (!worker) return "";
    let total = 0;
    for (const [sessionStart, sessionEnd, rate] of worker.finished) {
      const lo = Math.max(sessionStart, startTimestamp);
      const hi = Math.min(sessionEnd, endTimestamp);
      if (hi > lo) total += (hi - lo) * rate;
    }
    return String(total);
  }
}

module.exports = { Simulation };
