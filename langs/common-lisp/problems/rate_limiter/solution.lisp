(in-package :honepad-user)

(defclass key-state ()
  ((limit :initform 3 :accessor key-limit)
   (window :initform 10 :accessor key-window)
   (window-id :initform nil :accessor key-window-id)
   (used :initform 0 :accessor key-used)))

(defclass simulation ()
  ((keys :initform (make-hash-table :test 'equal) :accessor sim-keys)))

(defun state (sim key)
  (or (gethash key (sim-keys sim))
      (setf (gethash key (sim-keys sim)) (make-instance 'key-state))))

(defun used-at (item timestamp persist)
  (let ((window-id (floor timestamp (key-window item))))
    (if (or (null (key-window-id item))
            (/= window-id (key-window-id item)))
        (progn
          (when persist
            (setf (key-window-id item) window-id)
            (setf (key-used item) 0))
          0)
        (key-used item))))

(defmethod allow ((sim simulation) key timestamp)
  (allow_weighted sim key 1 timestamp))

(defmethod configure ((sim simulation) key limit window)
  (when (or (<= limit 0) (<= window 0))
    (return-from configure "invalid_request"))
  (let ((item (state sim key)))
    (setf (key-limit item) limit)
    (setf (key-window item) window)
    (setf (key-window-id item) nil)
    (setf (key-used item) 0)
    "true"))

(defmethod remaining ((sim simulation) key timestamp)
  (let* ((item (state sim key))
         (used (used-at item timestamp nil)))
    (princ-to-string (- (key-limit item) used))))

(defmethod allow_weighted ((sim simulation) key cost timestamp)
  (when (<= cost 0)
    (return-from allow_weighted "invalid_request"))
  (let ((item (state sim key)))
    (used-at item timestamp t)
    (when (> (+ (key-used item) cost) (key-limit item))
      (return-from allow_weighted "false"))
    (incf (key-used item) cost)
    "true"))
