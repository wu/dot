;;; 20-editing.el --- editor-wide behavior, history and keys  -*- lexical-binding: t; -*-

;; --- session history ---

;; `desktop-save' defaults to `ask-if-new', which means a single "no" at the
;; exit prompt leaves no desktop file to restore from.  `check-pid' loads a
;; desktop whose lock belongs to a process that is gone, which is what a crash
;; or a killed daemon leaves behind.
(setq desktop-save t
      desktop-load-locked-desktop 'check-pid)
(desktop-save-mode 1)

;; Desktop restores file buffers but no minibuffer history: savehist is what
;; makes C-x b and M-x remember across sessions, and what vertico sorts by.
(setq history-length 500)
(savehist-mode 1)

;; Recently visited files, independent of whether the desktop loaded.
(setq recentf-max-saved-items 200)
(recentf-mode 1)
;; `package-user-dir' is set in 10-package.el, which loads first.
(add-to-list 'recentf-exclude (regexp-quote package-user-dir))

;; --- backups and auto-saves ---

;; Keep edited directories clean: `foo~' backups and `#foo#' auto-saves live
;; under ~/.emacs.d rather than beside the file they belong to.
;;
;; `user-emacs-directory' rather than a literal path, so this follows Emacs to
;; ~/.config/emacs if this config is ever installed there instead.
(let ((backup-dir (expand-file-name "backups/" user-emacs-directory))
      (auto-save-dir (expand-file-name "auto-saves/" user-emacs-directory)))
  ;; Emacs makes the backup directory on demand but not the auto-save one, so
  ;; make both here.  The second argument means "parents, and no error if it
  ;; already exists", which is the case on every start after the first.
  (make-directory backup-dir t)
  (make-directory auto-save-dir t)

  ;; The alist maps a file-name regexp to the directory its backups go in;
  ;; "." matches every file.
  (setq backup-directory-alist `(("." . ,backup-dir)))

  ;; Auto-saves take a regexp plus a replacement instead.  The trailing t is
  ;; UNIQUIFY: the name is built from the buffer's whole path with the
  ;; separators turned into `!', so ~/a/foo.go and ~/b/foo.go get one
  ;; auto-save file each instead of fighting over a shared #foo.go#.
  (setq auto-save-file-name-transforms `((".*" ,auto-save-dir t))))

;; Lock files (the `.#foo' symlinks) are deliberately left in place: they are
;; how a second Emacs -- or another editor -- notices the file is already being
;; edited, which only works if the lock sits next to the file.  They are
;; removed as soon as the buffer is saved or reverted.

;; --- line numbers ---

;; The in-buffer line number column, for code buffers only.  `prog-mode-hook'
;; reaches go-ts-mode and every other language mode, since they all derive from
;; `prog-mode'; `global-display-line-numbers-mode' would also number magit,
;; dired and help buffers, where the column is noise.
;;
;; Not to be confused with `line-number-mode', on by default, which is the
;; mode-line readout of the current line.
;;
;; `display-line-numbers-width-start' sizes the column from the buffer's line
;; count when the mode turns on, so the code does not shift right the first
;; time you scroll past line 99.
(setq display-line-numbers-width-start t)
(add-hook 'prog-mode-hook #'display-line-numbers-mode)

;; Push the numbers well below the body text -- the default `line-number' face
;; is bright enough to compete with the code it is labelling.
;;
;; This has to run after `load-theme' (00-core.el, which loads first): loading a
;; theme applies that theme's own faces and would overwrite an earlier setting.
;; `line-number-current-line' inherits `line-number', so it dims along with it.
(set-face-attribute 'line-number nil :foreground "grey40")

;; --- prompts ---

;; The prompts that want a spelled-out "yes<RET>" come from `yes-or-no-p',
;; which Emacs uses where a mistyped `y' would cost something -- killing a
;; modified buffer, deleting files in dired, quitting with unsaved work.  This
;; makes them all take a single `y' or `n' instead, the same as `y-or-n-p'.
;;
;; This is the supported switch rather than aliasing `yes-or-no-p' to
;; `y-or-n-p': `yes-or-no-p' reads the variable itself, so callers that go
;; through it -- including ones that check which of the two they are using --
;; keep working, and `read-answer' follows along through its own
;; `read-answer-short' default of `auto'.
(setq use-short-answers t)


;; --- misc ---

;; Undo/redo window layouts: C-c <left> / C-c <right>.
(winner-mode 1)

(setq-default show-trailing-whitespace t)

(global-set-key [(meta +)] 'align-regexp)

;; Commenting is stock: `C-x C-;' (`comment-line') toggles the current line or
;; the lines a region spans, and `M-;' (`comment-dwim') appends a trailing
;; comment or toggles an active region.  Both are bound by default.
;;
;; Use `M-;' when a region is live.  `comment-line' rounds the region out to
;; whole lines, so a selection ending at column 0 -- what C-n leaves behind --
;; also comments the line below it.  `comment-dwim' passes the bounds through
;; untouched and stops where the selection does.
;;
;; This alias exists only because `C-x C-;' is an awkward chord.  `C-c' plus a
;; plain letter is the space reserved for users, so no major mode can shadow
;; it -- unlike `C-c C-c', which is major-mode territory and was only ever
;; reaching us in modes that left it unbound.
(global-set-key (kbd "C-c c") #'comment-line)
