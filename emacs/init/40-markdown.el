;;; 40-markdown.el --- markdown-mode  -*- lexical-binding: t; -*-

(with-eval-after-load 'markdown-mode
  (setq markdown-fontify-code-blocks-natively t
        markdown-command "pandoc"))
