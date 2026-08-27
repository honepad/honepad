(in-package :honepad-user)

(defclass inmemorydatabase ()
  ((database :initform (make-hash-table :test 'equal) :accessor db-data)
   (backup-timestamps :initform nil :accessor db-backup-ts)
   (backup-states :initform nil :accessor db-backup-states)))

(defun set-internal (db key field value expiry)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (setf fields (make-hash-table :test 'equal))
      (setf (gethash key (db-data db)) fields))
    (setf (gethash field fields) (cons value expiry))
    ""))

(defun is-alive (db key field timestamp)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from is-alive nil))
    (multiple-value-bind (row present) (gethash field fields)
      (unless present
        (return-from is-alive nil))
      (let ((expiry (cdr row)))
        (or (null expiry) (< timestamp expiry))))))

(defun join-scan (items)
  (with-output-to-string (out)
    (loop for pair in items
          for i from 0
          do (when (> i 0) (write-string ", " out))
             (format out "~a(~a)" (car pair) (cdr pair)))))

(defun sorted-fields (fields)
  (let ((keys nil))
    (maphash (lambda (k v)
               (declare (ignore v))
               (push k keys))
             fields)
    (sort keys #'string<)))

(defun bisect-right (list x)
  (let ((i 0))
    (dolist (v list i)
      (if (<= v x)
          (incf i)
          (return i)))))

(defmethod set ((db inmemorydatabase) key field value)
  (set-internal db key field value nil))

(defmethod get ((db inmemorydatabase) key field)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from get ""))
    (multiple-value-bind (row present) (gethash field fields)
      (if present (car row) ""))))

(defmethod delete ((db inmemorydatabase) key field)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from delete "false"))
    (multiple-value-bind (row present) (gethash field fields)
      (declare (ignore row))
      (unless present
        (return-from delete "false"))
      (remhash field fields)
      "true")))

(defmethod scan ((db inmemorydatabase) key)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from scan ""))
    (join-scan
     (loop for field in (sorted-fields fields)
           for row = (gethash field fields)
           collect (cons field (car row))))))

(defmethod scan_by_prefix ((db inmemorydatabase) key prefix)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from scan_by_prefix ""))
    (join-scan
     (loop for field in (sorted-fields fields)
           for row = (gethash field fields)
           when (and (>= (length field) (length prefix))
                     (string= field prefix :end1 (length prefix)))
             collect (cons field (car row))))))

(defmethod set_at ((db inmemorydatabase) key field value timestamp)
  (declare (ignore timestamp))
  (set-internal db key field value nil))

(defmethod set_at_with_ttl ((db inmemorydatabase) key field value timestamp ttl)
  (set-internal db key field value (+ timestamp ttl)))

(defmethod delete_at ((db inmemorydatabase) key field timestamp)
  (unless (is-alive db key field timestamp)
    (return-from delete_at "false"))
  (remhash field (gethash key (db-data db)))
  "true")

(defmethod get_at ((db inmemorydatabase) key field timestamp)
  (unless (is-alive db key field timestamp)
    (return-from get_at ""))
  (car (gethash field (gethash key (db-data db)))))

(defmethod scan_at ((db inmemorydatabase) key timestamp)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from scan_at ""))
    (join-scan
     (loop for field in (sorted-fields fields)
           for row = (gethash field fields)
           when (is-alive db key field timestamp)
             collect (cons field (car row))))))

(defmethod scan_by_prefix_at ((db inmemorydatabase) key prefix timestamp)
  (let ((fields (gethash key (db-data db))))
    (unless fields
      (return-from scan_by_prefix_at ""))
    (join-scan
     (loop for field in (sorted-fields fields)
           for row = (gethash field fields)
           when (and (>= (length field) (length prefix))
                     (string= field prefix :end1 (length prefix))
                     (is-alive db key field timestamp))
             collect (cons field (car row))))))

(defmethod backup ((db inmemorydatabase) timestamp)
  (let ((state (make-hash-table :test 'equal)))
    (maphash
     (lambda (key fields)
       (maphash
        (lambda (field row)
          (when (is-alive db key field timestamp)
            (let ((bucket (gethash key state))
                  (remaining (if (cdr row) (- (cdr row) timestamp) nil)))
              (unless bucket
                (setf bucket (make-hash-table :test 'equal))
                (setf (gethash key state) bucket))
              (setf (gethash field bucket) (cons (car row) remaining)))))
        fields))
     (db-data db))
    (setf (db-backup-ts db) (append (db-backup-ts db) (list timestamp)))
    (setf (db-backup-states db) (append (db-backup-states db) (list state)))
    (princ-to-string (hash-table-count state))))

(defmethod restore ((db inmemorydatabase) timestamp timestamp_to_restore)
  (let* ((idx (1- (bisect-right (db-backup-ts db) timestamp_to_restore)))
         (backup-state (nth idx (db-backup-states db))))
    (setf (db-data db) (make-hash-table :test 'equal))
    (maphash
     (lambda (key fields)
       (maphash
        (lambda (field row)
          (let ((expiry (if (cdr row) (+ timestamp (cdr row)) nil)))
            (set-internal db key field (car row) expiry)))
        fields))
     backup-state)
    ""))
