#!/bin/bash

# Helper bash script used to indicate the current state of the Git repository.

git_branch_color_clean=$(tput setaf 2)
git_branch_color_dirty=$(tput setaf 1)
bold=$(tput bold)
normal=$(tput sgr0)
no_color=$(tput sgr0)

parse_git_branch()
{
    branch=$(git branch 2> /dev/null | sed -e '/^[^*]/d' -e 's/* \(.*\)/ \1/')

    if [[ -n $branch ]]
    then
        if [ -n "$(git status --untracked-files=no --porcelain)" ]
        then
            # Uncommitted changes
            branch+='*'
            echo "${git_branch_color_dirty}${bold}${branch}${normal}${no_color}"
        else
            echo "${git_branch_color_clean}${branch}${no_color}"
        fi
    fi
}

export PS1="\[\033[01;32m\]\u@\h\[\033[00m\]\[\033[01;34m\] \w\[\$(parse_git_branch)\]\[\e[00m\]\n> "
