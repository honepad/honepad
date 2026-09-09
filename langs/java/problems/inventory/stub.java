public class Simulation {
    public Simulation() {}

    /**
     * Returns {@code "true"} if created, {@code "false"} if the sku exists.
     */
    public String createItem(String sku, String name) {
        return "";
    }

    /**
     * Add delta units. New qty as a string, {@code ""} if missing, or
     * {@code invalid_request}.
     */
    public String stock(String sku, int delta) {
        return "";
    }

    /**
     * On-hand quantity as a string, or {@code ""}.
     */
    public String getQty(String sku) {
        return "";
    }

    /**
     * Skus at or below threshold as {@code id(qty)}, or {@code ""}.
     */
    public String listLow(int threshold) {
        return "";
    }

    /**
     * Hold n on-hand units. {@code "true"} or {@code "invalid_request"}.
     */
    public String reserve(String sku, int n) {
        return "";
    }

    /**
     * Free n reserved units. {@code "true"} or {@code "invalid_request"}.
     */
    public String release(String sku, int n) {
        return "";
    }

    /**
     * Consume n reserved units. {@code "true"} or {@code "invalid_request"}.
     */
    public String ship(String sku, int n) {
        return "";
    }
}
