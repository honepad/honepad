public class Simulation {
    public Simulation() {}

    /**
     * Returns {@code "true"} if new, {@code "false"} if already subscribed.
     */
    public String subscribe(String topic, String client) {
        return "";
    }

    /**
     * Returns {@code "true"} if removed, {@code "false"} if not subscribed.
     */
    public String unsubscribe(String topic, String client) {
        return "";
    }

    /**
     * Deliver {@code topic:message}. Subscriber count, or {@code "0"}.
     */
    public String publish(String topic, String message) {
        return "";
    }

    /**
     * Delivered messages as {@code topic:message}, or {@code ""}.
     */
    public String inbox(String client) {
        return "";
    }

    /**
     * Sorted topics with subscribers, or {@code ""}.
     */
    public String listTopics() {
        return "";
    }

    /**
     * Sorted client ids on topic, or {@code ""}.
     */
    public String subscribers(String topic) {
        return "";
    }

    /**
     * Oldest inbox message, or {@code ""}.
     */
    public String peek(String client) {
        return "";
    }

    /**
     * Drop oldest n. Remaining count, or {@code invalid_request}.
     */
    public String ack(String client, int n) {
        return "";
    }

    /**
     * Store last retained message. Returns {@code ""}.
     */
    public String retain(String topic, String message) {
        return "";
    }
}
