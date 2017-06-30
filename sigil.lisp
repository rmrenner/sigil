(require :parenscript)

(defparameter *include-paths* ())
(defparameter *verbose* nil)

;; add 'load' to parenscript compiler
(ps:defpsmacro load (file)
  ;;(format *error-output* "~A~%" *include-paths*)
  (let (code)
      (catch 'found
        (dolist (include-path *include-paths*)
          (let ((path (concatenate 'string (directory-namestring include-path) file)))
            ;;(format *error-output* "Searching: ~A~%" path)
            (when (probe-file path)
              (with-open-file (f path)
                ;;(format *error-output* "Found: ~A~%" path)
                (do
                 ((form (read f nil) (read f nil)))
                 ((not form))
                  (push form code)))
              (throw 'found (cons 'progn (nreverse code))))))
          (format *error-output* "sigil: Cannot find load file: ~A~%" file))
      ))

(defun ps2js (f)
  (in-package :ps)
  (do
   ((form (read f nil) (read f nil)))
   ((not form))
    (when *verbose*
      (format t  "/* ~A */~%~%" form))
    (let ((js-output (format nil "~A~%~%" (ps:ps* form))))
      (when (some #'alphanumericp js-output)
	(format t js-output)))))

(defmacro while (test &body body)
  `(loop
      (when (not ,test)
        (return))
      ,@body))

(defun repl ()
  (let* ((node (run-program "node" '("-i") :search t :input :stream :output :stream :wait nil))
         (node-input (process-input node))
         (node-output (process-output node)))
    (loop
       (format *error-output* "> ")
       (force-output *error-output*)
       (read-char node-output) ; eat initial prompt
       (handler-case
           (let ((form (read)))
             (format node-input "~A~%" (ps:ps* form))
             (force-output node-input)
             (loop
                (let ((c (read-char node-output)))
                  (when (and (char= #\Newline c)
                             (char= #\> (peek-char nil node-output)))
                    (read-char node-output)
                    (fresh-line)
                    (return))
                  (princ c)
                  (force-output))))
         (sb-sys:interactive-interrupt () (sb-ext:exit))
         (end-of-file () (sb-ext:exit))
         ))))

(defun main (argv)
  (push (probe-file ".") *include-paths*)
  (if (cdr argv)
      (progn
        (pop argv)
	;;; check for verbose flag
	(when (member "-v" argv :test #'string=)
	  (setf *verbose* t)
	  (setf argv (remove "-v" argv :test #'string=)))
        (while argv
          (let ((arg (pop argv)))
            (cond 
              ((string= arg "-I")
               (let ((dir (pop argv)))
                 (push (probe-file dir) *include-paths*)))
              ((string= arg "-i") (repl))
              ((string= arg "--eval")
               (let ((code (pop argv)))
                 (when *verbose*
		   (format t "/* --eval ~A~% */" (read-from-string code)))
                 (in-package :ps)
                 (eval (read-from-string code))))
              ((string= arg "--pseval")
               (let ((code (pop argv)))
                 (when *verbose*
		   (format t "/* --pseval ~A~% */" (read-from-string code)))
                 (ps:ps* (read-from-string code))))
              (t
               (let ((probe-results (probe-file arg)))
                 (when probe-results
                   ;; Add current file directory to include paths so they can relative load properly
                   (push (directory-namestring probe-results) *include-paths*)
                   
                   (setf *include-paths* (reverse *include-paths*))
                   (with-open-file (f arg)
                     (handler-bind
                         ((error
                           (lambda (e) 
                             (format *error-output* "~A~%" e)
                             (sb-ext:exit :code 1))))
                       (ps2js f))))))))))
      (repl)))
