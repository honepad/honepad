(in-package :honepad-user)

(defclass item ()
  ((sku :initarg :sku :accessor item-sku)
   (name :initarg :name :accessor item-name)
   (qty :initform 0 :accessor item-qty)
   (reserved :initform 0 :accessor item-reserved)))

(defun make-item (sku name)
  (make-instance 'item :sku sku :name name))

(defclass simulation ()
  ((items :initform (make-hash-table :test 'equal) :accessor sim-items)))

(defmethod create_item ((sim simulation) sku name)
  (when (gethash sku (sim-items sim))
    (return-from create_item "false"))
  (setf (gethash sku (sim-items sim)) (make-item sku name))
  "true")

(defmethod stock ((sim simulation) sku delta)
  (let ((item (gethash sku (sim-items sim))))
    (unless item
      (return-from stock ""))
    (let ((nxt (+ (item-qty item) delta)))
      (when (< nxt (item-reserved item))
        (return-from stock "invalid_request"))
      (setf (item-qty item) nxt)
      (princ-to-string (item-qty item)))))

(defmethod get_qty ((sim simulation) sku)
  (let ((item (gethash sku (sim-items sim))))
    (if item (princ-to-string (item-qty item)) "")))

(defmethod list_low ((sim simulation) threshold)
  (let ((matched nil))
    (maphash (lambda (id item)
               (declare (ignore id))
               (when (<= (item-qty item) threshold)
                 (push item matched)))
             (sim-items sim))
    (setf matched
          (sort matched
                (lambda (a b)
                  (let ((qa (item-qty a))
                        (qb (item-qty b)))
                    (cond
                      ((< qa qb) t)
                      ((> qa qb) nil)
                      (t (string< (item-sku a) (item-sku b))))))))
    (with-output-to-string (out)
      (loop for item in matched
            for i from 0
            do (when (> i 0) (write-string ", " out))
               (format out "~a(~a)" (item-sku item) (item-qty item))))))

(defmethod reserve ((sim simulation) sku n)
  (let ((item (gethash sku (sim-items sim))))
    (when (or (null item) (<= n 0) (> (+ (item-reserved item) n) (item-qty item)))
      (return-from reserve "invalid_request"))
    (incf (item-reserved item) n)
    "true"))

(defmethod release ((sim simulation) sku n)
  (let ((item (gethash sku (sim-items sim))))
    (when (or (null item) (<= n 0) (> n (item-reserved item)))
      (return-from release "invalid_request"))
    (decf (item-reserved item) n)
    "true"))

(defmethod ship ((sim simulation) sku n)
  (let ((item (gethash sku (sim-items sim))))
    (when (or (null item) (<= n 0) (> n (item-reserved item)))
      (return-from ship "invalid_request"))
    (decf (item-reserved item) n)
    (decf (item-qty item) n)
    "true"))
