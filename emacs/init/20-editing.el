;;; 20-editing.el --- editor-wide behavior, history and keys  -*- lexical-binding: t; -*-

;; --- session history ---

;; `desktop-save' defaults to `ask-if-new', which means a single "no" at the
;; exit prompt leaves no desktop file to restore from.  `check-pid' loads a
;; desktop whose lock belongs to a process that is gone, which is what a crash
;; or a killed daemon leaves behind.
(setq desktop-save t
      desktop-load-locked-desktop 'check-pid)
(desktop-save-mode 1)

;; Desktop restores file buffers but no minibuffer history: savehist is what
;; makes C-x b and M-x remember across sessions, and what vertico sorts by.
(setq history-length 500)
(savehist-mode 1)

;; Recently visited files, independent of whether the desktop loaded.
(setq recentf-max-saved-items 200)
(recentf-mode 1)
;; `package-user-dir' is set in 10-package.el, which loads first.
(add-to-list 'recentf-exclude (regexp-quote package-user-dir))

;; --- misc ---

;; Undo/redo window layouts: C-c <left> / C-c <right>.
(winner-mode 1)

(setq-default show-trailing-whitespace t)

(global-set-key [(meta +)] 'align-regexp)
