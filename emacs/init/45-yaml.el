;;; 45-yaml.el --- YAML: yaml-ts-mode, treesit  -*- lexical-binding: t; -*-

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

;; Tabs are not indentation in YAML -- the spec forbids them outright, and a
;; parser rejects the file rather than guessing a width -- so no buffer here may
;; inherit the global `indent-tabs-mode'.
;;
;; `yaml-ts-mode' derives from `text-mode', not `prog-mode', so the line-number
;; column set up in 20-editing.el does not reach it.  These buffers are code.
(add-hook 'yaml-ts-mode-hook
          (lambda ()
            (setq-local indent-tabs-mode nil)
            (display-line-numbers-mode 1)))
