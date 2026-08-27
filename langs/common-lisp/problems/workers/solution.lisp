(in-package :honepad-user)

(defclass worker ()
  ((worker-id :initarg :worker-id :accessor worker-id)
   (position :initarg :position :accessor worker-position)
   (compensation :initarg :compensation :accessor worker-compensation)
   (in-office :initform nil :accessor worker-in-office)
   (entered-at :initform nil :accessor worker-entered-at)
   (finished :initform nil :accessor worker-finished)
   (pending-promo :initform nil :accessor worker-pending-promo)))

(defun make-worker (worker-id position compensation)
  (make-instance 'worker
                 :worker-id worker-id
                 :position position
                 :compensation compensation))

(defun total-time (worker)
  (loop for session in (worker-finished worker)
        sum (- (second session) (first session))))

(defun position-time (worker position)
  (loop for session in (worker-finished worker)
        when (string= (fourth session) position)
          sum (- (second session) (first session))))

(defun apply-promo-on-enter (worker timestamp)
  (let ((promo (worker-pending-promo worker)))
    (when (and promo (>= timestamp (third promo)))
      (setf (worker-position worker) (first promo))
      (setf (worker-compensation worker) (second promo))
      (setf (worker-pending-promo worker) nil))))

(defclass simulation ()
  ((workers :initform (make-hash-table :test 'equal) :accessor sim-workers)))

(defmethod add_worker ((sim simulation) worker_id position compensation)
  (when (gethash worker_id (sim-workers sim))
    (return-from add_worker "false"))
  (setf (gethash worker_id (sim-workers sim))
        (make-worker worker_id position compensation))
  "true")

(defmethod register ((sim simulation) worker_id timestamp)
  (let ((worker (gethash worker_id (sim-workers sim))))
    (unless worker
      (return-from register "invalid_request"))
    (if (worker-in-office worker)
        (progn
          (setf (worker-finished worker)
                (append (worker-finished worker)
                        (list (list (worker-entered-at worker)
                                    timestamp
                                    (worker-compensation worker)
                                    (worker-position worker)))))
          (setf (worker-in-office worker) nil)
          (setf (worker-entered-at worker) nil)
          "registered")
        (progn
          (apply-promo-on-enter worker timestamp)
          (setf (worker-in-office worker) t)
          (setf (worker-entered-at worker) timestamp)
          "registered"))))

(defmethod get ((sim simulation) worker_id)
  (let ((worker (gethash worker_id (sim-workers sim))))
    (if worker (princ-to-string (total-time worker)) "")))

(defmethod top_n_workers ((sim simulation) n position)
  (let ((matched nil))
    (maphash (lambda (id worker)
               (declare (ignore id))
               (when (string= (worker-position worker) position)
                 (push worker matched)))
             (sim-workers sim))
    (setf matched
          (sort matched
                (lambda (a b)
                  (let ((ta (position-time a position))
                        (tb (position-time b position)))
                    (cond
                      ((> ta tb) t)
                      ((< ta tb) nil)
                      (t (string< (worker-id a) (worker-id b))))))))
    (let ((count (min n (length matched))))
      (with-output-to-string (out)
        (loop for worker in matched
              for i from 0 below count
              do (when (> i 0) (write-string ", " out))
                 (format out "~a(~a)" (worker-id worker)
                         (position-time worker position)))))))

(defmethod promote ((sim simulation) worker_id new_position new_compensation
                    start_timestamp)
  (let ((worker (gethash worker_id (sim-workers sim))))
    (when (or (null worker) (worker-pending-promo worker))
      (return-from promote "invalid_request"))
    (setf (worker-pending-promo worker)
          (list new_position new_compensation start_timestamp))
    "success"))

(defmethod calc_salary ((sim simulation) worker_id start_timestamp end_timestamp)
  (let ((worker (gethash worker_id (sim-workers sim))))
    (unless worker
      (return-from calc_salary ""))
    (let ((total 0))
      (dolist (session (worker-finished worker))
        (let ((lo (max (first session) start_timestamp))
              (hi (min (second session) end_timestamp))
              (rate (third session)))
          (when (> hi lo)
            (incf total (* (- hi lo) rate)))))
      (princ-to-string total))))
