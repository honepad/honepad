public class Simulation {
    public Simulation() {}

    /**
     * Returns {@code "true"} if created, {@code "false"} if the id exists.
     */
    public String addWorker(String workerId, String position, int compensation) {
        return "";
    }

    /**
     * Toggle in or out. Returns {@code "registered"}, or
     * {@code "invalid_request"} if missing.
     */
    public String register(String workerId, int timestamp) {
        return "";
    }

    /**
     * Total finished time as a string, or {@code ""} if missing.
     */
    public String get(String workerId) {
        return "";
    }

    /**
     * Current position as {@code id(time), ...}. Time is finished time
     * in that position. Example: {@code "Jason(50), John(50), Ashley(0)"}.
     */
    public String topNWorkers(int n, String position) {
        return "";
    }

    /**
     * Queue one change. Applied on the next enter at or after
     * startTimestamp. Returns {@code "success"} or
     * {@code "invalid_request"}.
     */
    public String promote(
            String workerId, String newPosition, int newCompensation, int startTimestamp) {
        return "";
    }

    /**
     * Pay for finished sessions overlapping the window, or {@code ""}.
     */
    public String calcSalary(String workerId, int startTimestamp, int endTimestamp) {
        return "";
    }
}
