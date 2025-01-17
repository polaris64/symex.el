;;; symex-primitives.el --- An evil way to edit Lisp symbolic expressions as trees -*- lexical-binding: t -*-

;; URL: https://github.com/countvajhula/symex.el

;; This program is "part of the world," in the sense described at
;; https://drym.org.  From your perspective, this is no different than
;; MIT or BSD or other such "liberal" licenses that you may be
;; familiar with, that is to say, you are free to do whatever you like
;; with this program.  It is much more than BSD or MIT, however, in
;; that it isn't a license at all but an idea about the world and how
;; economic systems could be set up so that everyone wins.  Learn more
;; at drym.org.
;;
;; This work transcends traditional legal and economic systems, but
;; for the purposes of any such systems within which you may need to
;; operate:
;;
;; This is free and unencumbered software released into the public domain.
;; The authors relinquish any copyright claims on this work.
;;

;;; Commentary:

;; Primitive navigations using third party libraries.  This layer of primitives
;; can be swapped out without changing the higher-level functionality provided
;; by the Symex DSL.  In the future it may make sense to directly operate on
;; an annotated representation of the AST here containing a mapping to buffer
;; positions and other metadata relevant for editing purposes.

;;; Code:


(require 'symex-primitives-lisp)
(require 'symex-ts)

;;; User Interface

(defun symex--adjust-point ()
  "Helper to adjust point to indicate the correct symex."
  (if tree-sitter-mode
      (symex-ts--adjust-point)
    (symex-lisp--adjust-point)))

;;; Predicates

(defun symex--point-at-root-symex-p ()
  "Check if point is at a root symex."
  (if tree-sitter-mode
      ;; note that tree-sitter has a global
      ;; root for the whole file -- that's
      ;; not the one we mean here, but
      ;; rather, top level definitions
      (symex-ts--at-tree-root-p)
    (symex-lisp--point-at-root-symex-p)))

(defun symex--point-at-first-symex-p ()
  "Check if point is at the first symex at some level."
  (if tree-sitter-mode
      (symex-ts--at-first-p)
    (symex-lisp--point-at-first-symex-p)))

(defun symex--point-at-last-symex-p ()
  "Check if point is at the last symex at some level."
  (if tree-sitter-mode
      (symex-ts--at-last-p)
    (symex-lisp--point-at-last-symex-p)))

(defun symex--point-at-final-symex-p ()
  "Check if point is at the last symex in the buffer."
  (if tree-sitter-mode
      (symex-ts--at-final-p)
    (symex-lisp--point-at-final-symex-p)))

(defun symex--point-at-initial-symex-p ()
  "Check if point is at the first symex in the buffer."
  (if tree-sitter-mode
      (symex-ts--at-initial-p)
    (symex-lisp--point-at-initial-symex-p)))

(defun symex--point-at-start-p ()
  "Check if point is at the start of a symex."
  (if tree-sitter-mode
      (symex-ts--point-at-start-p)
    (symex-lisp--point-at-start-p)))

;;; Navigation

(defun symex--go-forward (&optional count)
  "Forward symex.

Go forward COUNT times, defaulting to one.

This is an internal utility that avoids any user-level concerns
such as symex selection via advice.  This should be used in all
internal operations that are not primarily user-directed."
  (interactive)
  (if tree-sitter-mode
      (symex-ts-move-next-sibling count)
    (symex-lisp--forward count)))

(defun symex--go-backward (&optional count)
  "Backward symex.

Go backward COUNT times, defaulting to one.

This is an internal utility that avoids any user-level concerns
such as symex selection via advice.  This should be used in all
internal operations that are not primarily user-directed."
  (interactive)
  (if tree-sitter-mode
      (symex-ts-move-prev-sibling count)
    (symex-lisp--backward count)))

(defun symex--go-up (&optional count)
  "Enter higher symex level.

Enter COUNT times, defaulting to one.

This is an internal utility that avoids any user-level concerns
such as symex selection via advice.  This should be used in all
internal operations that are not primarily user-directed."
  (interactive)
  (if tree-sitter-mode
      (symex-ts-move-child count)
    (symex-lisp--go-up count)))

(defun symex--go-down (&optional count)
  "Exit to lower symex level.

Exit COUNT times, defaulting to one.

This is an internal utility that avoids any user-level concerns
such as symex selection via advice.  This should be used in all
internal operations that are not primarily user-directed."
  (interactive)
  (if tree-sitter-mode
      (symex-ts-move-parent count)
    (symex-lisp--go-down count)))

;;; Utilities

(defmacro symex-save-excursion (&rest body)
  "Execute BODY while preserving position in the tree.

Like `save-excursion`, but in addition to preserving the point
position, this also preserves the structural position in the tree, for
languages where point position doesn't uniquely identify a tree
location (e.g. non-symex-based languages like Python)."
  (let ((offset (gensym))
        (result (gensym)))
    `(let ((,offset (symex--point-height-offset)))
       (let ((,result
              (save-excursion
                ,@body)))
         (symex-select-nearest)
         (symex--go-up ,offset)
         ,result))))

(defun symex--point-height-offset ()
  "Compute the height offset of the current symex.

This is measured from the lowest symex indicated by point.

This will always be zero for symex-oriented languages such as Lisp,
but in languages like Python where the same point position could
correspond to multiple hierarchy levels, this function computes the
difference from the lowest such level."
  (if tree-sitter-mode
      (symex-ts--point-height-offset)
    (symex-lisp--point-height-offset)))

(defun symex--get-starting-point ()
  "Get the point value at the start of the current symex."
  (if tree-sitter-mode
      (symex-ts--get-starting-point)
    (symex-lisp--get-starting-point)))

(defun symex--get-end-point (count)
  "Get the point value after COUNT symexes.

If the containing expression terminates earlier than COUNT
symexes, returns the end point of the last one found."
  (if tree-sitter-mode
      (symex-ts--get-end-point count)
    (symex-lisp--get-end-point count)))

(defun symex-select-nearest ()
  "Select symex nearest to point."
  (interactive)
  (if tree-sitter-mode
      (symex-ts-set-current-node-from-point)
    (symex-lisp--select-nearest))
  (point))

(defun symex--primitive-exit ()
  "Take necessary actions as part of exiting Symex mode, at a primitive level."
  (symex--delete-overlay)
  (if tree-sitter-mode
      (symex-ts--exit)
    (symex-lisp--exit)))


(provide 'symex-primitives)
;;; symex-primitives.el ends here
