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
