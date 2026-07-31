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
 '(package-selected-packages '(corfu dape edit-indirect exec-path-from-shell go-mode gotest magit markdown-mode)))
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


;; --- package manager ---

(require 'package)
(setq package-user-dir (expand-file-name "~/dot/emacs/libs"))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Packages are listed in `package-selected-packages' above.
;; To install them on a new machine, or after adding one:
;;   M-x package-refresh-contents
;;   M-x package-install-selected-packages

;; --- markdown ---

(with-eval-after-load 'markdown-mode
  (setq markdown-fontify-code-blocks-natively t
        markdown-command "pandoc"))

;; --- Go IDE ---

(add-to-list 'major-mode-remap-alist '(go-mode . go-ts-mode))

(with-eval-after-load 'go-mode
  (keymap-unset go-mode-map "M-." t)
  (keymap-unset go-mode-map "M-*" t)
  (keymap-set go-mode-map "C-c C-d" #'eldoc-doc-buffer))

;; gopls et al. live in $GOPATH/bin
(let ((gobin (expand-file-name "~/go/bin")))
  (add-to-list 'exec-path gobin)
  (setenv "PATH" (concat gobin ":" (getenv "PATH"))))

(global-corfu-mode 1)
(setq tab-always-indent 'complete)

(add-hook 'go-mode-hook #'eglot-ensure)
(add-hook 'go-mode-hook (lambda () (setq tab-width 4 indent-tabs-mode t)))

;; format + organize imports on save
(defun my/go-before-save ()
  (when (eglot-managed-p)
    (eglot-format-buffer)
    (call-interactively #'eglot-code-action-organize-imports)))
(add-hook 'before-save-hook #'my/go-before-save)

;; gopls settings: staticcheck + unused-param hints
(setq-default eglot-workspace-configuration
	      '(:gopls (:staticcheck t :usePlaceholders t :gofumpt t)))

(with-eval-after-load 'go-mode
  (define-key go-mode-map (kbd "C-c C-t") #'go-test-current-test)
  (define-key go-mode-map (kbd "C-c C-f") #'go-test-current-file)
  (define-key go-mode-map (kbd "C-c C-r") #'eglot-rename)
  (define-key go-mode-map (kbd "C-c C-a") #'eglot-code-actions))

  (with-eval-after-load 'flymake
    (keymap-set flymake-mode-map "M-n" #'flymake-goto-next-error)
    (keymap-set flymake-mode-map "M-p" #'flymake-goto-prev-error))



;; --- inherit path on macos ---
(when (memq window-system '(mac ns))
  (unless (package-installed-p 'exec-path-from-shell)
    (package-install 'exec-path-from-shell))
  (exec-path-from-shell-initialize))


;; llm
;; (setq minuet-provider 'openai-fim-compatible)
;; (plist-put minuet-openai-fim-compatible-options :end-point
;;            "http://localhost:8012/v1/completions")
;; (plist-put minuet-openai-fim-compatible-options :name "llama.cpp")
;; (plist-put minuet-openai-fim-compatible-options :api-key (lambda () "dummy"))
;; (plist-put minuet-openai-fim-compatible-options :model "qwen2.5-coder")

;; (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
;; (define-key global-map (kbd "M-y") #'minuet-accept-suggestion)
;; (define-key global-map (kbd "M-e") #'minuet-dismiss-suggestion)

(server-start)
