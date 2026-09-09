public class Simulation {
    public Simulation() {}

    /**
     * Register a backend. {@code "true"} if created, {@code "false"} if it
     * exists.
     */
    public String addBackend(String backendId) {
        return "";
    }

    /**
     * Next backend id, or {@code ""}.
     */
    public String route() {
        return "";
    }

    /**
     * 1 up, 0 down. {@code "true"} or {@code invalid_request}.
     */
    public String setHealth(String backendId, int flag) {
        return "";
    }

    /**
     * Turns per cycle. {@code "true"} or {@code invalid_request}.
     */
    public String setWeight(String backendId, int weight) {
        return "";
    }

    /**
     * Same healthy backend for this client, or {@code ""}.
     */
    public String sticky(String clientId) {
        return "";
    }

    /**
     * Drop one in-flight. {@code "true"} or {@code invalid_request}.
     */
    public String done(String backendId) {
        return "";
    }
}
