(defn InMemoryDatabase []
  (atom {:database {}
         :backup-timestamps []
         :backup-states []}))

(defn- set-internal [db key field value expiry]
  (swap! db assoc-in [:database key field] [value expiry])
  "")

(defn- field-row [db key field]
  (get-in @db [:database key field]))

(defn- alive? [db key field timestamp]
  (if-let [[_ expiry] (field-row db key field)]
    (or (nil? expiry) (< timestamp expiry))
    false))

(defn set [db key field value]
  (set-internal db key field value nil))

(defn get [db key field]
  (if-let [[value _] (field-row db key field)]
    value
    ""))

(defn delete [db key field]
  (if (field-row db key field)
    (do
      (swap! db update-in [:database key] dissoc field)
      "true")
    "false"))

(defn- join-fields [items]
  (->> items
       (sort-by first)
       (map (fn [[field [value _]]] (str field "(" value ")")))
       (interpose ", ")
       (apply str)))

(defn scan [db key]
  (join-fields (vec (get-in @db [:database key] {}))))

(defn scan_by_prefix [db key prefix]
  (join-fields
   (filterv (fn [[field _]]
              (.startsWith ^String field prefix))
            (vec (get-in @db [:database key] {})))))

(defn set_at [db key field value _timestamp]
  (set-internal db key field value nil))

(defn set_at_with_ttl [db key field value timestamp ttl]
  (set-internal db key field value (+ timestamp ttl)))

(defn delete_at [db key field timestamp]
  (if (alive? db key field timestamp)
    (do
      (swap! db update-in [:database key] dissoc field)
      "true")
    "false"))

(defn get_at [db key field timestamp]
  (if (alive? db key field timestamp)
    (first (field-row db key field))
    ""))

(defn- live-items [db key timestamp]
  (filterv (fn [[field _]]
             (alive? db key field timestamp))
           (vec (get-in @db [:database key] {}))))

(defn scan_at [db key timestamp]
  (->> (live-items db key timestamp)
       (map (fn [[field [value _]]] [field [value nil]]))
       vec
       join-fields))

(defn scan_by_prefix_at [db key prefix timestamp]
  (->> (live-items db key timestamp)
       (filter (fn [[field _]] (.startsWith ^String field prefix)))
       (map (fn [[field [value _]]] [field [value nil]]))
       vec
       join-fields))

(defn backup [db timestamp]
  (let [state
        (reduce (fn [acc [key fields]]
                  (let [kept
                        (reduce (fn [inner [field [value expiry]]]
                                  (if (alive? db key field timestamp)
                                    (assoc inner field
                                           [value (when expiry (- expiry timestamp))])
                                    inner))
                                {}
                                fields)]
                    (if (empty? kept)
                      acc
                      (assoc acc key kept))))
                {}
                (:database @db))]
    (swap! db update :backup-timestamps conj timestamp)
    (swap! db update :backup-states conj state)
    (str (count state))))

(defn restore [db timestamp timestamp_to_restore]
  (let [stamps (:backup-timestamps @db)
        idx (dec (count (filterv #(<= % timestamp_to_restore) stamps)))
        backup-state (nth (:backup-states @db) idx)]
    (swap! db assoc :database {})
    (doseq [[key fields] backup-state
            [field [value remaining]] fields]
      (set-internal db key field value
                    (when remaining (+ timestamp remaining))))
    ""))
