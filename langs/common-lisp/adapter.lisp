;; argv: sbcl --script adapter.lisp <src> <class> <cases.json>
;; Load the solution, instantiate Simulation or InMemoryDatabase,
;; call snake_case methods, compare JSON encodings.
;; Bank booleans are JSON true/false (:false is JSON false; nil is null).

(defpackage :honepad-user
  (:use :cl)
  (:shadow #:set #:get #:delete))

(defpackage :honepad-adapter
  (:use :cl))

(in-package :honepad-adapter)

(defstruct parser
  text
  (i 0)
  (n 0))

(defun peek (p)
  (if (>= (parser-i p) (parser-n p))
      nil
      (char (parser-text p) (parser-i p))))

(defun bump (p)
  (let ((c (peek p)))
    (when c
      (incf (parser-i p)))
    c))

(defun skipws (p)
  (loop for c = (peek p)
        while (and c (member c '(#\Space #\Tab #\Newline #\Return)))
        do (bump p)))

(defun parse-string (p)
  (unless (eql (bump p) #\")
    (error "expected string"))
  (with-output-to-string (out)
    (loop
      (let ((c (bump p)))
        (cond
          ((null c) (error "unterminated string"))
          ((eql c #\") (return))
          ((eql c #\\)
           (let ((e (bump p)))
             (cond
               ((member e '(#\" #\\ #\/)) (write-char e out))
               ((eql e #\b) (write-char #\Backspace out))
               ((eql e #\f) (write-char #\Page out))
               ((eql e #\n) (write-char #\Newline out))
               ((eql e #\r) (write-char #\Return out))
               ((eql e #\t) (write-char #\Tab out))
               ((eql e #\u)
                (let ((hex (make-string 4)))
                  (dotimes (k 4)
                    (setf (char hex k)
                          (or (bump p) (error "bad unicode escape"))))
                  (write-char (code-char (parse-integer hex :radix 16)) out)))
               (t (error "bad escape")))))
          (t (write-char c out)))))))

(defun digit-char-p* (c)
  (and c (char<= #\0 c #\9)))

(defun parse-number (p)
  (let ((start (parser-i p)))
    (when (eql (peek p) #\-)
      (bump p))
    (loop while (digit-char-p* (peek p)) do (bump p))
    (let ((floatp nil))
      (when (eql (peek p) #\.)
        (setf floatp t)
        (bump p)
        (loop while (digit-char-p* (peek p)) do (bump p)))
      (let ((c (peek p)))
        (when (member c '(#\e #\E))
          (setf floatp t)
          (bump p)
          (when (member (peek p) '(#\+ #\-))
            (bump p))
          (loop while (digit-char-p* (peek p)) do (bump p))))
      (let ((text (subseq (parser-text p) start (parser-i p))))
        (if floatp
            (let* ((n (read-from-string text))
                   (i (round n)))
              (if (= n i) i n))
            (parse-integer text))))))

(defun parse-array (p)
  (bump p)
  (skipws p)
  (if (eql (peek p) #\])
      (progn (bump p) #())
      (let ((acc (make-array 0 :adjustable t :fill-pointer 0)))
        (loop
          (vector-push-extend (parse-value p) acc)
          (skipws p)
          (let ((c (bump p)))
            (cond
              ((eql c #\]) (return acc))
              ((eql c #\,) (skipws p))
              (t (error "expected comma or ]"))))))))

(defun parse-object (p)
  (bump p)
  (skipws p)
  (let ((acc (make-hash-table :test 'equal)))
    (if (eql (peek p) #\})
        (progn (bump p) acc)
        (loop
          (skipws p)
          (let ((key (parse-string p)))
            (skipws p)
            (unless (eql (bump p) #\:)
              (error "expected colon"))
            (skipws p)
            (setf (gethash key acc) (parse-value p))
            (skipws p)
            (let ((c (bump p)))
              (cond
                ((eql c #\}) (return acc))
                ((eql c #\,) (skipws p))
                (t (error "expected comma or }")))))))))

(defun starts-with-p (p token)
  (let ((i (parser-i p))
        (n (parser-n p))
        (text (parser-text p)))
    (and (<= (+ i (length token)) n)
         (string= text token :start1 i :end1 (+ i (length token))))))

(defun parse-value (p)
  (skipws p)
  (let ((c (peek p)))
    (cond
      ((null c) (error "unexpected end"))
      ((starts-with-p p "null")
       (incf (parser-i p) 4)
       nil)
      ((starts-with-p p "true")
       (incf (parser-i p) 4)
       t)
      ((starts-with-p p "false")
       (incf (parser-i p) 5)
       :false)
      ((eql c #\") (parse-string p))
      ((eql c #\[) (parse-array p))
      ((eql c #\{) (parse-object p))
      ((or (eql c #\-) (digit-char-p* c)) (parse-number p))
      (t (error "unexpected json char ~s" c)))))

(defun json-decode (text)
  (let ((p (make-parser :text text :i 0 :n (length text))))
    (prog1 (parse-value p)
      (skipws p)
      (unless (>= (parser-i p) (parser-n p))
        (error "trailing json")))))

(defun write-json-string (s out)
  (write-char #\" out)
  (loop for c across s do
    (case c
      (#\" (write-string "\\\"" out))
      (#\\ (write-string "\\\\" out))
      (#\Backspace (write-string "\\b" out))
      (#\Page (write-string "\\f" out))
      (#\Newline (write-string "\\n" out))
      (#\Return (write-string "\\r" out))
      (#\Tab (write-string "\\t" out))
      (otherwise
       (if (< (char-code c) 32)
           (format out "\\u~4,'0x" (char-code c))
           (write-char c out)))))
  (write-char #\" out))

(defun write-json (val out)
  (cond
    ((eq val :false) (write-string "false" out))
    ((eq val t) (write-string "true" out))
    ((null val) (write-string "null" out))
    ((integerp val) (princ val out))
    ((floatp val)
     (let ((i (round val)))
       (if (= val i)
           (princ i out)
           (princ val out))))
    ((stringp val) (write-json-string val out))
    ((hash-table-p val)
     (write-char #\{ out)
     (let ((first t))
       (maphash
        (lambda (k v)
          (unless first (write-char #\, out))
          (setf first nil)
          (write-json (if (stringp k) k (princ-to-string k)) out)
          (write-char #\: out)
          (write-json v out))
        val))
     (write-char #\} out))
    ((vectorp val)
     (write-char #\[ out)
     (loop for i from 0 below (length val) do
       (when (> i 0) (write-char #\, out))
       (write-json (aref val i) out))
     (write-char #\] out))
    ((consp val)
     (write-char #\[ out)
     (loop for rest on val
           for i from 0
           do (when (> i 0) (write-char #\, out))
              (write-json (car rest) out)
           unless (listp (cdr rest))
             do (error "cannot encode dotted list"))
     (write-char #\] out))
    (t (error "cannot encode ~s" val))))

(defun json-encode (val)
  (with-output-to-string (out)
    (write-json val out)))

(defun hash-ref (table key &optional default)
  (gethash key table default))

(defun coerce-arg (val)
  (cond
    ((floatp val)
     (let ((i (round val)))
       (if (= val i) i val)))
    ((and (vectorp val) (not (stringp val)))
     (map 'vector #'coerce-arg val))
    ((consp val) (mapcar #'coerce-arg val))
    (t val)))

(defun fail-row (case-id index method expected actual)
  (let ((row (make-hash-table :test 'equal)))
    (setf (gethash "case" row) case-id)
    (setf (gethash "index" row) index)
    (setf (gethash "method" row) method)
    (setf (gethash "expected" row) expected)
    (setf (gethash "actual" row) actual)
    row))

(defun class-symbol (name)
  (intern (string-upcase name) :honepad-user))

(defun method-symbol (name)
  (intern (string-upcase name) :honepad-user))

(defun new-target (class-name)
  (let ((sym (class-symbol class-name)))
    (unless (find-class sym nil)
      (error "missing class ~a" class-name))
    (make-instance sym)))

(defun invoke-method (obj method args)
  (let ((sym (method-symbol method)))
    (unless (fboundp sym)
      (error "missing"))
    (apply sym obj (coerce (map 'list #'identity args) 'list))))

(defun exc-name (err)
  (string-downcase (symbol-name (type-of err))))

(defun replay (class-name cases)
  (let ((failed (make-array 0 :adjustable t :fill-pointer 0))
        (passed 0))
    (loop for row across cases do
      (let* ((obj (new-target class-name))
             (case-id (princ-to-string (hash-ref row "id")))
             (calls (or (hash-ref row "calls") #()))
             (ok t))
        (loop for i from 0 below (length calls)
              for call = (aref calls i)
              for method = (princ-to-string (hash-ref call "m"))
              for args = (map 'vector #'coerce-arg (or (hash-ref call "a") #()))
              for expected = (coerce-arg (hash-ref call "e"))
              do (handler-case
                     (let ((actual (invoke-method obj method args)))
                       (unless (string= (json-encode actual) (json-encode expected))
                         (vector-push-extend
                          (fail-row case-id i method expected actual)
                          failed)
                         (setf ok nil)))
                   (error (err)
                     (vector-push-extend
                      (fail-row case-id i method expected
                                (format nil "exc:~a" (exc-name err)))
                      failed)
                     (setf ok nil)))
              while ok)
        (when ok
          (incf passed))))
    (values passed failed)))

(defun script-args ()
  (cdr sb-ext:*posix-argv*))

(defun main ()
  (let ((argv (script-args)))
    (unless (= (length argv) 3)
      (format *error-output* "usage: sbcl --script adapter.lisp <src> <class> <cases.json>~%")
      (sb-ext:exit :code 2))
    (destructuring-bind (src class-name cases-path) argv
      (let ((report-out *standard-output*))
        (let ((*standard-output* (make-broadcast-stream)))
          (let ((*package* (find-package :honepad-user)))
            (load src :verbose nil :print nil))
          (unless (find-class (class-symbol class-name) nil)
            (format *error-output* "missing class ~a~%" class-name)
            (sb-ext:exit :code 2))
          (let ((cases (json-decode (with-open-file (in cases-path)
                                      (let ((s (make-string (file-length in))))
                                        (read-sequence s in)
                                        s)))))
            (unless (vectorp cases)
              (error "cases must be a json array"))
            (multiple-value-bind (passed failed) (replay class-name cases)
              (let ((payload (make-hash-table :test 'equal)))
                (setf (gethash "passed" payload) passed)
                (setf (gethash "failed" payload) failed)
                (write-line (json-encode payload) report-out))
              (sb-ext:exit :code (if (zerop (length failed)) 0 1)))))))))

(handler-case
    (main)
  (error (err)
    (format *error-output* "~a~%" err)
    (let ((payload (make-hash-table :test 'equal))
          (failed (make-array 0 :adjustable t :fill-pointer 0)))
      (vector-push-extend
       (fail-row "load" 0 "load" nil (format nil "exc:~a" (exc-name err)))
       failed)
      (setf (gethash "passed" payload) 0)
      (setf (gethash "failed" payload) failed)
      (write-line (json-encode payload)))
    (sb-ext:exit :code 2)))
