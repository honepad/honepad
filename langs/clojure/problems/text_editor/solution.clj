(defn Simulation []
  (atom {:buf "" :pos 0 :undo [] :redo [] :sel nil :clip ""}))

(defn- push-snap [sim]
  (swap! sim (fn [st]
               (-> st
                   (update :undo conj [(:buf st) (:pos st)])
                   (assoc :redo [] :sel nil)))))

(defn insert [sim pos text]
  (let [buf (:buf @sim)]
    (if (or (< pos 0) (> pos (count buf)))
      "invalid_request"
      (do
        (push-snap sim)
        (let [buf (:buf @sim)
              nxt (str (subs buf 0 pos) text (subs buf pos))]
          (swap! sim assoc :buf nxt)
          (str (count nxt)))))))

(defn erase [sim pos n]
  (let [buf (:buf @sim)]
    (if (or (<= n 0) (< pos 0) (> (+ pos n) (count buf)))
      "invalid_request"
      (do
        (push-snap sim)
        (let [buf (:buf @sim)
              deleted (subs buf pos (+ pos n))
              nxt (str (subs buf 0 pos) (subs buf (+ pos n)))]
          (swap! sim (fn [st]
                       (cond-> (assoc st :buf nxt)
                         (> (:pos st) (count nxt)) (assoc :pos (count nxt)))))
          deleted)))))

(defn get_text [sim]
  (:buf @sim))

(defn length [sim]
  (str (count (:buf @sim))))

(defn move [sim pos]
  (if (or (< pos 0) (> pos (count (:buf @sim))))
    "invalid_request"
    (do
      (swap! sim assoc :pos pos)
      "true")))

(defn type_text [sim text]
  (push-snap sim)
  (let [at (:pos @sim)
        buf (:buf @sim)
        nxt (str (subs buf 0 at) text (subs buf at))]
    (swap! sim assoc :buf nxt :pos (+ at (count text)))
    (str (count nxt))))

(defn cursor [sim]
  (str (:pos @sim)))

(defn undo [sim]
  (let [stack (:undo @sim)]
    (if (empty? stack)
      "false"
      (let [[buf pos] (peek stack)]
        (swap! sim (fn [st]
                     (-> st
                         (update :redo conj [(:buf st) (:pos st)])
                         (update :undo pop)
                         (assoc :buf buf :pos pos :sel nil))))
        "true"))))

(defn redo [sim]
  (let [stack (:redo @sim)]
    (if (empty? stack)
      "false"
      (let [[buf pos] (peek stack)]
        (swap! sim (fn [st]
                     (-> st
                         (update :undo conj [(:buf st) (:pos st)])
                         (update :redo pop)
                         (assoc :buf buf :pos pos :sel nil))))
        "true"))))

(defn select [sim start end]
  (if (or (< start 0) (< end 0) (> start end) (> end (count (:buf @sim))))
    "invalid_request"
    (do
      (swap! sim assoc :sel [start end])
      "true")))

(defn cut [sim]
  (let [sel (:sel @sim)]
    (if (or (nil? sel) (= (first sel) (second sel)))
      "invalid_request"
      (let [[start end] sel
            buf (:buf @sim)
            text (subs buf start end)
            nxt (str (subs buf 0 start) (subs buf end))]
        (swap! sim assoc :buf nxt :clip text :pos start :sel nil)
        text))))

(defn copy_sel [sim]
  (let [sel (:sel @sim)]
    (if (or (nil? sel) (= (first sel) (second sel)))
      "invalid_request"
      (let [[start end] sel
            text (subs (:buf @sim) start end)]
        (swap! sim assoc :clip text)
        text))))

(defn paste [sim]
  (let [clip (:clip @sim)]
    (if (= clip "")
      "invalid_request"
      (let [at (:pos @sim)
            buf (:buf @sim)
            nxt (str (subs buf 0 at) clip (subs buf at))]
        (swap! sim assoc :buf nxt :pos (+ at (count clip)))
        (str (count nxt))))))
