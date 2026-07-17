# host-specific settings, keyed on the short hostname
[[ -r ~/dot/hosts/zprofile.${HOST%%.*} ]] && source ~/dot/hosts/zprofile.${HOST%%.*}
