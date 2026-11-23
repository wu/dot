# Bracketed paste keeps a multi-line paste as one editable buffer instead of
# running it line by line. Only disable it where the terminal can't handle the
# escape sequences (Emacs shell-mode, dumb terminals); vterm/eat support it.
if [[ $TERM == dumb || ( -n $INSIDE_EMACS && $INSIDE_EMACS != *vterm* && $INSIDE_EMACS != *eat* ) ]]; then
    unset zle_bracketed_paste
fi

setopt				\
    NO_hup			\
    auto_pushd			\
    bsd_echo			\
    chase_links			\
    correct			\
    extended_history		\
    glob_complete		\
    hist_ignore_all_dups	\
    hist_ignore_space		\
    hist_reduce_blanks		\
    hist_save_no_dups		\
    hist_verify			\
    inc_append_history		\
    list_packed			\
    list_types			\
    long_list_jobs		\
    numeric_glob_sort		\
    prompt_cr			\
    prompt_subst		\
    pushd_ignore_dups		\

# history
HISTFILE=~/.zshhistory
HISTSIZE=10000
SAVEHIST=10000

# treat / as a word separator, so alt+f/alt+b stop at each path component
WORDCHARS=${WORDCHARS//\/}

# custom prompt
autoload -Uz vcs_info
fpath=(~/dot/.zsh $fpath)
autoload -U promptinit && promptinit
prompt wu

# zsh completions
fpath=(~/dot/zsh-completion $fpath)
autoload -U compinit && compinit

# aliases
alias g="git"
alias k="kubectl"
alias ll="ls -la"
# toggle bracketed paste in the current shell (takes effect at the next prompt)
alias paste-brack-off="unset zle_bracketed_paste"
alias paste-brack-on="zle_bracketed_paste=(\$'\e[?2004h' \$'\e[?2004l')"

# emacsclient, backgrounded and disowned so the shell stays free
emacs() { emacsclient "$@" &! }
alias ec="emacs"
