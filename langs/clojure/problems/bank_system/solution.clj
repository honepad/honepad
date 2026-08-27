(def ^:private cashback-delay (* 24 60 60 1000))

(defn- make-account [account-id created-at]
  {:account-id account-id
   :balance 0
   :outgoing 0
   :payments {}
   :created-at created-at
   :balance-history [[created-at 0]]})

(defn- record-balance [account timestamp]
  (update account :balance-history conj [timestamp (:balance account)]))

(defn- deposit-account [account amount]
  (update account :balance + amount))

(defn- withdraw-account [account amount]
  (if (< (:balance account) amount)
    nil
    (-> account
        (update :balance - amount)
        (update :outgoing + amount))))

(defn- get-balance-at [account time-at]
  (when-not (< time-at (:created-at account))
    (reduce (fn [result [ts bal]]
              (if (<= ts time-at) bal (reduced result)))
            nil
            (:balance-history account))))

(defn Simulation []
  (atom {:accounts {}
         :payment-counter 0
         :pending []}))

(defn- process-cashbacks [sim timestamp]
  (loop []
    (let [pending (:pending @sim)
          row (first pending)]
      (when (and row (<= (nth row 0) timestamp))
        (let [[cb-ts account-id amount payment-id] row]
          (swap! sim update :pending #(vec (rest %)))
          (when-let [account (get-in @sim [:accounts account-id])]
            (let [account (-> account
                              (deposit-account amount)
                              (assoc-in [:payments payment-id] "CASHBACK_RECEIVED")
                              (record-balance cb-ts))]
              (swap! sim assoc-in [:accounts account-id] account))))
        (recur)))))

(defn create_account [sim timestamp account_id]
  (process-cashbacks sim timestamp)
  (if (get-in @sim [:accounts account_id])
    false
    (do
      (swap! sim assoc-in [:accounts account_id] (make-account account_id timestamp))
      true)))

(defn deposit [sim timestamp account_id amount]
  (process-cashbacks sim timestamp)
  (when-let [account (get-in @sim [:accounts account_id])]
    (let [account (-> account (deposit-account amount) (record-balance timestamp))]
      (swap! sim assoc-in [:accounts account_id] account)
      (:balance account))))

(defn transfer [sim timestamp source_account_id target_account_id amount]
  (process-cashbacks sim timestamp)
  (let [source (get-in @sim [:accounts source_account_id])
        target (get-in @sim [:accounts target_account_id])]
    (when (and source target (not= source_account_id target_account_id))
      (when-let [source (withdraw-account source amount)]
        (let [target (deposit-account target amount)
              source (record-balance source timestamp)
              target (record-balance target timestamp)]
          (swap! sim assoc-in [:accounts source_account_id] source)
          (swap! sim assoc-in [:accounts target_account_id] target)
          (:balance source))))))

(defn top_spenders [sim timestamp n]
  (process-cashbacks sim timestamp)
  (let [ids (sort (fn [a b]
                    (let [oa (:outgoing (get-in @sim [:accounts a]))
                          ob (:outgoing (get-in @sim [:accounts b]))]
                      (if (not= oa ob)
                        (compare ob oa)
                        (compare a b))))
                  (keys (:accounts @sim)))]
    (mapv (fn [id]
            (str id "(" (:outgoing (get-in @sim [:accounts id])) ")"))
          (take n ids))))

(defn pay [sim timestamp account_id amount]
  (process-cashbacks sim timestamp)
  (when-let [account (get-in @sim [:accounts account_id])]
    (when-let [account (withdraw-account account amount)]
      (let [counter (inc (:payment-counter @sim))
            payment-id (str "payment" counter)
            cashback (quot (* amount 2) 100)
            account (-> account
                        (assoc-in [:payments payment-id] "IN_PROGRESS")
                        (record-balance timestamp))]
        (swap! sim assoc :payment-counter counter)
        (swap! sim assoc-in [:accounts account_id] account)
        (swap! sim update :pending conj
               [(+ timestamp cashback-delay) account_id cashback payment-id])
        payment-id))))

(defn get_payment_status [sim timestamp account_id payment]
  (process-cashbacks sim timestamp)
  (when-let [account (get-in @sim [:accounts account_id])]
    (get (:payments account) payment)))

(defn merge_accounts [sim timestamp account_id_1 account_id_2]
  (process-cashbacks sim timestamp)
  (if (= account_id_1 account_id_2)
    false
    (let [account1 (get-in @sim [:accounts account_id_1])
          account2 (get-in @sim [:accounts account_id_2])]
      (if (or (nil? account1) (nil? account2))
        false
        (let [account1 (-> account1
                           (update :balance + (:balance account2))
                           (update :outgoing + (:outgoing account2))
                           (update :payments merge (:payments account2))
                           (update :balance-history
                                   (fn [h]
                                     (vec (sort-by first (concat h (:balance-history account2))))))
                           (assoc :created-at (min (:created-at account1)
                                                   (:created-at account2)))
                           (record-balance timestamp))]
          (swap! sim assoc-in [:accounts account_id_1] account1)
          (swap! sim update :pending
                 (fn [pending]
                   (mapv (fn [row]
                           (if (= (nth row 1) account_id_2)
                             (assoc row 1 account_id_1)
                             row))
                         pending)))
          (swap! sim update :accounts dissoc account_id_2)
          true)))))

(defn get_balance [sim timestamp account_id time_at]
  (process-cashbacks sim timestamp)
  (when-let [account (get-in @sim [:accounts account_id])]
    (get-balance-at account time_at)))
