;;; 60-macos.el --- inherit the shell's PATH on macOS  -*- lexical-binding: t; -*-

;; Loads after 50-go.el so the shell's PATH wins over the ~/go/bin entry
;; prepended there.
(when (memq window-system '(mac ns))
  (if (fboundp 'exec-path-from-shell-initialize)
      (exec-path-from-shell-initialize)
    (message "exec-path-from-shell not installed: M-x package-install-selected-packages")))
