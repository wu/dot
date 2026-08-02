;;; .emacs --- loads the modules in emacs/init/  -*- lexical-binding: t; -*-

;; ~/.emacs is a symlink into the dotfiles repo (see install.sh), so resolve it
;; to locate the repo rather than hardcoding a path.
(defvar my/dot-dir
  (file-name-directory
   (file-truename (or load-file-name buffer-file-name user-init-file)))
  "Root of the dotfiles repo.")

(defvar my/init-dir (expand-file-name "emacs/init/" my/dot-dir)
  "Directory of numbered init modules, loaded in filename order.")

;; Custom rewrites `user-init-file' unless `custom-file' says otherwise, so its
;; block stays here where it can never clobber a module.
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

;; A module that signals reports and is skipped: one broken file costs one
;; feature rather than every module after it.
(dolist (file (directory-files my/init-dir t "\\`[0-9].+\\.el\\'"))
  (condition-case err
      (load (file-name-sans-extension file) nil t)
    (error
     (message "init: %s failed: %s"
              (file-name-nondirectory file)
              (error-message-string err)))))
