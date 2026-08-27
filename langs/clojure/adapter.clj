;; argv: clojure -M adapter.clj <src> <class> <cases.json>
;; Load the solution, instantiate Simulation or InMemoryDatabase,
;; call snake_case methods, compare JSON encodings.
;; Bank booleans are JSON true/false.

(ns honepad.adapter)

(defn- make-parser [text]
  (atom {:text text :i 0 :n (count text)}))

(defn- peek-ch [p]
  (let [{:keys [text i n]} @p]
    (when (< i n)
      (.charAt ^String text i))))

(defn- bump! [p]
  (let [c (peek-ch p)]
    (when c
      (swap! p update :i inc))
    c))

(defn- skipws! [p]
  (loop []
    (let [c (peek-ch p)]
      (when (and c (#{\space \tab \newline \return} c))
        (bump! p)
        (recur)))))

(defn- starts-with? [p token]
  (let [{:keys [text i n]} @p
        m (count token)]
    (and (<= (+ i m) n)
         (= (.substring ^String text i (+ i m)) token))))

(defn- advance! [p nsteps]
  (swap! p update :i + nsteps))

(declare parse-value)

(defn- parse-string [p]
  (when-not (= (bump! p) \")
    (throw (ex-info "expected string" {})))
  (let [out (StringBuilder.)]
    (loop []
      (let [c (bump! p)]
        (cond
          (nil? c) (throw (ex-info "unterminated string" {}))
          (= c \") (str out)
          (= c \\)
          (let [e (bump! p)]
            (cond
              (#{\" \\ \/} e) (.append out e)
              (= e \b) (.append out \backspace)
              (= e \f) (.append out \formfeed)
              (= e \n) (.append out \newline)
              (= e \r) (.append out \return)
              (= e \t) (.append out \tab)
              (= e \u)
              (let [hex (apply str (repeatedly 4 #(or (bump! p)
                                                      (throw (ex-info "bad unicode" {})))))]
                (.append out (char (Integer/parseInt hex 16))))
              :else (throw (ex-info "bad escape" {})))
            (recur))
          :else
          (do (.append out c) (recur)))))))

(defn- parse-number [p]
  (let [start (:i @p)]
    (when (= (peek-ch p) \-)
      (bump! p))
    (while (let [c (peek-ch p)] (and c (Character/isDigit ^char c)))
      (bump! p))
    (let [float? (atom false)]
      (when (= (peek-ch p) \.)
        (reset! float? true)
        (bump! p)
        (while (let [c (peek-ch p)] (and c (Character/isDigit ^char c)))
          (bump! p)))
      (when-let [c (peek-ch p)]
        (when (#{\e \E} c)
          (reset! float? true)
          (bump! p)
          (when-let [s (peek-ch p)]
            (when (#{\+ \-} s)
              (bump! p)))
          (while (let [d (peek-ch p)] (and d (Character/isDigit ^char d)))
            (bump! p))))
      (let [text (.substring ^String (:text @p) start (:i @p))]
        (if @float?
          (let [n (Double/parseDouble text)
                i (Math/round n)]
            (if (= n (double i)) i n))
          (Long/parseLong text))))))

(defn- parse-array [p]
  (bump! p)
  (skipws! p)
  (if (= (peek-ch p) \])
    (do (bump! p) [])
    (loop [acc []]
      (let [acc (conj acc (parse-value p))]
        (skipws! p)
        (let [c (bump! p)]
          (cond
            (= c \]) acc
            (= c \,) (do (skipws! p) (recur acc))
            :else (throw (ex-info "expected comma or ]" {}))))))))

(defn- parse-object [p]
  (bump! p)
  (skipws! p)
  (if (= (peek-ch p) \})
    (do (bump! p) {})
    (loop [acc {}]
      (skipws! p)
      (let [k (parse-string p)]
        (skipws! p)
        (when-not (= (bump! p) \:)
          (throw (ex-info "expected colon" {})))
        (skipws! p)
        (let [acc (assoc acc k (parse-value p))]
          (skipws! p)
          (let [c (bump! p)]
            (cond
              (= c \}) acc
              (= c \,) (do (skipws! p) (recur acc))
              :else (throw (ex-info "expected comma or }" {})))))))))

(defn- parse-value [p]
  (skipws! p)
  (let [c (peek-ch p)]
    (cond
      (nil? c) (throw (ex-info "unexpected end" {}))
      (starts-with? p "null") (do (advance! p 4) nil)
      (starts-with? p "true") (do (advance! p 4) true)
      (starts-with? p "false") (do (advance! p 5) false)
      (= c \") (parse-string p)
      (= c \[) (parse-array p)
      (= c \{) (parse-object p)
      (or (= c \-) (and c (Character/isDigit ^char c))) (parse-number p)
      :else (throw (ex-info (str "unexpected json char " c) {})))))

(defn json-decode [text]
  (let [p (make-parser text)
        val (parse-value p)]
    (skipws! p)
    (when (peek-ch p)
      (throw (ex-info "trailing json" {})))
    val))
(defn- write-json-string [^String s ^StringBuilder out]
  (.append out \")
  (doseq [c s]
    (case c
      \" (.append out "\\\"")
      \\ (.append out "\\\\")
      \backspace (.append out "\\b")
      \formfeed (.append out "\\f")
      \newline (.append out "\\n")
      \return (.append out "\\r")
      \tab (.append out "\\t")
      (if (< (int c) 32)
        (.append out (format "\\u%04x" (int c)))
        (.append out c))))
  (.append out \"))

(defn- write-json [val ^StringBuilder out]
  (cond
    (false? val) (.append out "false")
    (true? val) (.append out "true")
    (nil? val) (.append out "null")
    (integer? val) (.append out (str val))
    (float? val)
    (let [i (Math/round (double val))]
      (if (= (double val) (double i))
        (.append out (str i))
        (.append out (str val))))
    (string? val) (write-json-string val out)
    (map? val)
    (do
      (.append out \{)
      (doseq [[i [k v]] (map-indexed vector val)]
        (when (pos? i)
          (.append out \,))
        (write-json (if (string? k) k (str k)) out)
        (.append out \:)
        (write-json v out))
      (.append out \}))
    (or (sequential? val) (vector? val))
    (do
      (.append out \[)
      (doseq [[i item] (map-indexed vector val)]
        (when (pos? i)
          (.append out \,))
        (write-json item out))
      (.append out \]))
    :else (throw (ex-info (str "cannot encode " (pr-str val)) {}))))

(defn json-encode [val]
  (let [out (StringBuilder.)]
    (write-json val out)
    (str out)))

(defn- coerce [val]
  (cond
    (float? val)
    (let [i (Math/round (double val))]
      (if (= (double val) (double i)) i val))
    (vector? val) (mapv coerce val)
    (sequential? val) (mapv coerce val)
    :else val))

(defn- fail-row [case-id index method expected actual]
  {"case" case-id
   "index" index
   "method" method
   "expected" expected
   "actual" actual})

(defn- load-solution [src]
  (let [n (create-ns 'honepad.user)]
    (binding [*ns* n]
      (clojure.core/refer-clojure)
      (load-file src))
    n))

(defn- new-target [user-ns class-name]
  (let [sym (symbol class-name)
        v (ns-resolve user-ns sym)]
    (when-not v
      (throw (ex-info (str "missing " class-name) {})))
    (v)))

(defn- invoke-method [user-ns obj method args]
  (let [v (ns-resolve user-ns (symbol method))]
    (when-not v
      (throw (ex-info "missing" {})))
    (apply v obj args)))

(defn- exc-name [err]
  (.getSimpleName (class err)))

(defn- call-result [user-ns obj case-id i call]
  (let [method (str (get call "m"))
        args (mapv coerce (or (get call "a") []))
        expected (coerce (get call "e"))]
    (try
      (let [actual (invoke-method user-ns obj method args)]
        (if (not= (json-encode actual) (json-encode expected))
          [:fail (fail-row case-id i method expected actual)]
          :ok))
      (catch Throwable err
        [:fail (fail-row case-id i method expected
                         (str "exc:" (exc-name err)))]))))

(defn- replay [user-ns class-name cases]
  (loop [rows cases
         passed 0
         failed []]
    (if (empty? rows)
      [passed failed]
      (let [row (first rows)
            obj (new-target user-ns class-name)
            case-id (str (get row "id"))
            calls (or (get row "calls") [])
            outcome
            (reduce (fn [acc [i call]]
                      (let [result (call-result user-ns obj case-id i call)]
                        (if (= result :ok)
                          acc
                          (reduced (conj acc (second result))))))
                    failed
                    (map-indexed vector calls))]
        (if (identical? outcome failed)
          (recur (rest rows) (inc passed) failed)
          (recur (rest rows) passed outcome))))))

(defn -main [& args]
  (when (not= (count args) 3)
    (binding [*out* *err*]
      (println "usage: clojure -M adapter.clj <src> <class> <cases.json>"))
    (System/exit 2))
  (let [[src class-name cases-path] args]
    (try
      (let [user-ns (load-solution src)]
        (when-not (ns-resolve user-ns (symbol class-name))
          (binding [*out* *err*]
            (println "missing class" class-name))
          (System/exit 2))
        (let [cases (json-decode (slurp cases-path))]
          (when-not (sequential? cases)
            (throw (ex-info "cases must be a json array" {})))
          (let [[passed failed] (replay user-ns class-name cases)
                payload {"passed" passed "failed" failed}]
            (println (json-encode payload))
            (System/exit (if (empty? failed) 0 1)))))
      (catch Throwable err
        (binding [*out* *err*]
          (println (.getMessage err)))
        (println (json-encode
                  {"passed" 0
                   "failed" [(fail-row "load" 0 "load" nil
                                       (str "exc:" (exc-name err)))]}))
        (System/exit 2)))))

(apply -main *command-line-args*)
