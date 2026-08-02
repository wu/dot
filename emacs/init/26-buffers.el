;;; 26-buffers.el --- buffer naming and the buffer list  -*- lexical-binding: t; -*-

;; With one buffer per repo per filename, the default `main.go<2>' says
;; nothing; `forward' names them api/main.go and worker/main.go.
(setq uniquify-buffer-name-style 'forward)

;; ibuffer over the default buffer menu: it groups, and it operates on marks.
(global-set-key [remap list-buffers] #'ibuffer)

(setq ibuffer-expert t                       ; don't confirm every kill
      ibuffer-show-empty-filter-groups nil)

;; Group by git repo, which for a workspace of repos is the grouping that
;; matches how the buffers are actually organized.  ibuffer-vc is not in
;; `package-selected-packages'; add it there and this starts working, and
;; until then ibuffer just stays ungrouped.
(add-hook 'ibuffer-hook
          (lambda ()
            (when (fboundp 'ibuffer-vc-set-filter-groups-by-vc-root)
              (ibuffer-vc-set-filter-groups-by-vc-root)
              (unless (eq ibuffer-sorting-mode 'alphabetic)
                (ibuffer-do-sort-by-alphabetic)))))
