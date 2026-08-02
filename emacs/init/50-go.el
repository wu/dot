;;; 50-go.el --- Go IDE: go-ts-mode, eglot/gopls, treesit  -*- lexical-binding: t; -*-

;; go-mode's autoload claims .go, so remap it.  go-mode stays installed for
;; go-coverage and go-play-buffer, which are callable via autoload regardless.
;; Needs the grammar: M-x treesit-install-language-grammar RET go RET
(add-to-list 'major-mode-remap-alist '(go-mode . go-ts-mode))

;; gopls et al. live in $GOPATH/bin
(let ((gobin (expand-file-name "~/go/bin")))
  (add-to-list 'exec-path gobin)
  (setenv "PATH" (concat gobin ":" (getenv "PATH"))))

(when (fboundp 'global-corfu-mode) (global-corfu-mode 1))
(setq tab-always-indent 'complete)

(add-hook 'go-ts-mode-hook #'eglot-ensure)
;; Keep the indent offset equal to tab-width, or one level spans more than one
;; tab and TAB double-indents.  Both must change together.
(add-hook 'go-ts-mode-hook
          (lambda ()
            (setq-local tab-width 4
                        go-ts-mode-indent-offset 4
                        indent-tabs-mode t)))

;; format + organize imports on save
(defun my/go-before-save ()
  (when (eglot-managed-p)
    (eglot-format-buffer)
    ;; Signals when gopls offers no actions; unguarded that would abort the save.
    (ignore-errors
      (call-interactively #'eglot-code-action-organize-imports))))
(add-hook 'before-save-hook #'my/go-before-save)

;; gopls settings: staticcheck + unused-param hints
(setq-default eglot-workspace-configuration
	      '(:gopls (:staticcheck t :usePlaceholders t :gofumpt t)))

;; M-q is `prog-fill-reindent-defun', which reindents using go-ts-mode's own
;; rules.  Those disagree with gofumpt on column alignment, so let gopls be the
;; only thing that ever formats code.
(defun my/go-fill-or-format ()
  "Fill the comment at point; otherwise format the buffer with gopls."
  (interactive)
  (if (nth 4 (syntax-ppss))
      (fill-paragraph)
    (eglot-format-buffer)))

(with-eval-after-load 'go-ts-mode
  (keymap-set go-ts-mode-map "C-c C-t" #'go-test-current-test)
  (keymap-set go-ts-mode-map "C-c C-f" #'go-test-current-file)
  (keymap-set go-ts-mode-map "C-c C-r" #'eglot-rename)
  (keymap-set go-ts-mode-map "C-c C-a" #'eglot-code-actions)
  (keymap-set go-ts-mode-map "C-c C-d" #'eldoc-doc-buffer)
  (keymap-set go-ts-mode-map "M-q" #'my/go-fill-or-format))

(with-eval-after-load 'flymake
  (keymap-set flymake-mode-map "M-n" #'flymake-goto-next-error)
  (keymap-set flymake-mode-map "M-p" #'flymake-goto-prev-error))

;; Maximum fontification (default is 3): adds operators, brackets, delimiters,
;; property and variable references.  `setopt' so the setter recomputes
;; features in buffers that are already open.
(setopt treesit-font-lock-level 4)

(setq treesit-language-source-alist
      '((go "https://github.com/tree-sitter/tree-sitter-go")
        (gomod "https://github.com/camdencheek/tree-sitter-go-mod")))

(defun my/treesit-install-missing ()
  "Install any grammar in `treesit-language-source-alist' not already present."
  (interactive)
  (dolist (src treesit-language-source-alist)
    (unless (treesit-language-available-p (car src))
      (treesit-install-language-grammar (car src)))))
