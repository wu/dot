;;; 30-magit.el --- magit windows and multi-repo status  -*- lexical-binding: t; -*-

(global-set-key "\C-cm" 'magit-status)


;; --- windows ---

;; Status replaces the buffer in the selected window rather than splitting it,
;; so `winner-undo' steps back to whatever was being edited there.  Diffs, logs
;; and commit buffers still get their own windows -- they are meant to be read
;; alongside the status buffer.  `q' also restores the pre-magit layout.
(setq magit-display-buffer-function
      #'magit-display-buffer-same-window-except-diff-v1
      magit-bury-buffer-function #'magit-restore-window-configuration)


;; --- diffs ---

;; Syntax-highlight hunks instead of painting every line one flat red or green.
;; Magit runs the hunk text through `diff-syntax-fontify-props' in a buffer
;; visiting the real file, so both sides get their major mode's faces.
;;
;; `magit-diff-specify-hunk-foreground' has to be nil before magit-diff.el is
;; loaded -- its faces bake the value in at defface time -- otherwise magit's
;; own foreground covers the syntax colors.  Setting it here is early enough:
;; `package-initialize' only installs autoloads, so magit stays unloaded until
;; the first `magit-status'.
;;
;; With the foregrounds gone, the side of a line is carried by its background
;; and by the leading +/-, which `magit-diff-use-indicator-faces' colors
;; separately from the rest of the line.
(setq magit-diff-specify-hunk-foreground nil
      magit-diff-use-indicator-faces t)

;; Fontification is synchronous, so `all' can stall on a large diff.  `t' does
;; the hunk at point instead, as it becomes current.  `T' in the diff transient
;; toggles this per buffer, `t' toggles word-level refinement next to it.
(setq magit-diff-fontify-hunk 'all
      magit-diff-refine-hunk 'all)

;; Magit's stock hunk backgrounds assume the flat foreground we just turned
;; off: at #335533 under #1c1c1c they are strong enough to fight wombat's
;; syntax colors for the text.  Dim them to a tint that still reads as "green
;; side" out of the corner of the eye but lets the text win, and push the
;; saturation the backgrounds gave up into the +/- indicators.
;;
;; The `-highlight' variants are the current section, so each stays a step
;; stronger than its plain form.  `magit-diff-context-highlight' comes down
;; too: at its stock grey20 it would outweigh the tints and read as the
;; changed lines.  Not `custom-set-faces' -- .emacs keeps the one Custom
;; block, and these are meant to live with the settings above.
(with-eval-after-load 'magit-diff
  (dolist (spec '((magit-diff-added                . "#1b2a1b")
                  (magit-diff-added-highlight      . "#20321f")
                  (magit-diff-removed              . "#2b1c1c")
                  (magit-diff-removed-highlight    . "#3a2222")
                  (magit-diff-context-highlight    . "#262626")
                  (magit-diff-base                 . "#2e2b18")
                  (magit-diff-base-highlight       . "#3b3720")))
    (set-face-attribute (car spec) nil :background (cdr spec)))
  (set-face-attribute 'magit-diff-added-indicator   nil :foreground "#78c078")
  (set-face-attribute 'magit-diff-removed-indicator nil :foreground "#e08a8a")

  ;; Word-level refinement is not magit's own painting: `magit-diff-refine-hunk'
  ;; hands the hunk to `diff-refine-hunk', which overlays these faces, so the
  ;; table above never reached them.  Stock is #22aa22/#aa2222 -- saturated
  ;; enough to be the brightest thing on screen once the lines under them are
  ;; tinted.  Keep refinement a clear step above its line, no further.
  ;;
  ;; The `smerge-' pair is the same colors on the conflict-resolution side.
  ;; Which pair `diff-refine-hunk' reaches for has moved between Emacs
  ;; versions, and both are defined by the time magit-diff is loaded (it
  ;; requires diff-mode and smerge-mode), so set both and stay consistent
  ;; whichever is in play.
  (set-face-attribute 'diff-refine-added     nil :background "#2f5030")
  (set-face-attribute 'diff-refine-removed   nil :background "#5c2b2b")
  (set-face-attribute 'smerge-refined-added   nil :background "#2f5030")
  (set-face-attribute 'smerge-refined-removed nil :background "#5c2b2b"))


;; --- ediff ---

;; `e' in a magit buffer (`magit-ediff-dwim') diffs the thing at point: on a
;; file in the status buffer that is index vs worktree, on a commit it is that
;; commit against its parent.  Ediff works on buffers visiting the real files,
;; so syntax highlighting is just the major mode's, and the two revisions sit
;; side by side rather than interleaved.
;;
;; These two are global ediff settings, not magit's -- `M-x ediff-files' picks
;; them up as well.
;;
;; Ediff's own default splits A above B, and on a graphical display puts the
;; control panel in a frame of its own.  Horizontal split gives the actual
;; side-by-side; `plain' keeps the control panel a window in the same frame,
;; which is what makes `q' land back where you started.
(setq ediff-split-window-function #'split-window-horizontally
      ediff-window-setup-function #'ediff-setup-windows-plain)

;; Two panes, old on the left and new on the right.  On an uncommitted hunk
;; `magit-ediff-dwim' otherwise runs `magit-ediff-stage', which is a
;; three-buffer session -- HEAD, index, worktree -- because it exists to stage
;; and unstage through ediff, not to read a diff.  Showing on hunks instead
;; picks `magit-ediff-show-unstaged' (index vs worktree) or
;; `magit-ediff-show-staged' (HEAD vs index) by which section point is in.
;;
;; Staging that way is still one key further out: `E s' runs
;; `magit-ediff-stage' explicitly.
(setq magit-ediff-dwim-show-on-hunks t)

;; The other three-pane path: a stash records what was staged at the time, and
;; a third buffer is how that gets shown.  Off, so stashes read as the same
;; before/after as everything else.
(setq magit-ediff-show-stash-with-index nil)

;; Nothing to do for the way back: `magit-ediff-quit-hook' already holds
;; `magit-ediff-restore-previous-winconf', so quitting ediff restores the
;; window configuration magit was showing beforehand.

;; Ediff's faces are its own -- neither magit's nor diff-mode's -- and predate
;; dark themes: several name colors like "pale green" and "Grey" outright, and
;; pin a `:foreground' with them, which is what buries the buffer's own syntax
;; colors.  Clearing the foreground back to `unspecified' is half the fix; the
;; other half is sizing the backgrounds to a #1c1c1c frame the way the magit
;; ones above are sized.
;;
;; Three tiers, and they have to stay ordered by how much attention each wants:
;; `even'/`odd' are every *other* differing section, so they sit barely above
;; the frame background; `current' is the one `n'/`p' moved to; `fine' is the
;; changed words inside it, the only thing allowed to be loud.  A is the left
;; buffer, B the right, C a merge result, Ancestor the merge base -- kept on
;; the same red/green/yellow scheme as the magit diffs.
(with-eval-after-load 'ediff-init
  (pcase-dolist (`(,face ,bg)
                 '((ediff-even-diff-A         "#262626")
                   (ediff-even-diff-B         "#262626")
                   (ediff-even-diff-C         "#262626")
                   (ediff-even-diff-Ancestor  "#262626")
                   (ediff-odd-diff-A          "#2b2b2b")
                   (ediff-odd-diff-B          "#2b2b2b")
                   (ediff-odd-diff-C          "#2b2b2b")
                   (ediff-odd-diff-Ancestor   "#2b2b2b")
                   (ediff-current-diff-A        "#4a2626")
                   (ediff-current-diff-B        "#28402a")
                   (ediff-current-diff-C        "#3b3720")
                   (ediff-current-diff-Ancestor "#2e2b18")
                   (ediff-fine-diff-A         "#6e3232")
                   (ediff-fine-diff-B         "#356b3a")
                   (ediff-fine-diff-C         "#5c5426")
                   (ediff-fine-diff-Ancestor  "#4a4520")))
    (set-face-attribute face nil
                        :background bg
                        :foreground 'unspecified
                        :extend t)))

;; `ediff-highlight-all-diffs' nil is the blunter version of the even/odd rows
;; above: only the current difference gets a face at all.  Left on, because
;; the dimmed tiers still show at a glance how much of the file moved.


;; --- repolist ---

;; Status of every repo in a workspace at once.  A workspace is any directory
;; holding a `.workspace' marker file; the repos are its immediate subdirs,
;; plus the workspace itself when it is also a repo.  Scoping is
;; per-invocation, so `C-c M' in ~/projects/keyopx shows only the keyopx
;; repos, and elsewhere shows only that workspace's.

(defun my/magit-workspace-root ()
  "Nearest enclosing directory containing a `.workspace' file.
Falls back to `default-directory' when there is no marker above us."
  (file-name-as-directory
   (expand-file-name
    (or (locate-dominating-file default-directory ".workspace")
        default-directory))))

(defun my/magit-workspace-repos (root)
  "ROOT and each immediate subdir of it that is a git repo, as (DIR . 0).
Depth 0 because `magit-list-repos-1' stops at the first directory containing
a .git and never descends -- so a workspace that is itself a repo (with its
sub-repos gitignored) would otherwise report only itself."
  (mapcar (lambda (dir) (cons dir 0))
          (seq-filter
           (lambda (dir) (file-readable-p (expand-file-name ".git" dir)))
           (cons (directory-file-name root)
                 (seq-filter #'file-directory-p
                             (directory-files
                              root t directory-files-no-dot-files-regexp t))))))

(defun my/magit-list-repositories-here (&optional root)
  "List the repos in the current workspace.
With a prefix arg, prompt for ROOT instead of locating the marker."
  (interactive (list (when current-prefix-arg
                       (read-directory-name "Repo root: "))))
  (let* ((root (or root (my/magit-workspace-root)))
         (dirs (my/magit-workspace-repos root))
         (magit-repository-directories dirs))
    (unless dirs
      (user-error "No git repos in %s" root))
    (magit-list-repositories)
    ;; `g' in the repolist buffer re-reads the variable, and by then the `let'
    ;; above is gone -- pin the scope to the buffer so refresh stays put.
    (when-let* ((buf (get-buffer "*Magit Repositories*")))
      (with-current-buffer buf
        (setq-local magit-repository-directories dirs)))))

;; B<U/B>U compare against the last fetch, not the live remote; `f' in the
;; repolist buffer freshens them.
(setq magit-repolist-columns
      '(("Name"    25 magit-repolist-column-ident nil)
        ("Flag"     4 magit-repolist-column-flag
         ((:right-align t) (:help-echo "N=untracked U=unstaged S=staged")))
        ("B<U"      3 magit-repolist-column-unpulled-from-upstream
         ((:right-align t) (:help-echo "Upstream changes not in branch")))
        ("B>U"      3 magit-repolist-column-unpushed-to-upstream
         ((:right-align t) (:help-echo "Local changes not in upstream")))
        ("Branch"  15 magit-repolist-column-branch nil)
        ("Path"    99 magit-repolist-column-path nil)))

(global-set-key "\C-cM" 'my/magit-list-repositories-here)
