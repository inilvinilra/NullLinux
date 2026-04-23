#
# Null Linux live shell defaults
#

[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
