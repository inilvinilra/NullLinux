[[ $- != *i* ]] && return

autoload -Uz compinit && compinit
autoload -Uz colors && colors

HISTFILE=~/.zsh_history
HISTSIZE=10000
SAVEHIST=20000
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_SPACE
setopt SHARE_HISTORY
setopt AUTO_CD
setopt CORRECT
setopt EXTENDED_GLOB
setopt NO_BEEP

bindkey -e
bindkey '^[[A' history-search-backward
bindkey '^[[B' history-search-forward
bindkey '^[[3~' delete-char
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line

_null_git_branch() {
  local branch
  branch="$(git symbolic-ref --short HEAD 2>/dev/null)"
  [[ -n "$branch" ]] && printf ' (%s)' "$branch"
}

setopt PROMPT_SUBST
PROMPT='%F{8}[%f%F{7}%n%f%F{8}@%f%F{7}null%f%F{8} %f%F{4}%~%f%F{3}$(_null_git_branch)%f%F{8}]%f%(?.%F{7}.%F{1})$%f '
RPROMPT='%F{8}%T%f'

alias ls='ls --color=auto'
alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'
alias update='sudo pacman -Syu'
alias install='sudo pacman -S'
alias search='pacman -Ss'
alias remove='sudo pacman -Rns'
alias cleanup='sudo pacman -Sc'
alias listening='ss -tulnp | grep LISTEN'
alias openports='sudo nmap -sT -O localhost'
alias pubip='curl -s ifconfig.me && echo'
alias localip='ip -4 addr show scope global | grep -oP "inet \K[\d.]+"'
alias serve='python -m http.server'
alias clip='xclip -selection clipboard'
alias hex='xxd'
alias rot13='tr "A-Za-z" "N-ZA-Mn-za-m"'
alias b64e='base64'
alias b64d='base64 -d'
alias sha256='sha256sum'
alias md5='md5sum'
alias genpass='openssl rand -base64 32'
alias httpresp='curl -o /dev/null -s -w "%{http_code}\n"'

export EDITOR=vim
export VISUAL=vim
export PAGER=less
export LESS='-R'

if [[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi
if [[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

if command -v fastfetch >/dev/null 2>&1 && [[ -z "$NULLLINUX_FETCHED" ]]; then
  export NULLLINUX_FETCHED=1
  fastfetch
fi
