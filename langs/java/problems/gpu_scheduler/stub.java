public class Simulation {
    public Simulation() {}

    /**
     * Register a device. {@code "true"}, {@code "false"}, or
     * {@code invalid_request}.
     */
    public String addGpu(String gpuId, int mem) {
        return "";
    }

    /**
     * Queue a job. {@code "true"}, {@code "false"}, or
     * {@code invalid_request}.
     */
    public String submitJob(String jobId, int mem) {
        return "";
    }

    /**
     * queued, running, done, or {@code ""}.
     */
    public String status(String jobId) {
        return "";
    }

    /**
     * Start one queued job. Job id or {@code ""}.
     */
    public String assign() {
        return "";
    }

    /**
     * Finish a running job. {@code "true"} or {@code invalid_request}.
     */
    public String complete(String jobId) {
        return "";
    }

    /**
     * Drop a queued or running job. {@code "true"} or
     * {@code invalid_request}.
     */
    public String cancel(String jobId) {
        return "";
    }

    /**
     * Set a queued job's rank. {@code "true"} or {@code invalid_request}.
     */
    public String setPriority(String jobId, int priority) {
        return "";
    }
}
