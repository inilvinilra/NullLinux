[[ $- != *i* ]] && return

PS1='\[\e[0;90m\][\[\e[0;37m\]\u\[\e[0;90m\]@\[\e[0;37m\]null\[\e[0;90m\] \[\e[0;94m\]\W\[\e[0;90m\]]\[\e[0m\]\$ '

alias ll='ls -alF --color=auto'
alias la='ls -A --color=auto'
alias l='ls -CF --color=auto'
alias ls='ls --color=auto'
alias grep='grep --color=auto'
alias diff='diff --color=auto'
alias ip='ip -color=auto'
alias ports='ss -tulnp'
alias myip='curl -s ifconfig.me'

export EDITOR=vim
export VISUAL=vim
export HISTSIZE=10000
export HISTFILESIZE=20000
export HISTCONTROL=ignoredups:erasedups
