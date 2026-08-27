class WorkSession {
  WorkSession(this.start, this.end, this.rate, this.position);

  final int start;
  final int end;
  final int rate;
  final String position;
}

class Promo {
  Promo(this.position, this.compensation, this.startTimestamp);

  final String position;
  final int compensation;
  final int startTimestamp;
}

class Worker {
  Worker(this.workerId, this.position, this.compensation);

  final String workerId;
  String position;
  int compensation;
  bool inOffice = false;
  int? enteredAt;
  final List<WorkSession> finished = [];
  Promo? pendingPromo;

  int totalTime() {
    var sum = 0;
    for (final session in finished) {
      sum += session.end - session.start;
    }
    return sum;
  }

  int positionTime(String pos) {
    var sum = 0;
    for (final session in finished) {
      if (session.position == pos) {
        sum += session.end - session.start;
      }
    }
    return sum;
  }

  void applyPromoOnEnter(int timestamp) {
    final promo = pendingPromo;
    if (promo == null) {
      return;
    }
    if (timestamp >= promo.startTimestamp) {
      position = promo.position;
      compensation = promo.compensation;
      pendingPromo = null;
    }
  }
}

class Simulation {
  final Map<String, Worker> workers = {};

  String addWorker(String workerId, String position, int compensation) {
    if (workers.containsKey(workerId)) {
      return 'false';
    }
    workers[workerId] = Worker(workerId, position, compensation);
    return 'true';
  }

  String register(String workerId, int timestamp) {
    final worker = workers[workerId];
    if (worker == null) {
      return 'invalid_request';
    }
    if (worker.inOffice) {
      worker.finished.add(WorkSession(
        worker.enteredAt!,
        timestamp,
        worker.compensation,
        worker.position,
      ));
      worker.inOffice = false;
      worker.enteredAt = null;
      return 'registered';
    }
    worker.applyPromoOnEnter(timestamp);
    worker.inOffice = true;
    worker.enteredAt = timestamp;
    return 'registered';
  }

  String get(String workerId) {
    final worker = workers[workerId];
    if (worker == null) {
      return '';
    }
    return '${worker.totalTime()}';
  }

  String topNWorkers(int n, String position) {
    final matched = [
      for (final worker in workers.values)
        if (worker.position == position) worker,
    ];
    matched.sort((a, b) {
      final d = b.positionTime(position).compareTo(a.positionTime(position));
      return d != 0 ? d : a.workerId.compareTo(b.workerId);
    });
    final limit = n < matched.length ? n : matched.length;
    return matched
        .sublist(0, limit)
        .map((worker) => '${worker.workerId}(${worker.positionTime(position)})')
        .join(', ');
  }

  String promote(
    String workerId,
    String newPosition,
    int newCompensation,
    int startTimestamp,
  ) {
    final worker = workers[workerId];
    if (worker == null || worker.pendingPromo != null) {
      return 'invalid_request';
    }
    worker.pendingPromo = Promo(newPosition, newCompensation, startTimestamp);
    return 'success';
  }

  String calcSalary(String workerId, int startTimestamp, int endTimestamp) {
    final worker = workers[workerId];
    if (worker == null) {
      return '';
    }
    var total = 0;
    for (final session in worker.finished) {
      final lo =
          session.start > startTimestamp ? session.start : startTimestamp;
      final hi = session.end < endTimestamp ? session.end : endTimestamp;
      if (hi > lo) {
        total += (hi - lo) * session.rate;
      }
    }
    return '$total';
  }
}
