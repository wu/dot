unset zle_bracketed_paste
HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=10000
export PATH=/usr/local/go/bin:$PATH
export GOPATH=~/go


fpath=(~/dot/.zsh $fpath)
autoload -U promptinit && promptinit
prompt wu


