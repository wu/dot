unset zle_bracketed_paste

# history
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000

# PATH related settings
export PATH=/usr/local/go/bin:$PATH
export GOPATH=~/go

# custom prompt
autoload -Uz vcs_info
fpath=(~/dot/.zsh $fpath)
autoload -U promptinit && promptinit
prompt wu

# aliases
alias g="git"
alias k="kubectl"

