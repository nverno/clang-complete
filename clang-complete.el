;;; clang-complete.el --- Manage .clang_complete file -*- lexical-binding: t; -*-

;; This is free and unencumbered software released into the public domain.

;; Last modified: <2019-03-06 13:15:43>
;; Author: Noah Peart <noah.v.peart@gmail.com>
;; URL: https://github.com/nverno/clang-complete
;; Package-Requires: 
;; Created:  2 February 2017

;; This file is not part of GNU Emacs.
;;
;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License as
;; published by the Free Software Foundation; either version 3, or
;; (at your option) any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
;; General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with this program; see the file COPYING.  If not, write to
;; the Free Software Foundation, Inc., 51 Franklin Street, Fifth
;; Floor, Boston, MA 02110-1301, USA.

;;; Commentary:

;; Do the .clang_complete file
;; - create with defaults
;; - update with new options

;; https://github.com/Rip-Rip/clang_complete/wiki
;; discusses making pre-compiled headers for clang_complete

;;; Code:
(eval-when-compile
  (require 'cl-lib))

(defvar-local clang-complete-default-defines '("DEBUG" "TEST")
  "Default symbols to define in .clang_comlete.")

(defvar clang-complete-includes
  '((local "." ".." "../include") (c) (c++))
  "Default include paths to include for local/c/c++.")

;; merge environment variables ENV1 with ENV2, removing duplicates
(defun clang-complete--merge-envs (env1 env2)
  (let ((e1 (getenv env1))
        (e2 (getenv env2)))
    (delete-dups (append
                  (and e1 (split-string e1 path-separator t))
                  (and e2 (split-string e2 path-separator t))))))

;; Get default includes (local/system) for MODE, eg. c/c++.
;; If SYSTEM is non-nil, don't include local paths.
(defun clang-complete--default-includes (mode &optional system)
  (append
   (clang-complete--merge-envs
    (if (eq mode 'c-mode) "C_INCLUDE_PATH" "CPLUS_INCLUDE_PATH") "CPATH")
   (and (not system) (cdr (assq 'local clang-complete-includes)))
   (cdr (assq (if (eq mode 'c-mode) 'c 'c++) clang-complete-includes))))

;; generate list of defaults
(defsubst clang-complete--defaults (mode)
  (append
   (mapcar (lambda (s) (cons "-I" s)) (clang-complete--default-includes mode))
   (mapcar (lambda (s) (cons "-D" s)) clang-complete-default-defines)))

(defun clang-complete--parse-buffer ()
  "Parse .clang_complete file options to alist."
  (let (opts)
    (goto-char (point-min))
    (condition-case nil
        (while (re-search-forward
                (eval-when-compile
                  (concat
                   (regexp-opt '("-I" "-D" "-include" "-std=" "-W") 'paren)
                   "\\(.+\\)$")))
          (push (cons (match-string 1) (match-string 2)) opts))
      (error opts))))

;; merge options, sort, and concatenate
(defsubst clang-complete--merge-options (options)
  (mapconcat
   (lambda (k-v) (concat (car k-v) (cdr k-v)))
   (cl-sort (delete-dups options)
            (lambda (a b) (or (string< (car a) (car b))
                         (and (string= (car a) (car b))
                              (string< (cdr a) (cdr b))))))
   "\n"))

;; read input string, split by whitespace, eg -DDEBUG -DTEST => ("-DDEBUG" "-DTEST")
;; buffer parser will do the rest
(defsubst clang-complete--read-input ()
  (let ((opts (read-from-minibuffer "Clang complete options: ")))
    (mapconcat 'identity (split-string opts) "\n")))

;;;###autoload
(defun clang-complete-create-or-update (arg &optional mode options no-defaults)
  "Update or create .clang_complete file.
With prefix ARG, prompt for OPTIONS to add, otherwise uses defaults unless
NO-DEFAULTS is non-nil.
MODE defaults to current `major-mode'."
  (interactive "P")
  (let ((mode (or mode major-mode))
        (init (not (file-exists-p ".clang_complete"))))
    (with-current-buffer (find-file-noselect ".clang_complete")
      (when arg
        (insert "\n")
        (insert (clang-complete--read-input)))
      (let ((opts (clang-complete--parse-buffer))
            (new-opts (append options (and init (not no-defaults)
                                           (clang-complete--defaults mode)))))
        (erase-buffer)
        (insert (clang-complete--merge-options (nconc opts new-opts)))
        (save-buffer)
        (kill-buffer)))))

(provide 'clang-complete)
;;; clang-complete.el ends here
