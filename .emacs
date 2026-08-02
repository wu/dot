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
;; Start early: an error further down this file must not cost us emacsclient.
(server-start)

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

;; --- misc ---
(global-set-key "\C-cm" 'magit-status)
(desktop-save-mode 1)

;; Undo/redo window layouts: C-c <left> / C-c <right>.
(winner-mode 1)

(setq-default show-trailing-whitespace t)

(global-set-key [(meta +)] 'align-regexp)


;; --- magit windows ---

;; Status replaces the buffer in the selected window rather than splitting it,
;; so `winner-undo' steps back to whatever was being edited there.  Diffs, logs
;; and commit buffers still get their own windows -- they are meant to be read
;; alongside the status buffer.  `q' also restores the pre-magit layout.
(setq magit-display-buffer-function
      #'magit-display-buffer-same-window-except-diff-v1
      magit-bury-buffer-function #'magit-restore-window-configuration)


;; --- magit repolist ---

;; Status of every repo in a workspace at once.  A workspace is any directory
;; holding a `.workspace' marker file; the repos are its immediate subdirs,
;; plus the workspace itself when it is also a repo.  Scoping is
;; per-invocation, so `C-c M' in ~/projects/keyopx shows only the keyopx
;; repos, and elsewhere shows only that workspace's.

(defun my/magit-workspace-root ()
  "Nearest enclosing directory containing a `.workspace' file.
Falls back to `default-directory' when there is no marker above us."
  (file-name-as-directory
   (expand-file-name
    (or (locate-dominating-file default-directory ".workspace")
        default-directory))))

(defun my/magit-workspace-repos (root)
  "ROOT and each immediate subdir of it that is a git repo, as (DIR . 0).
Depth 0 because `magit-list-repos-1' stops at the first directory containing
a .git and never descends -- so a workspace that is itself a repo (with its
sub-repos gitignored) would otherwise report only itself."
  (mapcar (lambda (dir) (cons dir 0))
          (seq-filter
           (lambda (dir) (file-readable-p (expand-file-name ".git" dir)))
           (cons (directory-file-name root)
                 (seq-filter #'file-directory-p
                             (directory-files
                              root t directory-files-no-dot-files-regexp t))))))

(defun my/magit-list-repositories-here (&optional root)
  "List the repos in the current workspace.
With a prefix arg, prompt for ROOT instead of locating the marker."
  (interactive (list (when current-prefix-arg
                       (read-directory-name "Repo root: "))))
  (let* ((root (or root (my/magit-workspace-root)))
         (dirs (my/magit-workspace-repos root))
         (magit-repository-directories dirs))
    (unless dirs
      (user-error "No git repos in %s" root))
    (magit-list-repositories)
    ;; `g' in the repolist buffer re-reads the variable, and by then the `let'
    ;; above is gone -- pin the scope to the buffer so refresh stays put.
    (when-let* ((buf (get-buffer "*Magit Repositories*")))
      (with-current-buffer buf
        (setq-local magit-repository-directories dirs)))))

;; B<U/B>U compare against the last fetch, not the live remote; `f' in the
;; repolist buffer freshens them.
(setq magit-repolist-columns
      '(("Name"    25 magit-repolist-column-ident nil)
        ("Flag"     4 magit-repolist-column-flag
         ((:right-align t) (:help-echo "N=untracked U=unstaged S=staged")))
        ("B<U"      3 magit-repolist-column-unpulled-from-upstream
         ((:right-align t) (:help-echo "Upstream changes not in branch")))
        ("B>U"      3 magit-repolist-column-unpushed-to-upstream
         ((:right-align t) (:help-echo "Local changes not in upstream")))
        ("Branch"  15 magit-repolist-column-branch nil)
        ("Path"    99 magit-repolist-column-path nil)))

(global-set-key "\C-cM" 'my/magit-list-repositories-here)


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
