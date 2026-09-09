public class Simulation {
    public Simulation() {}

    /**
     * Spend one token. {@code "true"} if it fits, {@code "false"} if the
     * window is full.
     */
    public String allow(String key, int timestamp) {
        return "";
    }

    /**
     * Set that key's limit and window. {@code "true"} or
     * {@code invalid_request}.
     */
    public String configure(String key, int limit, int window) {
        return "";
    }

    /**
     * Unused tokens in this window as a string.
     */
    public String remaining(String key, int timestamp) {
        return "";
    }

    /**
     * Spend cost tokens. {@code "true"}, {@code "false"}, or
     * {@code invalid_request}.
     */
    public String allowWeighted(String key, int cost, int timestamp) {
        return "";
    }
}
