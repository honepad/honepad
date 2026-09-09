(defn- make-item [sku name]
  {:sku sku
   :name name
   :qty 0
   :reserved 0})

(defn Simulation []
  (atom {:items {}}))

(defn create_item [sim sku name]
  (if (contains? (:items @sim) sku)
    "false"
    (do
      (swap! sim assoc-in [:items sku] (make-item sku name))
      "true")))

(defn stock [sim sku delta]
  (if-let [item (get-in @sim [:items sku])]
    (let [nxt (+ (:qty item) delta)]
      (if (< nxt (:reserved item))
        "invalid_request"
        (do
          (swap! sim assoc-in [:items sku :qty] nxt)
          (str nxt))))
    ""))

(defn get_qty [sim sku]
  (if-let [item (get-in @sim [:items sku])]
    (str (:qty item))
    ""))

(defn list_low [sim threshold]
  (->> (vals (:items @sim))
       (filter #(<= (:qty %) threshold))
       (sort (fn [a b]
               (let [c (compare (:qty a) (:qty b))]
                 (if (zero? c)
                   (compare (:sku a) (:sku b))
                   c))))
       (map #(str (:sku %) "(" (:qty %) ")"))
       (interpose ", ")
       (apply str)))

(defn reserve [sim sku n]
  (let [item (get-in @sim [:items sku])]
    (if (or (nil? item) (<= n 0) (> (+ (:reserved item) n) (:qty item)))
      "invalid_request"
      (do
        (swap! sim update-in [:items sku :reserved] + n)
        "true"))))

(defn release [sim sku n]
  (let [item (get-in @sim [:items sku])]
    (if (or (nil? item) (<= n 0) (> n (:reserved item)))
      "invalid_request"
      (do
        (swap! sim update-in [:items sku :reserved] - n)
        "true"))))

(defn ship [sim sku n]
  (let [item (get-in @sim [:items sku])]
    (if (or (nil? item) (<= n 0) (> n (:reserved item)))
      "invalid_request"
      (do
        (swap! sim update-in [:items sku] (fn [cur]
                                            (-> cur
                                                (update :reserved - n)
                                                (update :qty - n))))
        "true"))))
