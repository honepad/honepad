(defn Simulation []
  (atom {:gpus {} :gpu-order [] :jobs {} :next-seq 0}))

(defn add_gpu [sim gpu-id mem]
  (cond
    (<= mem 0) "invalid_request"
    (contains? (:gpus @sim) gpu-id) "false"
    :else
    (do
      (swap! sim (fn [s]
                   (-> s
                       (assoc-in [:gpus gpu-id] {:gpu-id gpu-id :mem mem :job-id nil})
                       (update :gpu-order conj gpu-id))))
      "true")))

(defn submit_job [sim job-id mem]
  (cond
    (<= mem 0) "invalid_request"
    (contains? (:jobs @sim) job-id) "false"
    :else
    (do
      (swap! sim (fn [s]
                   (-> s
                       (assoc-in [:jobs job-id] {:job-id job-id
                                                 :mem mem
                                                 :seq (:next-seq s)
                                                 :priority 0
                                                 :state "queued"
                                                 :gpu-id nil})
                       (update :next-seq inc))))
      "true")))

(defn status [sim job-id]
  (if-let [job (get-in @sim [:jobs job-id])]
    (:state job)
    ""))

(defn assign [sim]
  (let [queued (->> (:jobs @sim)
                    vals
                    (filter #(= (:state %) "queued"))
                    (sort-by (juxt (comp - :priority) :seq)))]
    (or (some (fn [job]
                (some (fn [gpu-id]
                        (let [gpu (get-in @sim [:gpus gpu-id])]
                          (when (and (nil? (:job-id gpu))
                                     (>= (:mem gpu) (:mem job)))
                            (swap! sim (fn [s]
                                         (-> s
                                             (assoc-in [:jobs (:job-id job) :state] "running")
                                             (assoc-in [:jobs (:job-id job) :gpu-id] gpu-id)
                                             (assoc-in [:gpus gpu-id :job-id] (:job-id job)))))
                            (:job-id job))))
                      (:gpu-order @sim)))
              queued)
        "")))

(defn complete [sim job-id]
  (let [job (get-in @sim [:jobs job-id])]
    (if (or (nil? job) (not= (:state job) "running") (nil? (:gpu-id job)))
      "invalid_request"
      (do
        (swap! sim (fn [s]
                     (-> s
                         (assoc-in [:gpus (:gpu-id job) :job-id] nil)
                         (assoc-in [:jobs job-id :gpu-id] nil)
                         (assoc-in [:jobs job-id :state] "done"))))
        "true"))))

(defn cancel [sim job-id]
  (let [job (get-in @sim [:jobs job-id])]
    (if (or (nil? job) (= (:state job) "done"))
      "invalid_request"
      (do
        (when (and (= (:state job) "running") (:gpu-id job))
          (swap! sim assoc-in [:gpus (:gpu-id job) :job-id] nil))
        (swap! sim update :jobs dissoc job-id)
        (when (= (:state job) "running")
          (assign sim))
        "true"))))

(defn set_priority [sim job-id priority]
  (let [job (get-in @sim [:jobs job-id])]
    (if (or (nil? job) (not= (:state job) "queued"))
      "invalid_request"
      (do
        (swap! sim assoc-in [:jobs job-id :priority] priority)
        "true"))))
