#!/usr/bin/env bash
# symlink the dotfiles in this repo into $HOME
set -euo pipefail

repo=$(cd "$(dirname "$0")" && pwd)

link() {
  local src=$1 dst=$2
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    ln -s "$src" "$dst"
    echo "linked  $dst -> $src"
  elif [ -L "$dst" ] && [ "$(readlink -f "$dst")" = "$(readlink -f "$src")" ]; then
    echo "ok      $dst"
  else
    echo "warning: $dst exists and is not a symlink to $src" >&2
  fi
}

# .zshrc and .zprofile expect the repo itself at ~/dot
link "$repo" "$HOME/dot"

for src in "$repo"/.*; do
  name=$(basename "$src")
  case $name in
    .|..|.git|.claude|.zsh) continue ;;
  esac
  link "$src" "$HOME/$name"
done
