import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;

class WorkSession {
    int start;
    int end;
    int rate;
    String position;

    WorkSession(int start, int end, int rate, String position) {
        this.start = start;
        this.end = end;
        this.rate = rate;
        this.position = position;
    }
}

class Promo {
    String position;
    int compensation;
    int startTimestamp;

    Promo(String position, int compensation, int startTimestamp) {
        this.position = position;
        this.compensation = compensation;
        this.startTimestamp = startTimestamp;
    }
}

class Worker {
    String workerId;
    String position;
    int compensation;
    boolean inOffice = false;
    Integer enteredAt = null;
    List<WorkSession> finished = new ArrayList<>();
    Promo pendingPromo = null;

    Worker(String workerId, String position, int compensation) {
        this.workerId = workerId;
        this.position = position;
        this.compensation = compensation;
    }

    int totalTime() {
        int sum = 0;
        for (WorkSession session : finished) {
            sum += session.end - session.start;
        }
        return sum;
    }

    int positionTime(String pos) {
        int sum = 0;
        for (WorkSession session : finished) {
            if (session.position.equals(pos)) {
                sum += session.end - session.start;
            }
        }
        return sum;
    }

    void applyPromoOnEnter(int timestamp) {
        if (pendingPromo == null) {
            return;
        }
        if (timestamp >= pendingPromo.startTimestamp) {
            position = pendingPromo.position;
            compensation = pendingPromo.compensation;
            pendingPromo = null;
        }
    }
}

public class Simulation {
    private final Map<String, Worker> workers = new LinkedHashMap<>();

    public Simulation() {}

    public String addWorker(String workerId, String position, int compensation) {
        if (workers.containsKey(workerId)) {
            return "false";
        }
        workers.put(workerId, new Worker(workerId, position, compensation));
        return "true";
    }

    public String register(String workerId, int timestamp) {
        Worker worker = workers.get(workerId);
        if (worker == null) {
            return "invalid_request";
        }
        if (worker.inOffice) {
            worker.finished.add(
                new WorkSession(worker.enteredAt, timestamp, worker.compensation, worker.position)
            );
            worker.inOffice = false;
            worker.enteredAt = null;
            return "registered";
        }
        worker.applyPromoOnEnter(timestamp);
        worker.inOffice = true;
        worker.enteredAt = timestamp;
        return "registered";
    }

    public String get(String workerId) {
        Worker worker = workers.get(workerId);
        if (worker == null) {
            return "";
        }
        return String.valueOf(worker.totalTime());
    }

    public String topNWorkers(int n, String position) {
        List<Worker> matched = new ArrayList<>();
        for (Worker worker : workers.values()) {
            if (worker.position.equals(position)) {
                matched.add(worker);
            }
        }
        matched.sort((a, b) -> {
            int d = Integer.compare(b.positionTime(position), a.positionTime(position));
            return d != 0 ? d : a.workerId.compareTo(b.workerId);
        });
        if (n < matched.size()) {
            matched = matched.subList(0, n);
        }
        List<String> parts = new ArrayList<>();
        for (Worker worker : matched) {
            parts.add(worker.workerId + "(" + worker.positionTime(position) + ")");
        }
        return String.join(", ", parts);
    }

    public String promote(String workerId, String newPosition, int newCompensation, int startTimestamp) {
        Worker worker = workers.get(workerId);
        if (worker == null || worker.pendingPromo != null) {
            return "invalid_request";
        }
        worker.pendingPromo = new Promo(newPosition, newCompensation, startTimestamp);
        return "success";
    }

    public String calcSalary(String workerId, int startTimestamp, int endTimestamp) {
        Worker worker = workers.get(workerId);
        if (worker == null) {
            return "";
        }
        long total = 0;
        for (WorkSession session : worker.finished) {
            int lo = Math.max(session.start, startTimestamp);
            int hi = Math.min(session.end, endTimestamp);
            if (hi > lo) {
                total += (long) (hi - lo) * session.rate;
            }
        }
        return String.valueOf(total);
    }
}
