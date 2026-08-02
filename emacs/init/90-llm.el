;;; 90-llm.el --- minuet completion against a local llama.cpp  -*- lexical-binding: t; -*-

;; Disabled; minuet is not in `package-selected-packages'.

;; (setq minuet-provider 'openai-fim-compatible)
;; (plist-put minuet-openai-fim-compatible-options :end-point
;;            "http://localhost:8012/v1/completions")
;; (plist-put minuet-openai-fim-compatible-options :name "llama.cpp")
;; (plist-put minuet-openai-fim-compatible-options :api-key (lambda () "dummy"))
;; (plist-put minuet-openai-fim-compatible-options :model "qwen2.5-coder")

;; (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)
;; (define-key global-map (kbd "M-y") #'minuet-accept-suggestion)
;; (define-key global-map (kbd "M-e") #'minuet-dismiss-suggestion)
