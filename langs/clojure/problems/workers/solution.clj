(defn- make-worker [worker-id position compensation]
  {:worker-id worker-id
   :position position
   :compensation compensation
   :in-office false
   :entered-at nil
   :finished []
   :pending-promo nil
   :double-pay []})

(defn Simulation []
  (atom {:workers {}}))

(defn- total-time [worker]
  (reduce (fn [acc [start end _ _]]
            (+ acc (- end start)))
          0
          (:finished worker)))

(defn- position-time [worker position]
  (reduce (fn [acc [start end _ pos]]
            (if (= pos position)
              (+ acc (- end start))
              acc))
          0
          (:finished worker)))

(defn- apply-promo-on-enter [worker timestamp]
  (if-let [[new-pos new-comp start-ts] (:pending-promo worker)]
    (if (>= timestamp start-ts)
      (assoc worker
             :position new-pos
             :compensation new-comp
             :pending-promo nil)
      worker)
    worker))

(defn add_worker [sim worker_id position compensation]
  (if (contains? (:workers @sim) worker_id)
    "false"
    (do
      (swap! sim assoc-in [:workers worker_id]
             (make-worker worker_id position compensation))
      "true")))

(defn register [sim worker_id timestamp]
  (if-let [worker (get-in @sim [:workers worker_id])]
    (if (:in-office worker)
      (let [worker (-> worker
                       (update :finished conj
                               [(:entered-at worker) timestamp
                                (:compensation worker) (:position worker)])
                       (assoc :in-office false :entered-at nil))]
        (swap! sim assoc-in [:workers worker_id] worker)
        "registered")
      (let [worker (-> worker
                       (apply-promo-on-enter timestamp)
                       (assoc :in-office true :entered-at timestamp))]
        (swap! sim assoc-in [:workers worker_id] worker)
        "registered"))
    "invalid_request"))

(defn get [sim worker_id]
  (if-let [worker (get-in @sim [:workers worker_id])]
    (str (total-time worker))
    ""))

(defn top_n_workers [sim n position]
  (->> (vals (:workers @sim))
       (filter #(= (:position %) position))
       (sort (fn [a b]
               (let [c (compare (position-time b position)
                                (position-time a position))]
                 (if (zero? c)
                   (compare (:worker-id a) (:worker-id b))
                   c))))
       (take n)
       (map #(str (:worker-id %) "(" (position-time % position) ")"))
       (interpose ", ")
       (apply str)))

(defn promote [sim worker_id new_position new_compensation start_timestamp]
  (let [worker (get-in @sim [:workers worker_id])]
    (if (or (nil? worker) (some? (:pending-promo worker)))
      "invalid_request"
      (do
        (swap! sim assoc-in [:workers worker_id :pending-promo]
               [new_position new_compensation start_timestamp])
        "success"))))

(defn- bonus-overlap [lo hi windows]
  (let [segs (->> windows
                  (keep (fn [[begin end]]
                          (let [start (max lo begin)
                                stop (min hi end)]
                            (when (> stop start)
                              [start stop]))))
                  (sort-by first))
        merged (reduce (fn [acc [start stop]]
                         (if (or (empty? acc) (>= start (second (peek acc))))
                           (conj acc [start stop])
                           (conj (pop acc) [(first (peek acc))
                                            (max (second (peek acc)) stop)])))
                       []
                       segs)]
    (reduce (fn [acc [start stop]] (+ acc (- stop start))) 0 merged)))

(defn set_double_pay [sim worker_id interval_begin interval_end]
  (let [worker (get-in @sim [:workers worker_id])]
    (if (or (nil? worker) (<= interval_end interval_begin))
      "invalid_request"
      (do
        (swap! sim update-in [:workers worker_id :double-pay]
               (fnil conj []) [interval_begin interval_end])
        "true"))))

(defn calc_salary [sim worker_id start_timestamp end_timestamp]
  (if-let [worker (get-in @sim [:workers worker_id])]
    (str
     (reduce (fn [acc [session-start session-end rate _]]
               (let [lo (max session-start start_timestamp)
                     hi (min session-end end_timestamp)]
                 (if (> hi lo)
                   (let [bonus (bonus-overlap lo hi (:double-pay worker))]
                     (+ acc (* (- hi lo bonus) rate) (* bonus rate 2)))
                   acc)))
             0
             (:finished worker)))
    ""))
