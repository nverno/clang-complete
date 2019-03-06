(require 'ert)
(require 'clang-complete)

(defvar clang-complete-test-dir
  (file-name-directory (or load-file-name (buffer-file-name))))
(defvar clang-complete-file
  (expand-file-name ".clang_complete" clang-complete-test-dir))

;; return .clang_complete file contents as string
(defsubst clang-complete--string ()
  (and (file-exists-p clang-complete-file)
       (with-temp-buffer
         (insert-file-contents clang-complete-file)
         (buffer-string))))

(defmacro clang-complete-should-contain (contents &optional delete &rest body)
  "The .clang_complete file should contain CONTENTS after executing BODY."
  (declare (indent defun))
  `(progn
     (unwind-protect
         (progn
           (let ((default-directory clang-complete-test-dir)
                 (clang-complete-includes nil)
                 (clang-complete-default-defines nil)
                 (process-environment
                  (append '("CPATH=" "C_INCLUDE_PATH=" process-environment))))
             ,@body)
           (should (string= ,contents (clang-complete--string))))
       (and ,delete (delete-file clang-complete-file)))))

(ert-deftest clang-complete-defines-dups ()
  "Duplicated defines."
  (clang-complete-should-contain
    "\
-DDEBUG
-DTEST"
    'delete
    (let ((clang-complete-default-defines '("TEST" "DEBUG" "TEST" "DEBUG")))
      (clang-complete-create-or-update nil 'c-mode))))

(ert-deftest clang-complete-defines-empty ()
  "All empty defines and includes."
  (clang-complete-should-contain
    ""
    'delete
    (clang-complete-create-or-update nil 'c-mode)))

(ert-deftest clang-complete-envvars-1 ()
  "One env var defined."
  (clang-complete-should-contain
    "\
-I/h/inc
-I/u/inc"
    'delete
    (let ((process-environment
           (append '("CPATH=/h/inc:/u/inc" "C_INCLUDE_PATH=" process-environment))))
      (clang-complete-create-or-update nil 'c-mode))))

(ert-deftest clang-complete-envvars-2 ()
  "Env vars merge correctly."
  (clang-complete-should-contain
    "\
-I.
-I/h/inc
-I/j/n/inc
-I/u/inc"
    'delete
    (let ((process-environment
           (append '("CPATH=/h/inc:/u/inc" "C_INCLUDE_PATH=/j/n/inc:."
                     process-environment))))
      (clang-complete-create-or-update nil 'c-mode))))

(ert-deftest clang-complete-defines-and-envvars ()
  "Env vars and defines."
  (clang-complete-should-contain
    "\
-DDEBUG
-DTEST
-I.
-I/h/inc
-I/j/n/inc
-I/u/inc"
    'delete
    (let ((clang-complete-default-defines '("TEST" "TEST" "DEBUG"))
          (process-environment
           (append '("CPATH=/h/inc:/u/inc" "C_INCLUDE_PATH=/j/n/inc:."
                     process-environment))))
      (clang-complete-create-or-update nil 'c-mode))))

(ert-deftest clang-complete-update-1 ()
  "Add local includes."
  (clang-complete-should-contain
    "\
-DDEBUG
-I.
-I..
-I../inc
-I/h/inc
-I/j/n/inc
-I/u/inc
-I/usr/include"
    'delete
    (let ((clang-complete-includes '((local "." ".." "../inc")
                                     (c "/usr/include")))
          (clang-complete-default-defines '("DEBUG"))
          (process-environment
           (append '("CPATH=/h/inc:/u/inc" "C_INCLUDE_PATH=/j/n/inc:."
                     process-environment))))
      (clang-complete-create-or-update nil 'c-mode))))

(ert-deftest clang-complete-update-1 ()
  "Add local includes."
  (clang-complete-should-contain
    "\
-DDEBUG
-DTEST
-I.
-I/usr/include"
    'delete
    (let ((clang-complete-includes '((c++ "/usr/include")))
          (clang-complete-default-defines '("DEBUG"))
          (process-environment
           (append '("CPATH=/usr/include" "CPLUS_INCLUDE_PATH=."
                     process-environment))))
      (clang-complete-create-or-update nil 'c++-mode)
      (clang-complete-create-or-update
       nil 'c++-mode '(("-D" . "DEBUG") ("-D" . "TEST"))))))
