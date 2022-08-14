;;; symex-transformations-ts.el --- An evil way to edit Lisp symbolic expressions as trees -*- lexical-binding: t -*-

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

;; Standard mutative operations to be performed on symexes via Tree
;; Sitter.

;;; Code:

(require 'tree-sitter)

(defun symex-ts-append-after ()
  "Append after symex (instead of vim's default of line)."
  (when (symex-ts-get-current-node)
    (goto-char (tsc-node-end-position (symex-ts-get-current-node)))
    (insert " ")
    (evil-insert-state)))

(defun symex-ts-change-node-forward (&optional count)
  "Delete COUNT nodes forward from the current node and enter Insert state."
  (interactive "p")
  (save-excursion (symex-ts-delete-node-forward count t))
  (evil-insert-state 1))

(defun symex-ts-delete-node-backward (&optional count)
  "Delete COUNT nodes backward from the current node."
  (interactive "p")
  (let* ((count (or count 1))
         (node (tsc-get-prev-named-sibling (symex-ts-get-current-node))))
    (when node
      (let ((end-pos (tsc-node-end-position node))
            (start-pos (tsc-node-start-position
                        (if (> count 1)
                            (symex-ts--get-nth-sibling-from-node node #'tsc-get-prev-named-sibling count)
                          node))))
        (kill-region start-pos end-pos)
        (symex-ts--delete-current-line-if-empty start-pos)
        (symex-ts-set-current-node-from-point)))))

(defun symex-ts-delete-node-forward (&optional count keep-empty-lines)
  "Delete COUNT nodes forward from the current node.

If KEEP-EMPTY-LINES is set then if the deletion results in an
empty line it will be kept. By default empty lines are deleted
too."
  (interactive "p")
  (let* ((count (or count 1))
         (node (symex-ts-get-current-node))
         (next-node (symex-ts--get-nth-sibling-from-node node #'tsc-get-next-named-sibling count))
         (start-pos (tsc-node-start-position node))
         (end-pos (tsc-node-end-position
                   (if (> count 1)
                       (symex-ts--get-nth-sibling-from-node node #'tsc-get-next-named-sibling count)
                     node))))

    (if next-node
        (symex-ts--set-current-node next-node)
      (symex-ts-set-current-node-from-point))
    (kill-region start-pos end-pos)

    (when (not keep-empty-lines) (symex-ts--delete-current-line-if-empty start-pos))
    (symex-ts-set-current-node-from-point)))

(defun symex-ts-insert-at-beginning ()
  "Insert at beginning of symex."
  (interactive)
  (when (symex-ts-get-current-node)
    (goto-char (tsc-node-start-position (symex-ts-get-current-node)))
    (evil-insert-state)))

(defun symex-ts-insert-at-end ()
  "Insert at end of symex."
  (interactive)
  (when (symex-ts-get-current-node)
    (goto-char (tsc-node-end-position (symex-ts-get-current-node)))
    (evil-insert-state)))

(defun symex-ts-insert-before ()
  "Insert before symex (instead of vim's default at the start of line)."
  (interactive)
  (when (symex-ts-get-current-node)
    (goto-char (tsc-node-start-position (symex-ts-get-current-node)))
    (insert " ")
    (backward-char)
    (evil-insert-state)))

(defun symex-ts-open-line-after ()
  "Open new line after symex."
  (interactive)
  (when (symex-ts-get-current-node)
    (goto-char (tsc-node-end-position (symex-ts-get-current-node)))
    (newline-and-indent)
    (evil-insert-state)))

(defun symex-ts-open-line-before ()
  "Open new line before symex."
  (interactive)
  (when (symex-ts-get-current-node)
    (goto-char (tsc-node-start-position (symex-ts-get-current-node)))
    (newline-and-indent)
    (evil-previous-line)
    (indent-according-to-mode)
    (evil-append-line 1)))

(defun symex-ts--paste (count direction)
  "Paste before or after symex, COUNT times, according to DIRECTION.

DIRECTION should be either the symbol `before' or `after'."
  (interactive)
  (when (symex-ts-get-current-node)
    (let* ((node (symex-ts-get-current-node))
           (start (tsc-node-start-position node))
           (end (tsc-node-end-position node))
           (indent-start (save-excursion (back-to-indentation) (point)))
           (block-node (or (not (= (line-number-at-pos start) (line-number-at-pos end)))
                           (and (= start indent-start)
                                (= end (line-end-position))))))
      (goto-char (if (eq direction 'before) start end))
      (dotimes (_ count)
        (when (eq direction 'after) (insert (if block-node "\n" " ")))
        (yank)
        (when (eq direction 'before) (insert (if block-node "\n" " "))
              (indent-according-to-mode)))
      (backward-char (* count (- end start)))
      (symex-ts-set-current-node-from-point)
      (indent-according-to-mode))))

(defun symex-ts-paste-after (count)
  "Paste after symex, COUNT times."
  (interactive)
  (symex-ts--paste count 'after))

(defun symex-ts-paste-before (count)
  "Paste before symex, COUNT times."
  (interactive)
  (symex-ts--paste count 'before))

(defun symex-ts-yank (count)
  "Yank (copy) COUNT symexes."
  (interactive "p")
  ;; we set `last-command` here to avoid appending to the kill ring
  ;; when it's a delete followed by a yank. We want to treat each as
  ;; independent entries in the kill ring
  (when (symex-ts-get-current-node)
    (let* ((last-command nil)
           (node (symex-ts-get-current-node))
           (start (tsc-node-start-position node))
           (end (tsc-node-end-position
                 (if (> count 1)
                     (symex-ts--get-nth-sibling-from-node node #'tsc-get-next-named-sibling count)
                   node))))
      (copy-region-as-kill start end))))


;; TODO: TS: capture node
;; TODO: TS: clear node
;; TODO: TS: comment node
;; TODO: TS: delete remaining nodes
;; TODO: TS: emit node
;; TODO: TS: replace node
;; TODO: TS: shift forward/backward node
;; TODO: TS: splice node
;; TODO: TS: swallow node
;; TODO: TS: wrap node
;; TODO: TS: yank remaining nodes

;; TODO: TS: join node ?
;; TODO: TS: split node ?


(provide 'symex-transformations-ts)
;;; symex-transformations-ts.el ends here
