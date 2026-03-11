# ~/.bashrc: executed by bash(1) for non-login shells.

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# ─── History ───
HISTCONTROL=ignoreboth
shopt -s histappend
HISTSIZE=10000
HISTFILESIZE=20000

# ─── Shell options ───
shopt -s checkwinsize
shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# ─── Prompt ───
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# ─── Colors ───
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    alias grep='grep --color=auto'
    alias fgrep='fgrep --color=auto'
    alias egrep='egrep --color=auto'
fi

# ─── Aliases ───
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias ..='cd ..'
alias ...='cd ../..'
alias gs='git status'
alias gl='git log --oneline -20'
alias python=python3
alias pip=pip3

# ─── Environment ───
export EDITOR=nano
export PATH="$HOME/.local/bin:$PATH"

# ─── Bash aliases file ───
if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# ─── Bash completion ───
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# ─── Auto-cd to workspace mount (DevPod containers start SSH in $HOME) ───
if [ "$PWD" = "$HOME" ] && [ -z "${VSCODE_INJECTION:-}" ]; then
    for _ws_dir in /workspace /project; do
        if [ -d "$_ws_dir" ]; then
            cd "$_ws_dir"
            break
        fi
    done
    unset _ws_dir
fi

# ─── Activate Python venv if present ───
for venv_path in /workspace/.venv /project/.venv; do
    if [ -d "$venv_path" ]; then
        export VIRTUAL_ENV="$venv_path"
        export PATH="$VIRTUAL_ENV/bin:$PATH"
        source "$venv_path/bin/activate"
        break
    fi
done

# ─── Source custom dotfile snippets ───
for f in ~/.bashrc.d/*.sh; do [ -r "$f" ] && . "$f"; done
