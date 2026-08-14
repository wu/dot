;;; 29-workspaces.el --- one workspace per project  -*- lexical-binding: t; -*-

;; A stock `tab-bar' tab is only a saved window configuration.  It has no
;; notion of a project, and every tab draws on one global buffer list, so
;; visiting a file from elsewhere inside a project's tab quietly dissolves it:
;; the tab renames itself after the new buffer, `project-current' starts
;; answering with a different project, and C-x b still offers every buffer in
;; the session.  Switching away and back returns whatever was left behind
;; rather than the project.
;;
;; tabspaces ties the two built-ins together -- one tab per project.el project,
;; with a buffer list scoped to the tab and a session file per project holding
;; the window layout.  It is `tab-bar' and `project' underneath, so C-x t and
;; C-x p keep working and this stays configuration rather than a second system.

;; Everything below has to be in place before the mode turns on:
;; `tabspaces-project-switch-opens-workspace' is read when it is enabled, and
;; re-enabling the mode is what picks up a later change.
(if (not (require 'tabspaces nil t))
    (message "tabspaces not installed: M-x package-install-selected-packages")

  ;; --- what a workspace holds ---

  ;; Remap `switch-to-buffer' to the workspace-filtered version.  Without this
  ;; the isolation exists but nothing consults it -- the default leaves
  ;; `tabspaces-switch-to-buffer' as something you call by name.
  (setq tabspaces-use-filtered-buffers-as-default t)

  ;; Left at their defaults: `tabspaces-include-buffers' keeps *scratch* in
  ;; every workspace, and `tabspaces-remove-to-default' sends a buffer removed
  ;; from a workspace back to the "Default" tab instead of killing it.

  ;; A new tab opens on *scratch* rather than inheriting whatever was current
  ;; when it was created, so a fresh workspace starts empty instead of showing
  ;; a file that belongs to the workspace it was made from.
  (setq tab-bar-new-tab-choice "*scratch*")

  ;; --- keeping the tab pointed at its project ---

  ;; `tabspaces-project-fallback-to-tab' is t by default and is the fix for the
  ;; original complaint: a buffer belonging to no project -- *scratch*, an org
  ;; file elsewhere on disk -- makes `project-current' return nil, so project
  ;; commands prompt or wander off.  With it they fall back to the tab's
  ;; project.  A buffer that is itself inside another project still wins; the
  ;; tab never overrides it.

  ;; Route the stock C-x p p through tabspaces, so there is one way to open a
  ;; project and it creates or reuses that project's workspace.  Left off, C-x
  ;; p p and tabspaces' own entry point (C-c TAB o) do different things.
  (setq tabspaces-project-switch-opens-workspace t)

  ;; --- keys ---
  ;; The command map hangs off `tabspaces-keymap-prefix', C-c TAB by default,
  ;; left alone here.  It does not collide with C-c t (`dirvish-side',
  ;; 28-dired.el): TAB and t are distinct keys in a GUI frame, though not in a
  ;; terminal, where TAB and C-i are the same character.
  ;;
  ;;   C-c TAB s   switch to or create a workspace by name
  ;;   C-c TAB o   open a project as a workspace
  ;;   C-c TAB b   switch buffer within this workspace
  ;;   C-c TAB t   switch to a buffer and the workspace holding it
  ;;   C-c TAB n   rename this workspace      C-c TAB d   close it
  ;;   C-c TAB r   drop this buffer from the workspace
  ;;   C-c TAB w   list workspaces

  ;; --- sessions ---

  ;; A session records each tab's file buffers, its dired/eshell/shell buffers
  ;; and its window configuration, written on `kill-emacs-hook'.  Saving
  ;; (`tabspaces-session') is on by default.  Note that compilation buffers and
  ;; REPLs do not survive; windows showing them come back on *scratch*.

  ;; Restore after desktop rather than during init.
  ;;
  ;; `tabspaces-session-auto-restore' restores at the moment `tabspaces-mode'
  ;; is enabled, which is here, during init.  `desktop-read' runs later, from
  ;; an `after-init-hook' lambda that desktop.el installs at load time -- and a
  ;; frameset carries each frame's window state, taken from the root window
  ;; (frameset.el) and put back the same way.  So desktop replays the layout of
  ;; whichever tab was current when it was saved, sidebar included, over the
  ;; top of what tabspaces had just restored.  That is why exactly one tab came
  ;; back wrong: the frameset only holds the frame's current configuration.
  ;;
  ;; Filtering it out is not on offer.  `frameset-filter-alist' reaches frame
  ;; parameters only, and the window state is a separate element of the
  ;; frameset; `frameset-restore's predicate can drop a whole frame but not its
  ;; window state.  So run the restore behind desktop instead, by appending to
  ;; the same hook.  tabspaces owns tabs and windows in this config, and this
  ;; is what gives it the last word.
  ;;
  ;; `tabspaces--restore-session-on-startup' is the mode's own startup entry
  ;; point rather than `tabspaces-restore-session' directly: it creates the
  ;; session file when missing, defers under a daemon until the first client
  ;; frame, and demotes errors, which matters on a hook that nothing else
  ;; wraps.
  ;;
  ;; The nil also reaches `tabspaces-open-or-create-project-and-workspace',
  ;; which consults this variable before restoring a per-project session on
  ;; demand.  That path is already dead while sessions are global (below), but
  ;; it would need revisiting alongside a switch back to per-project files.
  (setq tabspaces-session-auto-restore nil)
  (add-hook 'after-init-hook #'tabspaces--restore-session-on-startup t)

  ;; Close the workspaces the restore placeholder leaves behind.
  ;;
  ;; `tabspaces-restore-session' parks the frame on "*tabspaces--placeholder*"
  ;; at the top of each iteration.  The first of those lands in the tab Emacs
  ;; started in, which the cleanup loop at the end never visits -- it only
  ;; walks the workspaces it restored.  `tab-bar-tab-name-current' then names
  ;; that tab after the placeholder, `tabspaces-save-session' saves it as a
  ;; workspace like any other, and the next restore brings it back under an
  ;; explicit name while stranding a fresh one.  So they accumulate, one more
  ;; at the head of the tab bar on every restart.
  (defun my/tabspaces-drop-placeholder-workspaces ()
    "Close workspaces named after the tabspaces restore placeholder."
    (dolist (name (tabspaces--list-tabspaces))
      (when (string-match-p "tabspaces--placeholder" name)
        (tab-bar-close-tab-by-name name))))

  (add-hook 'after-init-hook #'my/tabspaces-drop-placeholder-workspaces t)

  ;; Key dirvish sessions to the tab's name rather than its position.
  ;;
  ;; `dirvish--scopes' stamps each dirvish buffer with
  ;; `tab-bar--current-tab-index' (dirvish.el), and `dirvish-winbuf-change-h'
  ;; kills the session's buffers and rebuilds whenever the stamp stops matching
  ;; the current tab.  Closing a tab shifts the index of every tab after it, so
  ;; dirvish decides all of those sidebars have moved and tears them down --
  ;; which is what breaks the other tabs' sidebars when one workspace is
  ;; closed.
  ;;
  ;; A name is stable across closing and reordering.  It has to be interned
  ;; rather than left a string: `dirvish--get-session' compares the stamp with
  ;; `eq', which two equal strings fail.  Renaming a workspace now looks like a
  ;; tab change and rebuilds its sidebar, which is the rarer event.
  (defun my/dirvish-tab-scope ()
    "Return the current tab's name as a symbol, for `dirvish--scopes'."
    (intern (or (cdr (assq 'name (tab-bar--current-tab))) "")))

  (with-eval-after-load 'dirvish
    (setq dirvish--scopes
          (plist-put (copy-sequence dirvish--scopes)
                     :tab #'my/dirvish-tab-scope)))

  ;; Sidebars are recreated rather than restored.  A side window does not
  ;; survive `window-state-put' and the sidebar's buffer name carries a
  ;; timestamp, so the session deliberately records neither (see the save
  ;; advice below).  Opening a fresh one per workspace afterwards reaches the
  ;; same place.
  ;;
  ;; This works because dirvish already scopes its sessions by tab:
  ;; `dirvish--scopes' maps :tab to `tab-bar--current-tab-index' (dirvish.el),
  ;; and `dirvish--get-session' will only match a session whose buffer belongs
  ;; to the current tab.  So each workspace gets its own side session on its
  ;; own directory instead of all of them sharing one.
  ;;
  ;; Only workspaces that resolve to a project get one.  A non-project tab
  ;; would otherwise open a sidebar on whatever `default-directory' happened to
  ;; be, which is rarely anything to look at.
  (defun my/tabspaces-open-sidebars ()
    "Open a dirvish sidebar in each project workspace."
    (when (and (fboundp 'dirvish-side)
               (fboundp 'dirvish-side--session-visible-p))
      (let ((current (tab-bar--current-tab-index)))
        (dolist (name (tabspaces--list-tabspaces))
          (tab-bar-select-tab-by-name name)
          (when (and (project-current)
                     (not (dirvish-side--session-visible-p)))
            ;; `dirvish-side' selects the sidebar it opens, and the workspace
            ;; should be left on the window the restore selected.
            (save-selected-window (dirvish-side))))
        ;; `tab-bar-select-tab' counts tabs from 1, the index from 0.
        (tab-bar-select-tab (1+ current)))))

  ;; Appended behind the restore above, so the workspaces exist by the time
  ;; this walks them.
  (add-hook 'after-init-hook #'my/tabspaces-open-sidebars t)

  ;; Everything goes in the one file named by `tabspaces-session-file'
  ;; (~/.emacs.d/tabsession.el), which is what the startup restore reads.
  ;;
  ;; A non-nil `tabspaces-session-project-session-store' selects per-project
  ;; session files instead, and that splits the save in two: project tabs each
  ;; get their own file, everything else goes to the global one.  Startup only
  ;; ever reads the global file, so project workspaces then come back one at a
  ;; time, as each project is opened, rather than all at once on restart.
  ;; Having the whole set of tabs back after a restart is worth more here than
  ;; restoring them lazily.
  ;;
  ;; nil is the "traditional" setting per `tabspaces--save-session-smart',
  ;; though the defcustom's :type does not enumerate it.  It also keeps session
  ;; files out of the repos: the `project' setting drops a
  ;; `.NAME-tabspaces-session.el' in every project root to gitignore.
  (setq tabspaces-session-project-session-store nil)

  ;; Nor a project-todo.org written into the root of every project opened as a
  ;; workspace, which is the other default that writes into the repo.
  (setq tabspaces-initialize-project-with-todo nil)

  ;; Two session systems restoring at once is the one real conflict here.
  ;; `desktop-save-mode' (20-editing.el) restores frames, and a frame carries
  ;; its tabs, so leaving that alone means desktop and tabspaces each rebuild
  ;; the tab list from a different record.
  ;;
  ;; Turning off `desktop-restore-frames' settles that, but it throws out the
  ;; frame's position and size on screen along with the tabs -- they travel in
  ;; the same frameset.  Drop just the one parameter instead: `tab-bar' puts a
  ;; `tabs' entry in `frameset-filter-alist' (tab-bar.el), and `:never' stops
  ;; that parameter being saved or restored while the rest of the frame comes
  ;; back as before.  So desktop keeps the geometry and the file buffers, and
  ;; tabspaces owns tabs, windows and per-workspace buffer lists.
  ;;
  ;; `buffer-list', `buried-buffer-list' and `buffer-predicate' are already
  ;; `:never' in the stock alist (frameset.el), which is why the per-workspace
  ;; buffer lists were never at risk from the frameset in the first place.
  ;;
  ;; `setf' on the existing entry rather than pushing a second one: tab-bar
  ;; pushes its own at load time, and `assq' would keep finding that one.
  (setf (alist-get 'tabs frameset-filter-alist) :never)

  ;; `tab-bar-mode' otherwise only switches itself on the first time a tab is
  ;; created, which leaves the mode off during the session restore above.
  (tab-bar-mode 1)
  (tabspaces-mode 1)

  ;; --- upstream workaround: `tabspaces-remove-buffer' deletes windows ---
  ;; Two separate faults with one cause: the function chooses between burying a
  ;; buffer and deleting the window showing it, and gets the choice wrong in
  ;; both directions.
  ;;
  ;; Interactively (C-c TAB r, C-c TAB R) it decides on `one-window-p', which
  ;; counts the dirvish side window (28-dired.el).  With the sidebar open and a
  ;; single file window that sends it down the delete branch, onto the frame's
  ;; main window, which Emacs refuses -- "Attempt to delete main window of
  ;; frame", window.el.
  ;;
  ;; During a restore it deletes a window that was just restored.
  ;; `tabspaces-restore-session' parks the frame on "*tabspaces--placeholder*"
  ;; at the top of every iteration, and that lands in the workspace restored on
  ;; the previous pass -- after its layout had already been put back.  The
  ;; cleanup loop at the end then removes the placeholder from each workspace in
  ;; turn, and the branch that finds it still displayed calls `delete-window'.
  ;; So every restored workspace except the last one processed comes back a
  ;; window short, which is why the tab that was current at exit is the only one
  ;; to survive intact.
  ;;
  ;; Bury in both cases.  The `delete-window' rebinding stays scoped to this one
  ;; function rather than wrapping the whole restore, so `window-state-put' --
  ;; which is what rebuilds the layouts to begin with -- is left alone.
  (defvar my/tabspaces-restoring nil
    "Non-nil while `tabspaces-restore-session' is running.")

  (defun my/tabspaces-note-restoring (orig &rest args)
    "Bind `my/tabspaces-restoring' while ORIG runs with ARGS."
    (let ((my/tabspaces-restoring t))
      (apply orig args)))

  (defun my/tabspaces-bury-instead-of-delete (orig &rest args)
    "Bury rather than delete a window that should not be deleted.
Applied as advice around `tabspaces-remove-buffer'; ORIG is called with ARGS."
    (cl-letf* ((delete (symbol-function 'delete-window))
               ((symbol-function 'delete-window)
                (lambda (&optional window)
                  (let ((w (window-normalize-window window)))
                    (if (or my/tabspaces-restoring
                            (eq w (window-main-window (window-frame w))))
                        (bury-buffer)
                      (funcall delete w))))))
      (apply orig args)))

  (advice-add 'tabspaces-restore-session :around #'my/tabspaces-note-restoring)
  (advice-add 'tabspaces-remove-buffer :around #'my/tabspaces-bury-instead-of-delete)

  ;; --- upstream workaround: keep the sidebar out of saved sessions ---
  ;; Sessions store `(window-state-get nil t)', which defaults to the frame's
  ;; root window and so takes in the dirvish side window (28-dired.el).
  ;; Neither half of that survives a restart:
  ;;
  ;;   - `window-state-put' with a nil window "create[s] a new window before
  ;;     putting STATE into it" (window.el).  It rebuilds an ordinary window
  ;;     tree; the `window-side' parameter is carried across but the side
  ;;     window structure is not, so the sidebar comes back as a normal window.
  ;;
  ;;   - the sidebar's buffer is named " *SIDE :: dot :: 08/13/26|22:27:10" --
  ;;     leading space, and a timestamp.  dirvish mints a new name every
  ;;     session, so a recorded name can never be matched again.
  ;;
  ;; The two compound: the side structure collapses, the sidebar's dired buffer
  ;; is restored as an ordinary one, and it takes the first window slot from
  ;; whatever file was there.
  ;;
  ;; Save from `window-main-window' instead, which is the window tree with side
  ;; windows excluded.  The sidebar then never enters the session and the main
  ;; layout restores on its own; `C-c t' brings the sidebar back.  With no side
  ;; window open, `window-main-window' is the root window and this changes
  ;; nothing.
  (defun my/tabspaces-save-main-window-only (orig &rest args)
    "Save window state from the main window, excluding side windows.
Applied as advice around the tabspaces session savers; ORIG is called
with ARGS."
    (cl-letf* ((state-get (symbol-function 'window-state-get))
               ((symbol-function 'window-state-get)
                (lambda (&optional window writable)
                  (funcall state-get (or window (window-main-window)) writable))))
      (apply orig args)))

  ;; All four savers reach `window-state-get', and the interactive ones are
  ;; reachable without going through the `kill-emacs-hook' entry point.
  (dolist (fn '(tabspaces-save-session
                tabspaces-save-all-project-sessions
                tabspaces-save-non-project-tabs
                tabspaces-save-current-project-session))
    (advice-add fn :around #'my/tabspaces-save-main-window-only))

  ;; --- consult ---
  ;; C-x b is `consult-buffer' (25-completion.el), which builds its candidates
  ;; from its own sources and so does not follow the `switch-to-buffer' remap
  ;; above.  Consult has a hook for exactly this: every builtin source draws
  ;; its buffers from `consult-buffer-list-function', so pointing that at the
  ;; workspace scopes C-x b, C-x p b and the rest in one setting.
  ;;
  ;; This is narrower than upstream's suggested recipe, which defines a whole
  ;; extra source -- that predates the hook.  It also lights up
  ;; `consult-source-other-buffer', which enables itself as soon as this
  ;; variable is not `buffer-list' and puts every buffer outside the workspace
  ;; behind its "o" narrowing key.
  ;;
  ;; `tabspaces--buffer-list' is private, but it is the only reader of the
  ;; frame parameter tabspaces maintains, and upstream points at its siblings
  ;; for the same purpose.  Set inside the eval-after-load so consult's own
  ;; defcustom does not overwrite it at load time.
  (with-eval-after-load 'consult
    (setq consult-buffer-list-function #'tabspaces--buffer-list))

  ;; --- the file row ---
  ;; A second row on the tab bar, under the row of project tabs, listing the
  ;; files open in the workspace the selected tab holds.  Clicking a name
  ;; switches to it.
  ;;
  ;; `tab-line-mode' is the built-in that shows a bar of buffers, and it is not
  ;; what is wanted here: the tab line belongs to a window, so a split draws it
  ;; once per window.  The tab bar belongs to the frame -- one bar across the
  ;; top however the windows are arranged -- so the row goes there instead.
  ;;
  ;; The bar is not a fixed number of rows.  Redisplay concatenates the items'
  ;; captions into one string and draws it a line at a time
  ;; (`build_desired_tab_bar_string' and `display_tab_bar_line', xdisp.c), so a
  ;; caption holding a newline ends the row and starts another, and
  ;; `auto-resize-tab-bars' (t by default) grows the bar to fit.  A long file
  ;; list wraps onto a third row the same way.  `tab-bar-truncate', a C
  ;; variable, would draw the first row only; it defaults to nil.

  ;; `tabspaces--buffer-list' is the workspace's buffers, the same list C-x b
  ;; is filtered through above.  Sorted because it filters `buffer-list',
  ;; which is ordered by recency: unsorted, the row would reshuffle itself on
  ;; every buffer switch.  Filtered on `buffer-file-name', which is what drops
  ;; *scratch*, the sidebar, magit and the rest -- this row is about files.
  (defun my/tab-bar-workspace-files ()
    "Return the current workspace's file buffers, ordered by name."
    (sort (seq-filter #'buffer-file-name (tabspaces--buffer-list))
          (lambda (a b) (string< (buffer-name a) (buffer-name b)))))

  ;; An entry in `tab-bar-format' returns either a string or a list of
  ;; menu-items (tab-bar.el).  Items are what the tabs themselves are made of,
  ;; and they are clickable, so each file is one: its caption is the label, its
  ;; binding is the command run on a click, and `:help' is the tooltip -- the
  ;; full path, since the label is only the buffer name.
  ;; Nil when the workspace holds no files, so a fresh tab on *scratch* keeps
  ;; the bar one row tall instead of growing an empty one.
  (defun my/tab-bar-format-workspace-files ()
    "Produce a tab-bar row of the files open in the current workspace."
    ;; `window-buffer' of the frame's selected window rather than
    ;; `current-buffer': that is the buffer whose file the row should point at,
    ;; and it is right whatever happens to be current when redisplay gets round
    ;; to building the bar.
    (let ((files (my/tab-bar-workspace-files))
          (current (window-buffer (frame-selected-window)))
          (i 0))
      (when files
        (append
         ;; Ends the row of tabs.  What follows is drawn on the next one.
         '((files-row menu-item "\n" ignore))
         (mapcan
          (lambda (buf)
            (setq i (1+ i))
            `((,(intern (format "file-%i" i))
               menu-item
               ;; Brackets rather than the padding spaces on the file being
               ;; edited, so the two states differ in their text and not only
               ;; in a face.  The label is the same width either way, so the
               ;; row does not shift as the marker moves.
               ,(let ((current-p (eq buf current)))
                  (propertize (concat my/tab-bar-padding
                                      (if current-p "[" " ")
                                      (buffer-name buf)
                                      (if current-p "]" " ")
                                      my/tab-bar-padding)
                              'face (if current-p
                                        'my/tab-bar-file-current
                                      'my/tab-bar-file)))
               ,(lambda () (interactive) (switch-to-buffer buf))
               :help ,(buffer-file-name buf))))
          files)))))

  ;; Appended rather than inserted: the newline has to come after everything
  ;; else in the format, or those items are the ones that move to the second
  ;; row.  For the same reason the row cannot follow
  ;; `tab-bar-format-align-right', which measures every item after it to work
  ;; out where "right" starts -- worth remembering if a clock is ever added.
  ;;
  ;; `add-to-list' rather than appending to the value, so re-evaluating this
  ;; file while tweaking the row does not stack up a copy per evaluation.
  ;;
  ;; The function reads the selected frame's workspace, so each frame and each
  ;; tab shows its own files with no per-frame state of our own.
  (add-to-list 'tab-bar-format #'my/tab-bar-format-workspace-files t)

  ;; `tab-bar-auto-width' spreads the bar's width evenly across the tabs, and
  ;; works out what is left over by concatenating the captions of every item it
  ;; will not resize and subtracting their pixel width from the frame's
  ;; (`tab-bar-auto-width', tab-bar.el).  The file row is made of exactly such
  ;; items, so a workspace with a few files open would push the project tabs
  ;; down to `tab-bar-auto-width-min'.  Off: tabs are then as wide as their
  ;; names, which is why they want padding of their own (see the tab-name
  ;; padding at the end of this file).
  (setq tab-bar-auto-width nil)

  ;; Redisplay rebuilds the tab bar only when it believes the bar could have
  ;; changed: windows or buffers changed, or a mode line was forced to update
  ;; (`update_tab_bar', xdisp.c, whose comment names `force-mode-line-update'
  ;; as the supported way to ask for a recompute).  Selecting a tab qualifies,
  ;; which is why the highlight is right on arriving at a tab and then stops
  ;; moving as files are switched underneath it.
  ;;
  ;; The request has to be made before redisplay begins, which is why the
  ;; window-change hooks are the wrong place for it: `redisplay_internal' calls
  ;; `prepare_menu_bars' -- and so `update_tab_bar' -- early, runs the window
  ;; change functions late (xdisp.c:17573), and then clears `update_mode_lines'
  ;; and `windows_or_buffers_changed' at the end of the same pass
  ;; (xdisp.c:18151).  A flag raised from those hooks is therefore wiped before
  ;; anything reads it, so the row never gets its rebuild.
  ;;
  ;; `post-command-hook' runs before the redisplay that follows the command, so
  ;; the flag is still standing when `update_tab_bar' looks.
  ;;
  ;; Only when the buffer actually changed: `force-mode-line-update' with t
  ;; also sets `prevent_redisplay_optimizations_p', and paying that on every
  ;; keystroke is how a config makes a large file feel slow.  The last buffer
  ;; is kept in a frame parameter rather than a variable so that two frames
  ;; showing different buffers do not mask each other's changes.
  (defun my/tab-bar-refresh-file-row ()
    "Rebuild the tab bar when the selected window's buffer has changed."
    (let ((buffer (window-buffer (frame-selected-window))))
      (unless (eq buffer (frame-parameter nil 'my/tab-bar-file-row-buffer))
        (set-frame-parameter nil 'my/tab-bar-file-row-buffer buffer)
        (force-mode-line-update t))))

  (add-hook 'post-command-hook #'my/tab-bar-refresh-file-row)

  ;; Keep that frame parameter out of desktop's frameset, the same way and for
  ;; the same reason as the `tabs' parameter above: its value is a buffer
  ;; object, which has no readable printed representation, and desktop would be
  ;; writing one into ~/.emacs.d/.emacs.desktop to choke on at startup.
  (setf (alist-get 'my/tab-bar-file-row-buffer frameset-filter-alist) :never))


;;; --- the tab bar itself ---

;; Outside the tabspaces guard: `tab-bar-mode' turns itself on the first time a
;; tab is made, so the bar can show up whether or not the package loaded.
;;
;; On a dark background the stock faces separate the selected tab from the rest
;; by `grey40' against `grey20' (tab-bar.el), which is not much of a signal
;; when the point of the tab bar here is knowing which project you are in.
;; Lavender marks the selected tab, and it marks it in the text rather than in
;; a block behind it -- so the bar stays flat and the two rows say "here" the
;; same way, the file row with its brackets and the tabs with their colour.
;;
;; A filled block was the first attempt and it swallowed the close button:
;; `tab-bar-tab-name-format-close-button' appends " x" outside the padding, so
;; on the selected tab it landed at the very edge of the lavender in the same
;; dark ink as the name.  Coloured text puts the x back in plain sight.
;;
;; `:box nil' drops the stock released-button border, which would otherwise
;; draw the outline of a block this no longer paints.
;;
;; These run after `load-theme' (00-core.el, loaded first), which is what makes
;; them stick -- a theme applies its own faces and would otherwise overwrite
;; this.  Same reason as the `line-number' tweak in 20-editing.el.
(set-face-attribute 'tab-bar nil
                    :background "#1c1c1c" :foreground "#d0d0d0" :box nil)

;; Both tab faces take the bar's own background, so neither draws a block and
;; the difference between them is entirely in the ink: lavender for the tab you
;; are in, a muted grey for the others -- the same grey the file row gives the
;; files you are not editing.
;;
;; Weight stays `normal': bold is wider than regular in Anonymous Pro
;; (00-core.el), so bolding the selected tab reflows every tab after it and the
;; bar shifts on each switch.  The colour is doing the work anyway.
(set-face-attribute 'tab-bar-tab nil
                    :background "#1c1c1c" :foreground "#c8b6e6"
                    :weight 'normal :box nil)

(set-face-attribute 'tab-bar-tab-inactive nil
                    :background "#1c1c1c" :foreground "#808080"
                    :weight 'normal :box nil)

;; The mouse-hover face is Emacs 31; on 30 it does not exist and
;; `set-face-attribute' would signal.  Without this, hovering a tab reverts to
;; the stock grey block.  A faint lift of the background is enough to show the
;; tab is live under the pointer now that nothing else in the bar is filled.
(when (facep 'tab-bar-tab-highlight)
  (set-face-attribute 'tab-bar-tab-highlight nil
                      :background "#2f2f2f" :foreground "#e6dcf5" :box nil))

;; With `tab-bar-auto-width' off -- it had to go for the file row to fit -- a
;; tab is exactly as wide as its name, so one name ends where the next begins
;; and the row reads as crowded.  Pad the names.
;;
;; `tab-bar-tab-name-format-functions' (Emacs 30) is a pipeline: each stage
;; takes the name so far and returns the next.  Padding goes at the front, so
;; `tab-bar-tab-name-format-face' -- the stage that puts the tab's face on the
;; whole string -- covers the padding too, which is what would matter again if
;; the tabs ever go back to a filled background.
;;
;; The other knob, if this wants further tuning: `tab-bar-close-button-show'
;; governs the " x" the close button appends after the padding on the right of
;; every tab, and nil drops it -- along with the misclick that closes a
;; workspace.
(defvar my/tab-bar-padding "  "
  "Padding put on each side of a label in the tab bar.
Read by `my/tab-bar-pad-tab-name' for the tabs and by
`my/tab-bar-format-workspace-files' for the file row, so that the two
rows stay in step.  This is the one place to widen or tighten them.")

(defun my/tab-bar-pad-tab-name (name _tab _i)
  "Pad tab NAME with `my/tab-bar-padding' on each side."
  (concat my/tab-bar-padding name my/tab-bar-padding))

(when (boundp 'tab-bar-tab-name-format-functions)
  (add-to-list 'tab-bar-tab-name-format-functions #'my/tab-bar-pad-tab-name))

;; Padding widens the coloured blocks; this is the gap between them, drawn in
;; the bar's own background.  Both are needed to stop the tabs reading as one
;; run of colour: without a gap, the selected tab's lavender sits flush against
;; its neighbour's grey no matter how roomy each block is.  `tab-bar-separator'
;; is a single space in a GUI frame by default, and a "|" on a terminal, which
;; this replaces with spaces there too -- the faces above set backgrounds, and
;; those do render on a terminal, so the blocks still read as separate without
;; the divider.
;;
;; Set unconditionally rather than under `(window-system)': with a daemon
;; (emacsclient, the aliases) init runs on the initial terminal frame, where
;; that test is nil, and the setting would never be reached for the GUI frames
;; that come later.
(setq tab-bar-separator "  ")

;; The file row (`my/tab-bar-format-workspace-files' above) gets faces of its
;; own rather than borrowing the tab faces.  Putting the lavender on both rows
;; would cost it the one thing it says -- which project this frame is in -- so
;; the row sits in greys and spends the lavender on the file being edited,
;; where it reads as "here" against the rest.
;;
;; The inactive background is the bar's own, so those names read as labels on
;; the bar rather than as a second set of tabs; the current file gets the same
;; lift the unselected tabs have above.
;;
;; `defface' rather than the `set-face-attribute' calls above: these are new
;; faces, so there is no theme setting to overwrite and nothing to sequence
;; after `load-theme'.
(defface my/tab-bar-file
  '((t :background "#1c1c1c" :foreground "#808080" :box nil))
  "Face for a file in the tab bar's file row.")

;; Flat, like the tabs above: the brackets in the label are what mark the file
;; being edited, and the colour agrees with them rather than boxing it in.
(defface my/tab-bar-file-current
  '((t :background "#1c1c1c" :foreground "#c8b6e6" :box nil))
  "Face for the file being edited, in the tab bar's file row.")
