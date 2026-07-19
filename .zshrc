unset zle_bracketed_paste

setopt				\
    NO_hup			\
    auto_pushd			\
    bsd_echo			\
    chase_links			\
    correct			\
    extended_history		\
    glob_complete		\
    hist_ignore_all_dups	\
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
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

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

