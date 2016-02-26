#! /bin/bash

shopt -s autocd;
shopt -s cdspell;
shopt -s dotglob;

alias reset!='exec $SHELL -l'
alias reload!='source ~/.bash_profile'

alias -- -='cd -'

if ls --color 2>/dev/null; then
	alias ls='ls -A --color'
else
	alias ls='ls -AG'
fi
alias ls*='ls -R'

__tree() { tree -aC $@; }

alias tree='__tree -d'
alias tree*='__tree --dirsfirst'

alias mkdir='mkdir -p'
alias rm!='rm -rf'

alias grep='grep -E --color'

alias less='less -cr'

alias todo='todo.sh'

if type -f git >/dev/null 2>&1; then
	alias git='git --no-pager -c color.ui=always'
fi

__git_reset() {
	__git_url=$(git config --get remote.origin.url)
	rm! .git
	git init
	git remote add origin "$__git_url"
	git fetch
	git branch -t master origin/master
}

__github_clone() { git clone "https://github.com/$1.git" "$2"; }

alias ghclone='__github_clone'
alias greset!='__git_reset'

__git_list() {
	git log --graph --abbrev --pretty=format:"%C(yellow)%h%C(reset) %s %C(green)(%cr)%C(reset)%n%C(blue)%d%C(reset)" $@
}

alias g?='git status'
alias gls='__git_list --all'
alias gls*='git reflog; gls'

__git_curr() { git rev-parse --abbrev-ref HEAD; }

__git_root() {
	git log --reverse --format=%D HEAD |
		head -1 |
		tr -d , |
		tr ' ' '\n' |
		head -1 |
		sed 's/^origin\///'
}

__git_prev() {
	git log -n 1 --format=%D HEAD^ |
		tr -d , |
		tr ' ' '\n' |
		head -1 |
		sed 's/^origin\///'
}

__git_next() {
	git log --all --format='%P %D' |
		grep -e "^$(git rev-parse HEAD)" -e "^$(git rev-parse "origin/$(__git_curr)")" |
		cut -d ' ' -f 2- |
		tr -d , |
		tr ' ' '\n' |
		grep -v -e master -e origin/master |
		head -1 |
		sed 's/^origin\///'
}

alias g..*='git checkout $(__git_root)'
alias g..='git checkout $(__git_prev)'
alias gnx='git checkout $(__git_next)'

alias gcd='git checkout'

alias gcmp='git diff --cached --summary; git difftool -y -M --cached --diff-filter=M'
alias gdiff='gcmp HEAD'
alias gdiffr='gcmp "origin/$(__git_curr)" HEAD'

__git_rebase() { git rebase --onto "$1" HEAD~; }

alias gmv='__git_rebase'

alias gsync!='git pull --rebase && git push'
alias gsave!='git commit --amend'
alias gbless!='git push -f -u origin'

__git_undo() { git reset --hard HEAD $@; git checkout -- $@; }

alias gundo!='__git_undo'
alias gclean!='git reflog expire --expire=now --all; git gc --prune=now'

if type -f git >/dev/null 2>&1; then
	__ps1_git_status() {
		if [ -e .git ]; then
			git add --all

			current=$(__git_curr)
			remote=origin/$current
			dirty=$(git status --porcelain)
			online=$(git rev-parse --verify $remote 2>/dev/null)

			if [[ $online ]]; then
				behind=$(git rev-list "HEAD..$remote")
				ahead=$(git rev-list "$remote..HEAD")
			fi

			printf " ($(AEC 1)$(AEC 35)$current)$(AEC 33)"
			if [[ $dirty ]]; then
				printf ' ±'
			fi
			if [[ $online ]]; then
				if [[ $behind ]]; then
					if [[ $ahead ]]; then
						printf ' ⇔'
					else
						printf ' ⇐'
					fi
				elif [[ $ahead ]]; then
					printf ' ⇒'
				fi
			else
				printf " $(AEC 2)⇎"
			fi
			printf "$(AEC 0)$(AEC 35)"
		fi
	}

	__complete_git() {
		curr="${COMP_WORDS[COMP_CWORD]}"
		if [ -n "$curr" ]; then
			COMPREPLY=( $(compgen -W "$(git for-each-ref --format='%(refname:short)')" -- "${curr}") )
		fi
	}
	complete -F __complete_git git gcd gmv
else
	__ps1_git_status() { :; }
fi

__vagrant_provision () { vagrant provision ${1+--provision-with $1}; }

alias vreset!='vdown!; vup*'
alias vreload!='vagrant reload; vup'

alias v?='vagrant status'
alias vup*='vagrant up'
alias vup='__vagrant_provision'
alias vdown!='vagrant destroy -f'
alias vin='vagrant ssh'

cx () {
	TARGET=$(mktemp "/tmp/cx.XXXXXXXXXX")
	if [ -t 0 ]; then
		gcc -xc -o "$TARGET" $@
	else
		gcc -xc -o "$TARGET" - $@
	fi && "$TARGET"
	rm "$TARGET"
}
export -f cx

ecx () {
	embrace "$1" | cx
}
export -f cx

AEC() { echo $'\e'[$1m; }

__PS1_PROMPT="$(AEC 35)→$(AEC 0) "

if type -f gdate >/dev/null 2>&1; then
	# use gdate for osx users who have coreutils installed
	__now() { gdate +%s%N; }
elif [[ $(date +%N) == 'N' ]]; then
	# live without subsecond precision for osx users with no alternative
	__now() { echo $(( 1000000000 * $(date +%s) )); }
else
	__now() { date +%s%N; }
fi

__on_debug() {
	__cmd_prev=$__cmd_curr
	__cmd_curr=$BASH_COMMAND
	__cmd_started=${__cmd_started:-$(__now)}
}

__ps1_prologue() {
	echo
	echo "$__PS1_PROMPT$(AEC 35)$(AEC 1)$__cmd_prev$(AEC 0)"
	if [[ $__cmd_status == 0 ]]; then
		echo "$(AEC 32)✓ $(AEC 1)Victory!$(AEC 0)"
	else
		echo "$(AEC 31)✖ $(AEC 1)Defeat! $(AEC 2)[$__cmd_status]$(AEC 0)"
	fi
	echo "$(AEC 36)  Finished in $(AEC 1)$__cmd_elapsed s$(AEC 2) (at \T)$(AEC 0)"
}

__on_prompt() {
	__cmd_status=$?
	__cmd_elapsed=$(printf %010d "$(( $(__now) - $__cmd_started ))")
	__cmd_elapsed="$((10#${__cmd_elapsed:0:1})).${__cmd_elapsed:1:3}"
	unset __cmd_started
	
	__term_width=$(tput cols)
	
	PS1=''
	PS1+="$(echo -e "\e];\w\x07")"
	PS1+="$(__ps1_prologue)\n\n"
	PS1+="$(AEC 35)$(printf %$(( $__term_width > 80 ? 80 : __term_width ))s | tr ' ' '─')\n"
	PS1+="\w$(__ps1_git_status)$(AEC 0)\n"
	PS1+="$__PS1_PROMPT"
}

trap '__on_debug' DEBUG
PROMPT_COMMAND=__on_prompt

if [ -f ~/.bash_aliases ]; then
	. ~/.bash_aliases
fi
