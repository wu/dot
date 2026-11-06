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


;; --- the region ---

;; Type or yank over an active region and it is replaced, rather than the new
;; text landing alongside it.  Without this a `C-y' over a selection appends,
;; and clearing the selection first with `C-w' pushes it onto the kill ring, so
;; the yank that follows hands back the text just cut instead of the text that
;; was meant to replace it.
;;
;; The replaced text is deleted, not killed: the kill ring -- and with it the
;; clipboard entry being yanked -- is left untouched.  `undo' is what brings the
;; replaced text back, not `C-y'.
;;
;; Commands opt in through a `delete-selection' property, so this reaches
;; third-party yanks too: consult sets it on `consult-yank-pop', bound to M-y in
;; 25-completion.el.
;;
;; Backspace over a region already worked this way -- `delete-active-region'
;; defaults to t, and deletes rather than kills for the same reason -- so this
;; is that rule extended to insertion.
(delete-selection-mode 1)


;; --- misc ---

;; Undo/redo window layouts: C-c <left> / C-c <right>.
;;
;; `tab-bar-history-mode' rather than `winner-mode', which held these keys
;; before.  Winner keeps one ring per frame -- `winner-ring-size' is documented
;; in those words -- and knows nothing about tabs.  With a tab per project
;; (29-workspaces.el) a tab switch is itself a window configuration change, so
;; the ring ends up interleaving every workspace's layouts and an undo in one
;; project can restore another project's windows into it.
;;
;; This mode keeps the history in the tab, swapping it in and out as tabs are
;; selected, so undo stays inside the workspace it was invoked in.  The
;; `tab-bar-mode' docstring recommends it over winner for exactly this reason,
;; and it binds the same two keys, so nothing downstream changes.
;;
;; The depth is `tab-bar-history-limit', 10 against winner's 200 -- but 10 per
;; tab rather than 10 for the whole frame.  Raise it here if that bites.
;;
;; tab-bar.el carries no autoload cookies, so require it before the call.
(require 'tab-bar)
(tab-bar-history-mode 1)

;; Let the last key of a sequence repeat on its own: after C-c <left>, a bare
;; <left> steps back again, <right> forward.  `tab-bar-history-repeat-map'
;; declares those two with `:repeat t', which is what `repeat-mode' reads.
;;
;; This is global, not a tab-bar feature -- it activates every repeat map that
;; ships with Emacs, so C-x o, C-x {, C-x ^ and the undo commands all gain the
;; same one-key continuation.  `repeat-exit-key' or M-x repeat-mode backs it
;; out if that turns out to be more than was wanted.
(repeat-mode 1)

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
;; plain letter is the space reserved for users, so no major mode can shadow it.
(global-set-key (kbd "C-c c") #'comment-line)

;; `C-c C-c' toggles the active region in code buffers.  `comment-dwim' rather
;; than `comment-or-uncomment-region', which with no active region silently
;; acts on whatever lies between point and a stale mark.
;;
;; This key is major-mode territory, so it is bound from the hooks and not
;; globally: a global binding loses to every mode that claims the key.  The
;; hooks run after the mode has set up its map, so this deliberately replaces
;; those claims -- e.g. `python-shell-send-buffer', `sh-case', and `conf-mode's
;; `conf-colon-mode', which silently reinterprets the file.
;;
;; `local-set-key' writes to the major mode's map, which minor-mode maps outrank,
;; so with-editor's and edit-indirect's C-c C-c "finish" keeps working in these
;; buffers.  Text modes stay out of the list: there the key means send or commit.
;; `yaml-ts-mode' derives from `text-mode', and `conf-mode' from neither.
(defun my/bind-comment-key ()
  "Bind \\`C-c C-c' to `comment-dwim' in this major mode's keymap."
  (local-set-key (kbd "C-c C-c") #'comment-dwim))
(dolist (hook '(prog-mode-hook conf-mode-hook yaml-ts-mode-hook))
  (add-hook hook #'my/bind-comment-key))
