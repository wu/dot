;;; 28-dired.el --- directory browsing  -*- lexical-binding: t; -*-

;; --- stock dired ---
;; These stand on their own: if dirvish below is not installed, dired is still
;; the better version of itself.

;; Visiting a directory reuses the dired buffer instead of leaving the old one
;; behind, so browsing a tree no longer ends with a dozen buffers named after
;; directories.  Emacs 28+.
(setq dired-kill-when-opening-new-dired-buffer t)

;; Permissions, owner and size are noise when the buffer is being used to find
;; a file.  `(' toggles them back in the buffers where they matter.
(add-hook 'dired-mode-hook #'dired-hide-details-mode)

;; With two dired windows open, copy and rename default to the other window's
;; directory -- the one thing a two-pane file manager does that dired does not
;; do out of the box.
(setq dired-dwim-target t)

;; Re-read a directory that changed underneath us, rather than showing a stale
;; listing until `g'.
(setq dired-auto-revert-buffer t)

;; `dired-jump' is already on C-x C-j: it is autoloaded from dired.el as of
;; Emacs 28, so dired-x is not needed for it.

;; --- ls ---
;; `--group-directories-first' is a GNU coreutils switch.  macOS ships BSD ls,
;; where coreutils installs a GNU one as `gls'; without either, asking for the
;; switch makes every listing fail, so the stock switches stay.
(cond
 ((executable-find "gls")
  (setq insert-directory-program "gls"
        dired-listing-switches "-alh --group-directories-first"))
 ((memq system-type '(darwin berkeley-unix))
  ;; BSD ls has no `--dired', and dired warns on every listing if it asks.
  (setq dired-use-ls-dired nil))
 (t
  (setq dired-listing-switches "-alh --group-directories-first")))

;; --- dirvish ---
;; Dirvish is dired underneath -- same keymap, same commands -- with a listing
;; that reuses one session and a project sidebar.  Until it is installed, every
;; setting above still applies and this block does nothing.
;; `dirvish-side' and its follow mode live in a separate file of the package;
;; requiring it by name beats relying on the autoloads being where we expect.
(if (not (and (require 'dirvish nil t)
              (require 'dirvish-side nil t)
              (require 'dirvish-subtree nil t)))
    (message "dirvish not installed: M-x package-install-selected-packages")

  ;; Take over dired itself rather than living alongside it, so `C-x d',
  ;; `dired-jump' and the sidebar are all the same thing.
  (dirvish-override-dired-mode 1)

  ;; The sidebar points at the current buffer's project and, with follow mode
  ;; on, re-points itself whenever the current buffer moves to another one --
  ;; which is exactly what makes it wander off the project as soon as a file
  ;; from elsewhere is opened.  Left off: the workspace decides which project
  ;; the tab is about (29-workspaces.el), and the sidebar stays where it was
  ;; opened.  `C-c t' re-points it deliberately.
  (dirvish-side-follow-mode -1)

  ;; File icons are `vscode-icon' rather than `nerd-icons': bundled PNGs, so
  ;; there is no font to install on each machine.  The cost is that they need a
  ;; graphical frame.  Dirvish draws an attribute without checking its package
  ;; is there, so the attribute is only listed once the package is installed.
  ;;
  ;; The size is in pixels, and one taller than the text would stretch every
  ;; row.  Any size works when Emacs can scale images: the icons are scaled
  ;; down from the 128 px set, whatever dirvish's docstring says about 23.
  (let ((icons (and (locate-library "vscode-icon") '(vscode-icon))))
    ;; The side window is narrow: the VC state in the fringe, the icon and the
    ;; expansion arrow are all that fit.  A full-frame session has room for
    ;; more.
    (setq dirvish-side-attributes `(vc-state ,@icons subtree-state)
          dirvish-attributes `(vc-state ,@icons subtree-state collapse file-size)
          dirvish-side-width 32
          dirvish-vscode-icon-size 18))

  ;; --- grouping the listing by file type ---
  ;; `dirvish-emerge-mode' is the mode from the screenshots: it splits a
  ;; listing into titled groups.  A group is (NAME . (TYPE . VALUE)) where TYPE
  ;; is `predicate', `extensions' or `regex'.  The predicates that ship are
  ;; recent-files-2h, recent-files-today, directories, files, symlinks and
  ;; executables; whatever matches nothing lands in a trailing group.
  (setq dirvish-emerge-groups
        '(("Recent"    (predicate . recent-files-today))
          ("Documents" (extensions "pdf" "epub" "md" "org" "txt" "doc" "docx"))
          ("Images"    (extensions "png" "jpg" "jpeg" "gif" "svg" "webp" "heic"))
          ("Video"     (extensions "mp4" "mkv" "mov" "webm" "avi"))
          ("Audio"     (extensions "mp3" "m4a" "flac" "wav" "ogg"))
          ("Archives"  (extensions "zip" "tar" "gz" "bz2" "xz" "7z" "dmg"))))

  ;; The mode itself is left off: it is buffer-local, and grouping a source
  ;; tree is rarely the point.  M-x dirvish-emerge-mode turns it on where it is
  ;; wanted, M-e below edits the groups and can write them into .dir-locals.el
  ;; (`dirvish-emerge-groups' is marked safe as a local variable), and adding
  ;; `dirvish-emerge-mode' to `dirvish-setup-hook' would turn it on everywhere.

  ;; --- keys inside a dirvish buffer ---
  ;; `dirvish-mode-map' inherits `dired-mode-map', so these reach dirvish
  ;; buffers and nothing else.  M-t is where the preview lives: it toggles the
  ;; full-frame layout (`dirvish-default-layout' -- parent pane, listing,
  ;; preview pane), which the narrow side window deliberately does without.
  (keymap-set dirvish-mode-map "TAB" #'dirvish-subtree-toggle)
  (keymap-set dirvish-mode-map "M-t" #'dirvish-layout-toggle)
  (keymap-set dirvish-mode-map "M-e" #'dirvish-emerge-menu)

  ;; Clicking a directory splits the frame, because dired binds <mouse-2> to
  ;; `dired-mouse-find-file-other-window' and its `follow-link' entry sends a
  ;; plain mouse-1 click on a filename to that same command.  Dirvish's mouse
  ;; command expands a directory in place and leaves files opening as before,
  ;; so rebinding <mouse-2> is enough to cover both buttons.
  ;;
  ;; `dirvish-mode-map' inherits `dired-mode-map' and is the map dirvish
  ;; installs in its buffers, so the change stops there.
  (keymap-set dirvish-mode-map "<mouse-2>" #'dirvish-subtree-toggle-or-open)

  ;; C-c plus a plain letter is the space reserved for users (20-editing.el).
  ;; Upstream suggests the C-x t prefix, which is `tab-prefix-map' in Emacs
  ;; 27+, so it is not used here.
  (global-set-key (kbd "C-c t") #'dirvish-side))
