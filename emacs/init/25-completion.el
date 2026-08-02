;;; 25-completion.el --- minibuffer completion  -*- lexical-binding: t; -*-

;; corfu (50-go.el) does in-buffer completion; this is its minibuffer
;; counterpart: vertico for the vertical candidate list, orderless for
;; matching, marginalia for annotations, consult for the commands.

(when (fboundp 'vertico-mode) (vertico-mode 1))
(when (fboundp 'marginalia-mode) (marginalia-mode 1))

;; 10 candidates is the default and is cramped for buffer lists.  `resize' t
;; shrinks back down when there are only a few matches, so the tall list costs
;; nothing when it is not needed.
(setq vertico-count 20
      vertico-resize t)

;; Space-separated fragments match in any order, so `go main' finds
;; api/main.go.  orderless registers its style at load time rather than via an
;; autoload, so it has to be required before `completion-styles' names it.
(when (require 'orderless nil t)
  (setq completion-styles '(orderless basic)
        ;; Category defaults quietly override `completion-styles'; clearing
        ;; them is what makes orderless apply everywhere.
        completion-category-defaults nil
        ;; File names keep `partial-completion' so /u/s/l expands the way it
        ;; always has, and TRAMP paths still complete.
        completion-category-overrides '((file (styles partial-completion)))))

;; --- moving around the candidate list ---

(defun my/vertico-next-half ()
  "Move down half a screen of candidates."
  (interactive)
  (vertico-next (max 1 (/ vertico-count 2))))

(defun my/vertico-previous-half ()
  "Move up half a screen of candidates."
  (interactive)
  (vertico-previous (max 1 (/ vertico-count 2))))

;; Vertico reaches these via remaps of `scroll-up-command' and friends, which
;; only works if nothing else claims the keys first -- bind them outright.
(with-eval-after-load 'vertico
  (keymap-set vertico-map "<prior>"   #'vertico-scroll-down)  ; PgUp: page up
  (keymap-set vertico-map "<next>"    #'vertico-scroll-up)    ; PgDn: page down
  (keymap-set vertico-map "M-v"       #'vertico-scroll-down)
  (keymap-set vertico-map "C-v"       #'vertico-scroll-up)
  (keymap-set vertico-map "M-<"       #'vertico-first)        ; top of list
  (keymap-set vertico-map "M->"       #'vertico-last)         ; bottom of list
  (keymap-set vertico-map "C-<prior>" #'my/vertico-previous-half)
  (keymap-set vertico-map "C-<next>"  #'my/vertico-next-half))

;; Let a minibuffer command read from the minibuffer again -- consult previews
;; and `M-x' from inside a prompt both rely on it.
(setq enable-recursive-minibuffers t)
(minibuffer-depth-indicate-mode 1)

;; Hide commands that are not applicable to the current mode from M-x.
(setq read-extended-command-predicate #'command-completion-default-include-p)

;; --- consult ---

;; C-x b spans open buffers, recentf files and bookmarks in one prompt, so
;; "the file I had open last week" and "the buffer open now" are one keystroke.
(when (fboundp 'consult-buffer)
  (global-set-key (kbd "C-x b")   #'consult-buffer)
  (global-set-key (kbd "C-x 4 b") #'consult-buffer-other-window)
  (global-set-key (kbd "C-x p b") #'consult-project-buffer)
  (global-set-key (kbd "M-y")     #'consult-yank-pop)
  (global-set-key (kbd "M-g g")   #'consult-goto-line)
  (global-set-key (kbd "M-g i")   #'consult-imenu)
  ;; C-s stays isearch; consult-line lives alongside it under the search map.
  (global-set-key (kbd "M-s l")   #'consult-line)
  (global-set-key (kbd "M-s r")   #'consult-ripgrep)
  (global-set-key (kbd "M-s f")   #'consult-find))

;; Previewing every candidate opens files as you arrow past them, which is
;; expensive over TRAMP and noisy with eglot; require M-. to preview instead.
(with-eval-after-load 'consult
  (consult-customize
   consult-buffer consult-recent-file consult-project-buffer
   :preview-key "M-."))
