;; Dark background theme
(load-theme 'wombat t)

;; Optional: set default frame appearance
(setq default-frame-alist
      '((background-color . "#1c1c1c")
        (foreground-color . "#d0d0d0")
        (cursor-color . "#f0f0f0")))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(package-selected-packages '(magit)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

(global-set-key "\C-cm" 'magit-status)
(desktop-save-mode 1)

(setq-default show-trailing-whitespace t)

(global-set-key [(meta +)] 'align-regexp)

(server-start)

