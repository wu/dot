;;; 00-core.el --- appearance and server  -*- lexical-binding: t; -*-

;; Dark background theme
(load-theme 'wombat t)

;; Optional: set default frame appearance
;; `tool-bar-lines' is here as well as in the `tool-bar-mode' call below:
;; disabling the mode only rewrites `default-frame-alist' when the parameter is
;; already in it, and frames made by emacsclient are built from that alist.
(setq default-frame-alist
      '((background-color . "#1c1c1c")
        (foreground-color . "#d0d0d0")
        (cursor-color . "#f0f0f0")
        (tool-bar-lines . 0)))

;; No tool bar.  On macOS it is drawn as a native toolbar in the title bar,
;; where the icons are large and take a row of screen height for commands that
;; all have key bindings.
(tool-bar-mode -1)

;; --- font ---
;; Anonymous Pro if it's installed, otherwise leave the default alone.
;; Frames created by emacsclient read `default-frame-alist', so set both.
(when (and (display-graphic-p) (find-font (font-spec :name "Anonymous Pro")))
  (add-to-list 'default-frame-alist '(font . "Anonymous Pro-12"))
  (set-face-attribute 'default nil :font "Anonymous Pro-12"))

;; --- server ---
;; Start early: an error in a later module must not cost us emacsclient.
(server-start)
