(defn Simulation []
  (atom {:backends [] :by-id {} :cursor 0 :sticky-map {} :use-least false}))

(defn- reset-cycle [s]
  (-> s
      (assoc :cursor 0 :use-least false)
      (update :backends (fn [items]
                          (mapv #(assoc % :inflight 0) items)))
      (as-> nxt
            (assoc nxt :by-id
                   (into {} (map (fn [item] [(:backend-id item) item]) (:backends nxt)))))))

(defn- tickets [items]
  (vec (mapcat (fn [item] (repeat (:weight item) item)) items)))

(defn- pick [s]
  (let [healthy (filterv :health (:backends s))]
    (if (empty? healthy)
      [nil s]
      (let [pool (if (:use-least s)
                   (let [least (apply min (map :inflight healthy))]
                     (filterv #(= (:inflight %) least) healthy))
                   healthy)
            tix (tickets pool)]
        (if (empty? tix)
          [nil s]
          (let [chosen (nth tix (mod (:cursor s) (count tix)))]
            [chosen (update s :cursor inc)]))))))

(defn- put-item [s item]
  (let [backends (mapv (fn [cur]
                         (if (= (:backend-id cur) (:backend-id item)) item cur))
                       (:backends s))]
    (-> s
        (assoc :backends backends)
        (assoc-in [:by-id (:backend-id item)] item))))

(defn- take-one [s]
  (let [[item s] (pick s)]
    (if (nil? item)
      ["" s]
      (let [item (update item :inflight inc)]
        [(:backend-id item) (put-item s item)]))))

(defn add_backend [sim backend-id]
  (if (contains? (:by-id @sim) backend-id)
    "false"
    (do
      (swap! sim (fn [s]
                   (let [item {:backend-id backend-id :health true :weight 1 :inflight 0}]
                     (-> s
                         (update :backends conj item)
                         (assoc-in [:by-id backend-id] item)))))
      "true")))

(defn set_health [sim backend-id flag]
  (let [item (get-in @sim [:by-id backend-id])]
    (if (or (nil? item) (not (#{0 1} flag)))
      "invalid_request"
      (do
        (swap! sim (fn [s]
                     (let [item (assoc (get-in s [:by-id backend-id]) :health (= flag 1))]
                       (reset-cycle (put-item s item)))))
        "true"))))

(defn set_weight [sim backend-id weight]
  (let [item (get-in @sim [:by-id backend-id])]
    (if (or (nil? item) (<= weight 0))
      "invalid_request"
      (do
        (swap! sim (fn [s]
                     (let [item (assoc (get-in s [:by-id backend-id]) :weight weight)]
                       (reset-cycle (put-item s item)))))
        "true"))))

(defn route [sim]
  (let [[chosen nxt] (take-one @sim)]
    (reset! sim nxt)
    chosen))

(defn sticky [sim client-id]
  (let [s @sim
        bound (get-in s [:sticky-map client-id])
        item (when bound (get-in s [:by-id bound]))]
    (if (and item (:health item))
      (let [item (update item :inflight inc)]
        (swap! sim put-item item)
        (:backend-id item))
      (let [[chosen nxt] (take-one s)
            nxt (if (seq chosen)
                  (assoc-in nxt [:sticky-map client-id] chosen)
                  nxt)]
        (reset! sim nxt)
        chosen))))

(defn done [sim backend-id]
  (let [item (get-in @sim [:by-id backend-id])]
    (if (or (nil? item) (<= (:inflight item) 0))
      "invalid_request"
      (do
        (swap! sim (fn [s]
                     (let [item (update (get-in s [:by-id backend-id]) :inflight dec)]
                       (-> (put-item s item)
                           (assoc :use-least true)))))
        "true"))))
