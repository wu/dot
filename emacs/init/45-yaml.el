;;; 45-yaml.el --- YAML: yaml-ts-mode, treesit  -*- lexical-binding: t; -*-

;; `treesit-language-source-alist' is a plain `defvar' in treesit.el, and
;; treesit.el is not preloaded -- so the variable is void until something
;; requires it, and `add-to-list' on a void variable signals rather than
;; creating it.
(require 'treesit)

;; `yaml-ts-mode' ships with Emacs 29+, so nothing goes in
;; `package-selected-packages'.  It does need the grammar:
;;   M-x my/treesit-install-missing   (defined in 50-go.el)
(add-to-list 'treesit-language-source-alist
             '(yaml "https://github.com/tree-sitter-grammars/tree-sitter-yaml"))

;; yaml-ts-mode.el claims .yaml/.yml itself, but the `add-to-list' that does it
;; sits at the end of the file rather than behind an autoload cookie, so it only
;; runs once something has already loaded the mode.  Claim the extensions here
;; instead.
(add-to-list 'auto-mode-alist '("\\.ya?ml\\'" . yaml-ts-mode))

;; `yaml-ts-mode' derives from `text-mode', not `prog-mode', so the line-number
;; column set up in 20-editing.el does not reach it.  These buffers are code.
;; (Tabs need no handling here: the mode already sets `indent-tabs-mode' nil,
;; the YAML spec forbidding tabs as indentation.)
(add-hook 'yaml-ts-mode-hook #'display-line-numbers-mode)
