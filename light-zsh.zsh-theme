# light-zsh.zsh-theme
# light-zsh - https://github.com/InfinityUniverse0/light-zsh
# A lightweight and clean Zsh theme

# Icons
() {
    macOS_icon=$'\uf179'              # 
    folder_icon=$'\uf4d4'             # 
    terminal_icon=$'\u276f'           # ❯

    err_icon=$'\u2718'                # ✘
    root_icon=$'\uee15'               # 
    background_job_icon=$'\u2699'     # ⚙

    # Git icons
    git_branch_icon=$'\uf126'         # 
    ahead_behind_icon=$'\u21c5'       # ⇅
    ahead_icon=$'\u21b1'              # ↱
    behind_icon=$'\u21b2'             # ↲

    # Not used
    # ok_icon=$'\ue63f'                 # 
    # turn_up_icon=$'\uf148'            # 
    # turn_down_icon=$'\uf149'          # 
}

# Status:
# - was there an error
# - am I root
# - are there background jobs?
prompt_status() {
    local -a symbols

    [[ $RETVAL -ne 0 ]] && symbols+="%{%F{red}%}$err_icon"
    [[ $UID -eq 0 ]] && symbols+="%{%F{136}%}$root_icon"
    [[ $(jobs -l | wc -l) -gt 0 ]] && symbols+="%{%F{cyan}%}$background_job_icon"

    [[ -n "$symbols" ]] && echo -n "$symbols%f "
}

# Virtualenv: current working virtualenve
export VIRTUAL_ENV_DISABLE_PROMPT=1
prompt_virtualenv() {
    # if [[ -n "$VIRTUAL_ENV" && -n "$VIRTUAL_ENV_DISABLE_PROMPT" ]]; then
    if [[ -n "$VIRTUAL_ENV" ]]; then
        echo -n "(%F{136}${VIRTUAL_ENV:t:gs/%/%%}%f) "
    fi
}

# Condaenv: current working condaenv
export CONDA_CHANGEPS1=false
prompt_condaenv() {
    if [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        echo -n "(%F{green}${CONDA_DEFAULT_ENV:t:gs/%/%%}%f) "
    fi
}

# Context: user@hostname (who am I and where am I)
prompt_context() {
    if [[ "$USERNAME" != "$DEFAULT_USER" || -n "$SSH_CLIENT" ]]; then
        echo -n "%F{white}$macOS_icon%f %(!.%{%F{red}%}.)%n%f@%m "
    fi
}

# Dir: current working directory
export LSCOLORS="exfxcxdxbxegedabagacad"
export LS_COLORS="di=34:ln=35:so=32:pi=38;5;136:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

(( $+commands[gls] )) && alias ls='gls --color=auto'

prompt_dir() {
    echo -n "%F{cyan}$folder_icon %F{blue}%~%f"
}

# Git: vcs_info configuration (run once at theme load time)
setopt promptsubst
autoload -Uz vcs_info

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:*' get-revision true
zstyle ':vcs_info:*' check-for-changes true
zstyle ':vcs_info:*' stagedstr '%{%F{green}%}+'
zstyle ':vcs_info:*' unstagedstr '%{%F{136}%}M'
zstyle ':vcs_info:*' formats ' %u%c'
zstyle ':vcs_info:*' actionformats ' %u%c'

### git: Show marker (U) if there are untracked files in repository
# Make sure you have added staged to your 'formats':  %c
zstyle ':vcs_info:git*+set-message:*' hooks git-untracked

+vi-git-untracked() {
    if [[ $(git rev-parse --is-inside-work-tree 2> /dev/null) == 'true' ]] && \
        git status --porcelain | grep '??' &> /dev/null ; then
        # This will show the marker if there are any untracked files in repo.
        # If instead you want to show the marker only if there are untracked
        # files in $PWD, use:
        # [[ -n $(git ls-files --others --exclude-standard) ]] ; then
        hook_com[staged]+='%{%F{red}%}U'
    fi
}

# Git: branch/detached head, dirty status
prompt_git() {
    (( $+commands[git] )) || return
    if [[ "$(command git config --get oh-my-zsh.hide-status 2>/dev/null)" = 1 ]]; then
        return
    fi
    local PL_BRANCH_CHAR=$git_branch_icon
    local ref dirty mode repo_path branch_color

    if [[ "$(command git rev-parse --is-inside-work-tree 2>/dev/null)" = "true" ]]; then
        repo_path=$(command git rev-parse --git-dir 2>/dev/null)
        dirty=$(parse_git_dirty)
        ref=$(command git symbolic-ref HEAD 2> /dev/null) || \
        ref="◈ $(command git describe --exact-match --tags HEAD 2> /dev/null)" || \
        ref="➦ $(command git rev-parse --short HEAD 2> /dev/null)"

        branch_color=" %{%F{green}%}"  # Default to green if no dirty files
        if [[ -n $dirty ]]; then
            branch_color=" %{%F{136}%}"
        fi

        local ahead behind
        ahead=$(command git log --oneline @{upstream}.. 2>/dev/null)
        behind=$(command git log --oneline ..@{upstream} 2>/dev/null)
        if [[ -n "$ahead" ]] && [[ -n "$behind" ]]; then
            PL_BRANCH_CHAR=$ahead_behind_icon
        elif [[ -n "$ahead" ]]; then
            PL_BRANCH_CHAR=$ahead_icon
        elif [[ -n "$behind" ]]; then
            PL_BRANCH_CHAR=$behind_icon
        fi

        if [[ -e "${repo_path}/BISECT_LOG" ]]; then
            mode=" %{%F{136}%}<B>"
        elif [[ -e "${repo_path}/MERGE_HEAD" ]]; then
            mode=" %{%F{136}%}>M<"
        elif [[ -e "${repo_path}/rebase" || -e "${repo_path}/rebase-apply" || -e "${repo_path}/rebase-merge" || -e "${repo_path}/../.dotest" ]]; then
            mode=" %{%F{136}%}>R>"
        fi

        vcs_info

        # If there are only untracked files, change the branch color to green
        [[ ${vcs_info_msg_0_%%} = ' %{%F{red}%}U' ]] && branch_color=" %{%F{green}%}"
        echo -n $branch_color
        echo -n "${${ref:gs/%/%%}/refs\/heads\//$PL_BRANCH_CHAR }${vcs_info_msg_0_%% }${mode}%f"
    fi
}

# Main prompt
build_prompt() {
    RETVAL=$?
    prompt_status

    # Check if both conda and virtual environments are active
    if [[ -n "$CONDA_DEFAULT_ENV" && -n "$VIRTUAL_ENV" ]]; then
        # Determine which Python is currently in use
        if [[ "$(whence -p python)" == "$VIRTUAL_ENV/bin/python" ]]; then
            prompt_virtualenv
            prompt_condaenv
        else
            prompt_condaenv
            prompt_virtualenv
        fi
    elif [[ -n "$CONDA_DEFAULT_ENV" ]]; then
        prompt_condaenv
    elif [[ -n "$VIRTUAL_ENV" ]]; then
        prompt_virtualenv
    fi

    prompt_context
    prompt_dir
    prompt_git
}

PROMPT='%{$fg[cyan]%}╭─ %{$reset_color%}$(build_prompt)
%{$fg[cyan]%}╰─%{$reset_color%}%{$fg[green]%}$terminal_icon%{$reset_color%} '
