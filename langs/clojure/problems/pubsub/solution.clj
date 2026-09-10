(defn Simulation []
  (atom {:subs {} :inbox-map {} :retained {}}))

(defn subscribe [sim topic client]
  (let [clients (get-in @sim [:subs topic] [])]
    (if (some #{client} clients)
      "false"
      (do
        (swap! sim update-in [:subs topic] (fnil conj []) client)
        (when-let [kept (get-in @sim [:retained topic])]
          (swap! sim update-in [:inbox-map client] (fnil conj []) (str topic ":" kept)))
        "true"))))

(defn unsubscribe [sim topic client]
  (let [clients (get-in @sim [:subs topic])]
    (if (or (nil? clients) (not (some #{client} clients)))
      "false"
      (do
        (swap! sim update-in [:subs topic] (fn [cur] (vec (remove #{client} cur))))
        (when (empty? (get-in @sim [:subs topic]))
          (swap! sim update :subs dissoc topic))
        "true"))))

(defn publish [sim topic message]
  (let [clients (get-in @sim [:subs topic] [])
        payload (str topic ":" message)]
    (doseq [client clients]
      (swap! sim update-in [:inbox-map client] (fnil conj []) payload))
    (str (count clients))))

(defn inbox [sim client]
  (->> (get-in @sim [:inbox-map client] [])
       (interpose ", ")
       (apply str)))

(defn list_topics [sim]
  (->> (keys (:subs @sim))
       sort
       (interpose ", ")
       (apply str)))

(defn subscribers [sim topic]
  (->> (get-in @sim [:subs topic] [])
       sort
       (interpose ", ")
       (apply str)))

(defn peek [sim client]
  (let [items (get-in @sim [:inbox-map client] [])]
    (if (empty? items) "" (first items))))

(defn ack [sim client n]
  (let [items (get-in @sim [:inbox-map client])]
    (cond
      (or (<= n 0) (nil? items)) "invalid_request"
      (> n (count items)) "invalid_request"
      :else
      (do
        (swap! sim assoc-in [:inbox-map client] (vec (drop n items)))
        (str (count (get-in @sim [:inbox-map client])))))))

(defn retain [sim topic message]
  (swap! sim assoc-in [:retained topic] message)
  "")
