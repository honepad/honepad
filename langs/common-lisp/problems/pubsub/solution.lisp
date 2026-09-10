(in-package :honepad-user)

(defclass simulation ()
  ((subs :initform (make-hash-table :test 'equal) :accessor sim-subs)
   (inbox-map :initform (make-hash-table :test 'equal) :accessor sim-inbox)
   (retained :initform (make-hash-table :test 'equal) :accessor sim-retained)))

(defun join-comma (items)
  (with-output-to-string (out)
    (loop for item in items
          for i from 0
          do (when (> i 0) (write-string ", " out))
             (write-string item out))))

(defmethod subscribe ((sim simulation) topic client)
  (let ((clients (gethash topic (sim-subs sim))))
    (when (member client clients :test #'string=)
      (return-from subscribe "false"))
    (setf (gethash topic (sim-subs sim)) (append clients (list client)))
    (let ((kept (gethash topic (sim-retained sim))))
      (when kept
        (setf (gethash client (sim-inbox sim))
              (append (gethash client (sim-inbox sim))
                      (list (format nil "~a:~a" topic kept))))))
    "true"))

(defmethod unsubscribe ((sim simulation) topic client)
  (let ((clients (gethash topic (sim-subs sim))))
    (unless (member client clients :test #'string=)
      (return-from unsubscribe "false"))
    (let ((kept (remove client clients :test #'string=)))
      (if kept
          (setf (gethash topic (sim-subs sim)) kept)
          (remhash topic (sim-subs sim))))
    "true"))

(defmethod publish ((sim simulation) topic message)
  (let ((clients (gethash topic (sim-subs sim)))
        (payload (format nil "~a:~a" topic message)))
    (dolist (client clients)
      (setf (gethash client (sim-inbox sim))
            (append (gethash client (sim-inbox sim)) (list payload))))
    (princ-to-string (length clients))))

(defmethod inbox ((sim simulation) client)
  (join-comma (gethash client (sim-inbox sim))))

(defmethod list_topics ((sim simulation))
  (let ((topics nil))
    (maphash (lambda (topic clients)
               (declare (ignore clients))
               (push topic topics))
             (sim-subs sim))
    (join-comma (sort topics #'string<))))

(defmethod subscribers ((sim simulation) topic)
  (join-comma (sort (copy-list (gethash topic (sim-subs sim))) #'string<)))

(defmethod peek ((sim simulation) client)
  (let ((items (gethash client (sim-inbox sim))))
    (if items (first items) "")))

(defmethod ack ((sim simulation) client n)
  (multiple-value-bind (items present) (gethash client (sim-inbox sim))
    (when (or (<= n 0) (not present))
      (return-from ack "invalid_request"))
    (when (> n (length items))
      (return-from ack "invalid_request"))
    (setf (gethash client (sim-inbox sim)) (nthcdr n items))
    (princ-to-string (length (gethash client (sim-inbox sim))))))

(defmethod retain ((sim simulation) topic message)
  (setf (gethash topic (sim-retained sim)) message)
  "")
