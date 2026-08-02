;;; 00-core.el --- appearance and server  -*- lexical-binding: t; -*-

;; Dark background theme
(load-theme 'wombat t)

;; Optional: set default frame appearance
(setq default-frame-alist
      '((background-color . "#1c1c1c")
        (foreground-color . "#d0d0d0")
        (cursor-color . "#f0f0f0")))

;; --- font ---
;; Anonymous Pro if it's installed, otherwise leave the default alone.
;; Frames created by emacsclient read `default-frame-alist', so set both.
(when (and (display-graphic-p) (find-font (font-spec :name "Anonymous Pro")))
  (add-to-list 'default-frame-alist '(font . "Anonymous Pro-12"))
  (set-face-attribute 'default nil :font "Anonymous Pro-12"))

;; --- server ---
;; Start early: an error in a later module must not cost us emacsclient.
(server-start)
