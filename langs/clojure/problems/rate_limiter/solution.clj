(defn- make-key []
  {:limit 3
   :window 10
   :window-id nil
   :used 0})

(defn Simulation []
  (atom {:keys {}}))

(defn- ensure-key! [sim key]
  (when-not (contains? (:keys @sim) key)
    (swap! sim assoc-in [:keys key] (make-key)))
  (get-in @sim [:keys key]))

(defn- persist-window! [sim key timestamp]
  (let [item (get-in @sim [:keys key])
        window-id (quot timestamp (:window item))]
    (when (or (nil? (:window-id item)) (not= window-id (:window-id item)))
      (swap! sim update-in [:keys key] assoc :window-id window-id :used 0))))

(defn configure [sim key limit window]
  (if (or (<= limit 0) (<= window 0))
    "invalid_request"
    (do
      (swap! sim assoc-in [:keys key] {:limit limit
                                       :window window
                                       :window-id nil
                                       :used 0})
      "true")))

(defn remaining [sim key timestamp]
  (let [item (ensure-key! sim key)
        window-id (quot timestamp (:window item))
        used (if (or (nil? (:window-id item)) (not= window-id (:window-id item)))
               0
               (:used item))]
    (str (- (:limit item) used))))

(defn allow_weighted [sim key cost timestamp]
  (if (<= cost 0)
    "invalid_request"
    (do
      (ensure-key! sim key)
      (persist-window! sim key timestamp)
      (let [item (get-in @sim [:keys key])]
        (if (> (+ (:used item) cost) (:limit item))
          "false"
          (do
            (swap! sim update-in [:keys key :used] + cost)
            "true"))))))

(defn allow [sim key timestamp]
  (allow_weighted sim key 1 timestamp))
