;;; 10-package.el --- package archives and load path  -*- lexical-binding: t; -*-

;; Loads before every module that needs a package to be on the load path.

(require 'package)
(setq package-user-dir (expand-file-name "emacs/libs" my/dot-dir))
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(package-initialize)

;; Packages are listed in `package-selected-packages', in ~/.emacs.
;; To install them on a new machine, or after adding one:
;;   M-x package-refresh-contents
;;   M-x package-install-selected-packages
