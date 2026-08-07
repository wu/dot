;; ;;; 90-llm.el --- local llama.cpp: inline completion and commit messages  -*- lexical-binding: t; -*-

;; ;; One llama.cpp server backs both features below, now serving Qwen3.5-4B at
;; ;; Q8_0.  That model is FIM-trained -- it carries <|fim_prefix|>,
;; ;; <|fim_suffix|> and <|fim_middle|> -- so the two clients no longer want the
;; ;; same endpoint:
;; ;;
;; ;;   minuet          -> /infill              (raw completion, no chat template)
;; ;;   magit-gptcommit -> /v1/chat/completions (needs instruction following)
;; ;;
;; ;; That split matters for more than speed.  Qwen3.5 runs in thinking mode by
;; ;; default and emits a <think>...</think> block ahead of its answer, which is
;; ;; injected by the chat template.  /infill never applies a chat template, so
;; ;; inline completion sidesteps thinking entirely.  The commit-message path does
;; ;; not, and is handled at the bottom of this file.
;; ;;
;; ;; Start the server with thinking off so the chat path stays clean:
;; ;;
;; ;;   llama-server -m Qwen3.5-4B-Q8_0.gguf --port 1234 --reasoning-budget 0
;; ;;
;; ;; llama-server ignores the :model field and serves whatever was loaded, so the
;; ;; name here only affects what shows up in prompts and mode lines.

;; (defvar my/llama-host "localhost:1235"
;;   "Host:port of the local llama.cpp server.")

;; (defvar my/llama-model "qwen3.5-4b"
;;   "Name reported to the OpenAI-compatible endpoints.")

;; ;; Three shapes of the same address: llama.cpp's native infill endpoint, the
;; ;; OpenAI chat endpoint, and the base path that `llm' appends the command to.
;; (defun my/llama-infill-endpoint ()
;;   "URL of the local llama.cpp infill endpoint."
;;   (format "http://%s/infill" my/llama-host))

;; (defun my/llama-endpoint ()
;;   "URL of the local chat-completions endpoint."
;;   (format "http://%s/v1/chat/completions" my/llama-host))

;; (defun my/llama-base-url ()
;;   "Base URL of the local server, up to but excluding the command."
;;   (format "http://%s/v1/" my/llama-host))

;; (defun my/llama-strip-thinking (s)
;;   "Return S with a leading Qwen thinking block removed.
;; Belt and braces next to the server's --reasoning-budget 0: a response
;; that opens with <think> is dropped up to and including the closing tag."
;;   (let ((s (or s "")))
;;     (if (string-match "</think>" s)
;;         (string-trim (substring s (match-end 0)))
;;       (string-trim s))))

;; ;; Packages are installed by hand (see 10-package.el), so every block below
;; ;; degrades to a no-op rather than an error on a machine that lacks them.


;; ;; --- minuet: inline completion ---

;; (defun my/minuet-fim->llama-infill (req)
;;   "Rewrite minuet's OpenAI-FIM request REQ for llama.cpp's /infill endpoint.
;; Minuet builds the body for the OpenAI completions API, which carries the
;; two halves as `:prompt' and `:suffix'.  llama.cpp wants `:input_prefix'
;; and `:input_suffix', and in return assembles the prompt using the FIM
;; tokens recorded in the model itself rather than trusting the client to
;; guess them.  `:model' is dropped: the native endpoint has no use for it,
;; and llama-server serves whatever was loaded regardless.  Every other key
;; -- `:stream' and the sampling options -- is carried through untouched."
;;   (let* ((body (plist-get req :body))
;;          (out (list :input_prefix (or (plist-get body :prompt) "")
;;                     :input_suffix (or (plist-get body :suffix) ""))))
;;     (while body
;;       (let ((k (car body)) (v (cadr body)))
;;         (unless (memq k '(:prompt :suffix :model))
;;           (setq out (plist-put out k v))))
;;       (setq body (cddr body)))
;;     (plist-put req :body out)))

;; (defun my/minuet-fim-prefix (ctx)
;;   "Return the text before the cursor in CTX, and nothing else.
;; `minuet--default-fim-prompt-function' prepends two synthetic comment
;; lines naming the language and the indent style.  Those earn their place
;; in a chat prompt, where the model is being told about a file it cannot
;; see.  In a FIM prefix they are a lie about how the file starts, and a
;; model trained on real code will happily continue the pattern and write
;; more header comments.  The code carries its own language."
;;   (plist-get ctx :before-cursor))

;; (when (require 'minuet nil t)
;;   ;; Qwen3.5 is FIM-trained, so the infill path is available and is the one to
;;   ;; use: it skips the chat template, which means no system prompt to process
;;   ;; and no <think> block to wait through or strip.
;;   (setq minuet-provider 'openai-fim-compatible)

;;   ;; `plist-put' returns a new list head when the key is absent instead of
;;   ;; mutating in place, so assign its result rather than calling it for effect.
;;   (dolist (kv `((:name        . "llama.cpp")
;;                 (:end-point   . ,(my/llama-infill-endpoint))
;;                 (:api-key     . ,(lambda () "dummy"))
;;                 (:model       . ,my/llama-model)
;;                 (:transform   . ,(list #'my/minuet-fim->llama-infill))
;;                 (:template    . (:prompt my/minuet-fim-prefix
;;                                  :suffix minuet--default-fim-suffix-function))
;;                 ;; /infill is llama.cpp's own endpoint, not the OpenAI one, so
;;                 ;; its stream chunks carry `content' rather than
;;                 ;; `choices[0].text' -- the stock `minuet--openai-fim-get-text-fn'
;;                 ;; would find nothing and every completion would decode empty.
;;                 (:get-text-fn . ,(lambda (json) (plist-get json :content)))
;;                 ;; Native endpoint, so these are llama.cpp's spellings:
;;                 ;; `n_predict', not `max_tokens'.  `t_max_predict_ms' is a hard
;;                 ;; wall clock cap on generation, which is what actually keeps a
;;                 ;; completion from outstaying its welcome -- a token budget
;;                 ;; alone does not bound time.
;;                 (:optional    . (:n_predict 128
;;                                  :t_max_predict_ms 1500
;;                                  :temperature 0.2))))
;;     (setq minuet-openai-fim-compatible-options
;;           (plist-put minuet-openai-fim-compatible-options (car kv) (cdr kv))))

;;   ;; Three round trips for one suggestion made sense against a model good
;;   ;; enough to disagree with itself usefully.  For inline FIM it is three times
;;   ;; the latency for candidates nobody scrolls through.
;;   (setq minuet-n-completions 1)

;;   ;; The default 16000 is a lot of prompt to process before the first token,
;;   ;; and FIM quality falls off well before that much context helps.  Halving it
;;   ;; is the single largest latency win available here.
;;   (setq minuet-context-window 8000)

;;   ;; The 3s default is measured against hosted APIs.  A local 4B at Q8 answers
;;   ;; well inside that once the model is warm, but the first request after a
;;   ;; cold start also pays for prompt processing.
;;   (setq minuet-request-timeout 4)

;;   ;; Still no `prog-mode-hook' entry, but the reasoning has changed: a 4B at Q8
;;   ;; over /infill is fast enough that automatic suggestion is now genuinely
;;   ;; usable, where against the 26B it was not.  Left off by default because
;;   ;; that is a taste question rather than a performance one -- flip it per
;;   ;; buffer with C-c I and see whether the constant suggestions help or nag.
;;   ;;
;;   ;;   C-c i  one suggestion, here, now
;;   ;;   C-c I  toggle the automatic mode on for this buffer, when it is wanted
;;   ;;
;;   (global-set-key (kbd "C-c i") #'minuet-show-suggestion)
;;   (global-set-key (kbd "C-c I") #'minuet-auto-suggestion-mode)

;;   ;; Dropping the hook only governs buffers opened from now on.
;;   ;; `minuet--setup-auto-suggestion' adds `minuet--maybe-show-suggestion' to
;;   ;; `post-command-hook' with the buffer-local flag, so any buffer that already
;;   ;; had the mode keeps requesting until told otherwise.
;;   (defun my/minuet-auto-suggestion-off-everywhere ()
;;     "Turn `minuet-auto-suggestion-mode' off in every live buffer."
;;     (interactive)
;;     (let ((n 0))
;;       (dolist (buf (buffer-list))
;;         (with-current-buffer buf
;;           (when (bound-and-true-p minuet-auto-suggestion-mode)
;;             (minuet-auto-suggestion-mode -1)
;;             (setq n (1+ n)))))
;;       (message "Disabled minuet auto-suggestion in %d buffer(s)" n)))

;;   ;; And `desktop-save-mode' (20-editing.el) records which minor modes a buffer
;;   ;; had and switches them back on when the session is restored -- so the mode
;;   ;; would return on every restart, in every restored buffer, even with the hook
;;   ;; gone.  A nil entry here tells desktop not to restore it.
;;   (with-eval-after-load 'desktop
;;     (add-to-list 'desktop-minor-mode-table '(minuet-auto-suggestion-mode nil)))

;;   ;; Bound in `minuet-active-mode-map', not globally: that map is live only
;;   ;; while a suggestion is on screen, so M-y keeps being `yank-pop' everywhere
;;   ;; else.
;;   (define-key minuet-active-mode-map (kbd "M-y") #'minuet-accept-suggestion)
;;   (define-key minuet-active-mode-map (kbd "M-e") #'minuet-dismiss-suggestion))


;; ;; --- magit-gptcommit: commit messages from the staged diff ---

;; ;; Driven by the `llm' package, not gptel -- magit-gptcommit reads
;; ;; `magit-gptcommit-llm-provider' and ignores any other client's config.
;; ;; `make-llm-openai-compatible' lives in llm-openai, which plain `llm' does not
;; ;; pull in on its own.
;; (when (and (require 'magit-gptcommit nil t)
;;            (require 'llm-openai nil t))
;;   (setq magit-gptcommit-llm-provider
;;         (make-llm-openai-compatible
;;          ;; Base path only: llm appends "chat/completions" to this itself, so a
;;          ;; full endpoint here would resolve to a doubled path.
;;          :url (my/llama-base-url)
;;          :chat-model my/llama-model
;;          ;; Unauthenticated locally; the slot just has to be non-nil.
;;          :key "dummy"))

;;   ;; The stock `magit-gptcommit-prompt-one-line' asks for "a single line, no
;;   ;; more than 50 characters" and closes with "[label]: [summary]", which is why
;;   ;; it never produces a body.  The whole prompt is one plain string, so replace
;;   ;; it wholesale.
;;   ;;
;;   ;; It reaches the model as (format magit-gptcommit-prompt diff): %s is where
;;   ;; the staged diff lands, and any other literal % must be written %%.
;;   (setq magit-gptcommit-prompt
;;         "You are an expert programmer writing a Git commit message.
;; You have carefully reviewed every file diff included in this commit.

;; First, choose the most appropriate label for the changes:
;; build, chore, ci, docs, feat, fix, perf, refactor, style, test.

;; Write a subject line, then a body.

;; Subject line:
;; - Format it as [label]: [summary]
;; - Keep it under 50 characters
;; - Use the imperative tense (e.g. 'Add logging' not 'Added logging')
;; - Do not end it with a period

;; Body:
;; - Separate it from the subject with one blank line
;; - Hard-wrap it at 72 columns
;; - Explain what changed and why it changed, not how
;; - Use '-' bullets when the commit covers several independent changes
;; - Omit the body only when the change is genuinely trivial

;; Do not use backticks anywhere in the response.

;; THE FILE DIFFS:
;; %s

;; Now write the commit message.")

;;   ;; The diff is truncated to this many tokens before it is interpolated, so a
;;   ;; large staged change silently reaches the model as a prefix of itself.
;;   (setq magit-gptcommit-max-token 1024)

;;   ;; This path does go through the chat template, so it is the one exposed to
;;   ;; Qwen3.5's thinking mode.  --reasoning-budget 0 on the server is the real
;;   ;; fix; llama.cpp has a standing bug where enable_thinking alone does not
;;   ;; take for this family, so strip anything that gets through here too rather
;;   ;; than let a <think> block land in a commit message.  Wrapping the stock
;;   ;; function rather than replacing it keeps its narrowing, its comment
;;   ;; handling and `magit-gptcommit-commit-message-action'.
;;   (setq magit-gptcommit-process-commit-message-function
;;         (lambda (message orig-message)
;;           (magit-gptcommit--process-commit-message
;;            (my/llama-strip-thinking message) orig-message)))

;;   ;; Entries in the message history are stamped when stored and expire 16s later
;;   ;; by default, which a local run on a real diff never beats -- the 26B took
;;   ;; over a minute, and 4B is quicker but not that quick, especially if any
;;   ;; thinking survives.  Expiry does not lose the message (the finder returns
;;   ;; it on the way past), but it empties the history before
;;   ;; `magit-gptcommit--update-section-with-latest-message' reads it, so the
;;   ;; status section stops refreshing at the end of a run.  Nothing here depends
;;   ;; on messages aging out.
;;   (setq magit-gptcommit-message-timeout nil)

;;   ;; Deliberately not `magit-gptcommit-mode': that hooks
;;   ;; `magit-status-sections-hook' and fires a request whenever a status buffer
;;   ;; refreshes with something staged.  This call only appends a "GPT Commit"
;;   ;; group to the `magit-commit' transient, so nothing is sent until asked.
;;   ;;
;;   ;;   c G  generate      c q  generate and commit in one step
;;   ;;
;;   (magit-gptcommit-status-buffer-setup)

;;   ;; `magit-gptcommit-generate' only implements the `magit-status-mode' branch:
;;   ;; its `with-editor-mode' and `magit-diff-mode' branches are upstream TODOs
;;   ;; that log and return, so calling it from a commit buffer silently does
;;   ;; nothing.  Drive it from the repo's status buffer instead, then accept the
;;   ;; result back here once it lands.
;;   (defun my/magit-gptcommit--status-buffer ()
;;     "The `magit-status-mode' buffer for this buffer's repository, or nil.
;; Not `magit-get-mode-buffer': that matches a buffer's recorded
;; `magit--default-directory' against `magit-toplevel' with `equal', so one
;; repository reached by two spellings of its path never matches itself.
;; Git hands the commit buffer the truename of COMMIT_EDITMSG -- which is
;; why `magit-commit-message-buffer' binds `find-file-visit-truename' -- so
;; a checkout behind a symlink is exactly that case.  Resolve both sides."
;;     (when-let* ((top (magit-toplevel))
;;                 (topdir (file-name-as-directory (file-truename top))))
;;       (seq-find
;;        (lambda (buf)
;;          (with-current-buffer buf
;;            (and (eq major-mode 'magit-status-mode)
;;                 magit--default-directory
;;                 (equal topdir
;;                        (file-name-as-directory
;;                         (file-truename magit--default-directory))))))
;;        (buffer-list))))

;;   (defcustom my/magit-gptcommit-timeout 120
;;     "Seconds to wait for a generated commit message before giving up."
;;     :type 'integer
;;     :group 'magit-gptcommit)

;;   (defun my/magit-gptcommit-generate-here ()
;;     "Generate a commit message and insert it into this commit buffer.
;; Runs `magit-gptcommit-generate' in the repository's status buffer, since
;; that is the only branch it implements, then waits for the result and
;; accepts it here."
;;     (interactive)
;;     (unless (magit-toplevel)
;;       (user-error "Not inside a Git repository"))
;;     (let* ((commit-buf (current-buffer))
;;            (status-buf (or (my/magit-gptcommit--status-buffer)
;;                            ;; No status buffer open for this repo.  Make one,
;;                            ;; and put the windows back so the commit buffer
;;                            ;; keeps the frame.
;;                            (save-window-excursion
;;                              (magit-status-setup-buffer (magit-toplevel)))))
;;            (deadline (+ (float-time) my/magit-gptcommit-timeout))
;;            timer)
;;       (with-current-buffer status-buf
;;         (magit-gptcommit-generate))
;;       ;; Generation is asynchronous and announces completion only by writing
;;       ;; `magit-gptcommit--last-message' into the repository-local cache --
;;       ;; there is no completion hook to hang this on.  `magit-gptcommit--insert'
;;       ;; deletes that entry before it starts, so its reappearance means *this*
;;       ;; run finished rather than an earlier one.  Until then
;;       ;; `magit-gptcommit-commit-accept' is a silent no-op: its `when-let' just
;;       ;; falls through, which is why accepting too early looked like nothing
;;       ;; happening.
;;       (setq timer
;;             (run-with-timer
;;              1 1
;;              (lambda ()
;;                (cond
;;                 ((not (buffer-live-p commit-buf))
;;                  (cancel-timer timer))
;;                 ((> (float-time) deadline)
;;                  (cancel-timer timer)
;;                  (message "Gave up waiting for a commit message after %ss"
;;                           my/magit-gptcommit-timeout))
;;                 (t
;;                  ;; Read with the same key it was written with.  The callback
;;                  ;; that stores the message runs in the status buffer, so it is
;;                  ;; filed under that buffer's `magit--default-directory'; the
;;                  ;; commit buffer has none and falls back to `magit-toplevel',
;;                  ;; and the two only agree if git spells the repository the same
;;                  ;; way in both.  When they disagree the commit buffer's lookup
;;                  ;; returns nil and `magit-gptcommit-commit-accept' quietly does
;;                  ;; nothing.
;;                  (when-let* ((msg (with-current-buffer status-buf
;;                                     (magit-repository-local-get
;;                                      'magit-gptcommit--last-message))))
;;                    (cancel-timer timer)
;;                    (with-current-buffer commit-buf
;;                      ;; File it under this buffer's key too, so the package's
;;                      ;; own accept -- which handles the comment ring and
;;                      ;; `magit-gptcommit-process-commit-message-function' -- can
;;                      ;; find it and do the insertion properly.
;;                      (magit-repository-local-set
;;                       'magit-gptcommit--last-message msg)
;;                      (magit-gptcommit-commit-accept)
;;                      ;; Accept also needs `magit-commit-message-buffer' to
;;                      ;; resolve, and returns silently when it does not.  We know
;;                      ;; which buffer we want, so fall back to inserting it.
;;                      (if (string-empty-p
;;                           (string-trim (or (git-commit-buffer-message) "")))
;;                          (progn
;;                            (save-excursion
;;                              (goto-char (point-min))
;;                              (insert (string-trim msg) "\n"))
;;                            (message "Commit message inserted directly"))
;;                        (message "Commit message inserted")))))))))
;;       (message "Generating commit message...")))

;;   (with-eval-after-load 'git-commit
;;     (define-key git-commit-mode-map (kbd "C-c C-g")
;;                 #'magit-gptcommit-commit-accept)
;;     (define-key git-commit-mode-map (kbd "C-c M-g")
;;                 #'my/magit-gptcommit-generate-here)))

;; ;(setq magit-gptcommit-debug t)

