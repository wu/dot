;;; 90-llm.el --- local llama.cpp: inline completion and commit messages  -*- lexical-binding: t; -*-

;; One llama.cpp server backs both features below.  It serves an
;; instruction-tuned chat model (gemma-4-26B-A4B-it) rather than a FIM-trained
;; coder model, so both clients talk to /v1/chat/completions.
;;
;; llama-server ignores the :model field and serves whatever was loaded, so the
;; name here only affects what shows up in prompts and mode lines.

(defvar my/llama-host "localhost:1234"
  "Host:port of the local llama.cpp server.")

(defvar my/llama-model "gemma-4-26b-a4b-it"
  "Name reported to the OpenAI-compatible endpoints.")

;; The two clients want different shapes of the same address: minuet takes a
;; full endpoint, llm takes the base path and appends the command itself.
(defun my/llama-endpoint ()
  "URL of the local chat-completions endpoint."
  (format "http://%s/v1/chat/completions" my/llama-host))

(defun my/llama-base-url ()
  "Base URL of the local server, up to but excluding the command."
  (format "http://%s/v1/" my/llama-host))

;; Packages are installed by hand (see 10-package.el), so every block below
;; degrades to a no-op rather than an error on a machine that lacks them.


;; --- minuet: inline completion ---

(when (require 'minuet nil t)
  ;; Not `openai-fim-compatible': that posts a prompt/suffix pair to
  ;; /v1/completions and needs a model trained with infill tokens, which an
  ;; instruction-tuned Gemma does not have.  The chat provider asks for the
  ;; completion in a system prompt instead, which any -it model can answer.
  (setq minuet-provider 'openai-compatible)

  ;; `plist-put' returns a new list head when the key is absent instead of
  ;; mutating in place, so assign its result rather than calling it for effect.
  (dolist (kv `((:end-point . ,(my/llama-endpoint))
                (:api-key    . ,(lambda () "dummy"))
                (:model      . ,my/llama-model)))
    (setq minuet-openai-compatible-options
          (plist-put minuet-openai-compatible-options (car kv) (cdr kv))))

  (add-hook 'prog-mode-hook #'minuet-auto-suggestion-mode)

  ;; Bound in `minuet-active-mode-map', not globally: that map is live only
  ;; while a suggestion is on screen, so M-y keeps being `yank-pop' everywhere
  ;; else.
  (define-key minuet-active-mode-map (kbd "M-y") #'minuet-accept-suggestion)
  (define-key minuet-active-mode-map (kbd "M-e") #'minuet-dismiss-suggestion))


;; --- magit-gptcommit: commit messages from the staged diff ---

;; Driven by the `llm' package, not gptel -- magit-gptcommit reads
;; `magit-gptcommit-llm-provider' and ignores any other client's config.
;; `make-llm-openai-compatible' lives in llm-openai, which plain `llm' does not
;; pull in on its own.
(when (and (require 'magit-gptcommit nil t)
           (require 'llm-openai nil t))
  (setq magit-gptcommit-llm-provider
        (make-llm-openai-compatible
         ;; Base path only: llm appends "chat/completions" to this itself, so a
         ;; full endpoint here would resolve to a doubled path.
         :url (my/llama-base-url)
         :chat-model my/llama-model
         ;; Unauthenticated locally; the slot just has to be non-nil.
         :key "dummy"))

  ;; The stock `magit-gptcommit-prompt-one-line' asks for "a single line, no
  ;; more than 50 characters" and closes with "[label]: [summary]", which is why
  ;; it never produces a body.  The whole prompt is one plain string, so replace
  ;; it wholesale.
  ;;
  ;; It reaches the model as (format magit-gptcommit-prompt diff): %s is where
  ;; the staged diff lands, and any other literal % must be written %%.
  (setq magit-gptcommit-prompt
        "You are an expert programmer writing a Git commit message.
You have carefully reviewed every file diff included in this commit.

First, choose the most appropriate label for the changes:
build, chore, ci, docs, feat, fix, perf, refactor, style, test.

Write a subject line, then a body.

Subject line:
- Format it as [label]: [summary]
- Keep it under 50 characters
- Use the imperative tense (e.g. 'Add logging' not 'Added logging')
- Do not end it with a period

Body:
- Separate it from the subject with one blank line
- Hard-wrap it at 72 columns
- Explain what changed and why it changed, not how
- Use '-' bullets when the commit covers several independent changes
- Omit the body only when the change is genuinely trivial

Do not use backticks anywhere in the response.

THE FILE DIFFS:
%s

Now write the commit message.")

  ;; The diff is truncated to this many tokens before it is interpolated, so a
  ;; large staged change silently reaches the model as a prefix of itself.
  (setq magit-gptcommit-max-token 4096)

  ;; Entries in the message history are stamped when stored and expire 16s later
  ;; by default, which a 26B model on a real diff never beats -- a local run
  ;; takes over a minute.  Expiry does not lose the message (the finder returns
  ;; it on the way past), but it empties the history before
  ;; `magit-gptcommit--update-section-with-latest-message' reads it, so the
  ;; status section stops refreshing at the end of a run.  Nothing here depends
  ;; on messages aging out.
  (setq magit-gptcommit-message-timeout nil)

  ;; Deliberately not `magit-gptcommit-mode': that hooks
  ;; `magit-status-sections-hook' and fires a request whenever a status buffer
  ;; refreshes with something staged.  This call only appends a "GPT Commit"
  ;; group to the `magit-commit' transient, so nothing is sent until asked.
  ;;
  ;;   c G  generate      c q  generate and commit in one step
  ;;
  (magit-gptcommit-status-buffer-setup)

  ;; `magit-gptcommit-generate' only implements the `magit-status-mode' branch:
  ;; its `with-editor-mode' and `magit-diff-mode' branches are upstream TODOs
  ;; that log and return, so calling it from a commit buffer silently does
  ;; nothing.  Drive it from the repo's status buffer instead, then accept the
  ;; result back here once it lands.
  (defun my/magit-gptcommit--status-buffer ()
    "The `magit-status-mode' buffer for this buffer's repository, or nil.
Not `magit-get-mode-buffer': that matches a buffer's recorded
`magit--default-directory' against `magit-toplevel' with `equal', so one
repository reached by two spellings of its path never matches itself.
Git hands the commit buffer the truename of COMMIT_EDITMSG -- which is
why `magit-commit-message-buffer' binds `find-file-visit-truename' -- so
a checkout behind a symlink is exactly that case.  Resolve both sides."
    (when-let* ((top (magit-toplevel))
                (topdir (file-name-as-directory (file-truename top))))
      (seq-find
       (lambda (buf)
         (with-current-buffer buf
           (and (eq major-mode 'magit-status-mode)
                magit--default-directory
                (equal topdir
                       (file-name-as-directory
                        (file-truename magit--default-directory))))))
       (buffer-list))))

  (defcustom my/magit-gptcommit-timeout 120
    "Seconds to wait for a generated commit message before giving up."
    :type 'integer
    :group 'magit-gptcommit)

  (defun my/magit-gptcommit-generate-here ()
    "Generate a commit message and insert it into this commit buffer.
Runs `magit-gptcommit-generate' in the repository's status buffer, since
that is the only branch it implements, then waits for the result and
accepts it here."
    (interactive)
    (unless (magit-toplevel)
      (user-error "Not inside a Git repository"))
    (let* ((commit-buf (current-buffer))
           (status-buf (or (my/magit-gptcommit--status-buffer)
                           ;; No status buffer open for this repo.  Make one,
                           ;; and put the windows back so the commit buffer
                           ;; keeps the frame.
                           (save-window-excursion
                             (magit-status-setup-buffer (magit-toplevel)))))
           (deadline (+ (float-time) my/magit-gptcommit-timeout))
           timer)
      (with-current-buffer status-buf
        (magit-gptcommit-generate))
      ;; Generation is asynchronous and announces completion only by writing
      ;; `magit-gptcommit--last-message' into the repository-local cache --
      ;; there is no completion hook to hang this on.  `magit-gptcommit--insert'
      ;; deletes that entry before it starts, so its reappearance means *this*
      ;; run finished rather than an earlier one.  Until then
      ;; `magit-gptcommit-commit-accept' is a silent no-op: its `when-let' just
      ;; falls through, which is why accepting too early looked like nothing
      ;; happening.
      (setq timer
            (run-with-timer
             1 1
             (lambda ()
               (cond
                ((not (buffer-live-p commit-buf))
                 (cancel-timer timer))
                ((> (float-time) deadline)
                 (cancel-timer timer)
                 (message "Gave up waiting for a commit message after %ss"
                          my/magit-gptcommit-timeout))
                (t
                 ;; Read with the same key it was written with.  The callback
                 ;; that stores the message runs in the status buffer, so it is
                 ;; filed under that buffer's `magit--default-directory'; the
                 ;; commit buffer has none and falls back to `magit-toplevel',
                 ;; and the two only agree if git spells the repository the same
                 ;; way in both.  When they disagree the commit buffer's lookup
                 ;; returns nil and `magit-gptcommit-commit-accept' quietly does
                 ;; nothing.
                 (when-let* ((msg (with-current-buffer status-buf
                                    (magit-repository-local-get
                                     'magit-gptcommit--last-message))))
                   (cancel-timer timer)
                   (with-current-buffer commit-buf
                     ;; File it under this buffer's key too, so the package's
                     ;; own accept -- which handles the comment ring and
                     ;; `magit-gptcommit-process-commit-message-function' -- can
                     ;; find it and do the insertion properly.
                     (magit-repository-local-set
                      'magit-gptcommit--last-message msg)
                     (magit-gptcommit-commit-accept)
                     ;; Accept also needs `magit-commit-message-buffer' to
                     ;; resolve, and returns silently when it does not.  We know
                     ;; which buffer we want, so fall back to inserting it.
                     (if (string-empty-p
                          (string-trim (or (git-commit-buffer-message) "")))
                         (progn
                           (save-excursion
                             (goto-char (point-min))
                             (insert (string-trim msg) "\n"))
                           (message "Commit message inserted directly"))
                       (message "Commit message inserted")))))))))
      (message "Generating commit message...")))

  (with-eval-after-load 'git-commit
    (define-key git-commit-mode-map (kbd "C-c C-g")
                #'magit-gptcommit-commit-accept)
    (define-key git-commit-mode-map (kbd "C-c M-g")
                #'my/magit-gptcommit-generate-here)))

;(setq magit-gptcommit-debug t)

