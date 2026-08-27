(defn Simulation []
  (atom {:files {}
         :capacity {"admin" nil}
         :backups {}}))

(defn- used [sim user-id]
  (reduce (fn [acc item]
            (if (= (:owner item) user-id)
              (+ acc (:size item))
              acc))
          0
          (vals (:files @sim))))

(defn- remaining [sim user-id]
  (when-let [cap (get (:capacity @sim) user-id)]
    (- cap (used sim user-id))))

(defn- put-file [sim name size owner]
  (swap! sim assoc-in [:files name] {:name name :size size :owner owner}))

(defn add_file [sim name size]
  (if (contains? (:files @sim) name)
    "false"
    (do
      (put-file sim name size "admin")
      "true")))

(defn get_file_size [sim name]
  (if-let [item (get-in @sim [:files name])]
    (str (:size item))
    ""))

(defn delete_file [sim name]
  (if-let [item (get-in @sim [:files name])]
    (do
      (swap! sim update :files dissoc name)
      (str (:size item)))
    ""))

(defn copy_file [sim source dest]
  (if-let [src (get-in @sim [:files source])]
    (if (= source dest)
      (str (:size src))
      (let [dest-item (get-in @sim [:files dest])
            owner (if dest-item (:owner dest-item) (:owner src))
            extra (if dest-item (- (:size src) (:size dest-item)) (:size src))
            left (remaining sim owner)]
        (if (and (some? left) (> extra left))
          ""
          (do
            (if dest-item
              (swap! sim assoc-in [:files dest :size] (:size src))
              (put-file sim dest (:size src) owner))
            (str (:size src))))))
    ""))

(defn get_n_largest [sim prefix n]
  (->> (vals (:files @sim))
       (filter #(.startsWith ^String (:name %) prefix))
       (sort (fn [a b]
               (let [c (compare (:size b) (:size a))]
                 (if (zero? c)
                   (compare (:name a) (:name b))
                   c))))
       (take n)
       (map #(str (:name %) "(" (:size %) ")"))
       (interpose ", ")
       (apply str)))

(defn add_user [sim user_id capacity]
  (if (contains? (:capacity @sim) user_id)
    "false"
    (do
      (swap! sim assoc-in [:capacity user_id] capacity)
      "true")))

(defn add_file_by [sim user_id name size]
  (let [cap-map (:capacity @sim)]
    (if (or (not (contains? cap-map user_id))
            (contains? (:files @sim) name))
      ""
      (let [left (remaining sim user_id)]
        (if (and (some? left) (> size left))
          ""
          (do
            (put-file sim name size user_id)
            (if-let [rem (remaining sim user_id)]
              (str rem)
              "")))))))

(defn merge_user [sim user_id1 user_id2]
  (let [cap1 (get (:capacity @sim) user_id1)
        cap2 (get (:capacity @sim) user_id2)]
    (if (or (= user_id1 user_id2) (nil? cap1) (nil? cap2))
      ""
      (do
        (swap! sim update :files
               (fn [files]
                 (into {}
                       (map (fn [[name item]]
                              [name (if (= (:owner item) user_id2)
                                      (assoc item :owner user_id1)
                                      item)])
                            files))))
        (swap! sim assoc-in [:capacity user_id1] (+ cap1 cap2))
        (swap! sim update :capacity dissoc user_id2)
        (swap! sim update :backups dissoc user_id2)
        (if-let [left (remaining sim user_id1)]
          (str left)
          "")))))

(defn backup_user [sim user_id]
  (if-not (contains? (:capacity @sim) user_id)
    ""
    (let [snapshot (->> (vals (:files @sim))
                        (filter #(= (:owner %) user_id))
                        (map (fn [item] [(:name item) (:size item)]))
                        (into {}))]
      (swap! sim assoc-in [:backups user_id] snapshot)
      (str (count snapshot)))))

(defn restore_user [sim user_id]
  (if-not (contains? (:capacity @sim) user_id)
    ""
    (do
      (swap! sim update :files
             (fn [files]
               (into {}
                     (remove (fn [[_ item]] (= (:owner item) user_id)) files))))
      (if-let [snapshot (get-in @sim [:backups user_id])]
        (let [restored
              (reduce (fn [count [name size]]
                        (cond
                          (contains? (:files @sim) name) count
                          (let [left (remaining sim user_id)]
                            (and (some? left) (> size left)))
                          count
                          :else
                          (do
                            (put-file sim name size user_id)
                            (inc count))))
                      0
                      snapshot)]
          (str restored))
        "0"))))
