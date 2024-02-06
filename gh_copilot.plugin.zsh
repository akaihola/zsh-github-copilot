typeset -g GH_COPILOT_RESULT_FILE="${GH_COPILOT_RESULT_FILE:-/tmp/zsh_gh_copilot_result}"
typeset -g RED='\033[0;31m'
typeset -g GREEN='\033[0;32m'
typeset -g RESET='\033[0m'

_gh_copilot() {
	echo "" | gh copilot "$@" 2>/dev/null
}

_spinner() {
	local pid=$1
	local delay=0.1
	local spin='⣾⣽⣻⢿⡿⣟⣯⣷'

	cleanup() {
		kill $pid
		tput cnorm
	}
	trap cleanup SIGINT

	i=0
	# while the copilot process is running
	tput civis
	while kill -0 "$pid" 2>/dev/null; do
		i=$(((i + 1) % ${#spin}))
		printf "  ${RED}%s${RESET}" ${spin:$i:1}
		sleep "$delay"
		printf "\b\b\b"
	done
	printf "   \b\b\b"
	tput cnorm
	trap - SIGINT
}

_gh_copilot_spinner() {
	# run gh copilot in the background and show a spinner
	read < <(
		_gh_copilot "$@" >$GH_COPILOT_RESULT_FILE &
		echo $!
	)
	_spinner $REPLY >&2
	cat $GH_COPILOT_RESULT_FILE
}

_gh_copilot_explain() {
	local result
	local pattern
	# the explanation starts with 2 spaces but ignore the header comment
	# which starts with #
	pattern='^  [^#]'
	result="$(
		_gh_copilot_spinner explain "$@" |
			sed -n -e "/${pattern}/p"
	)"
	__trim_string "$result"
}

_gh_copilot_suggest() {
	local result
	local pattern
	# the suggestions start with 4 spaces
	pattern='^    '
	result="$(
		_gh_copilot_spinner suggest -t shell "$@" |
			sed -n -e "/${pattern}/p"
	)"
	__trim_string "$result"
}

__trim_string() {
	# reomve leading and trailing whitespaces
	# from https://github.com/dylanaraps/pure-bash-bible?tab=readme-ov-file#trim-leading-and-trailing-white-space-from-string
	# Usage: trim_string "   example   string    "
	: "${1#"${1%%[![:space:]]*}"}"
	: "${_%"${_##*[![:space:]]}"}"
	printf '%s\n' "$_"
}

_prompt_msg() {
	# print a message to the prompt
	printf "\n${GREEN}%s${RESET}\n\n" "$@"
	# this isn't great because it might work with multiline prompts
	zle reset-prompt
}

zsh_gh_copilot_suggest() {
	# based on https://github.com/stefanheule/zsh-llm-suggestions/blob/master/zsh-llm-suggestions.zsh#L65
	# check if the buffer is empty
	[ -z "$BUFFER" ] && return

	local result
	# place the query in history
	print -s "$BUFFER"
	result="$(_gh_copilot_suggest "$BUFFER")"
	[ -z "$result" ] && _prompt_msg "No suggestion found" && return
	# replace the current buffer with the result
	BUFFER="${result}"
	CURSOR=${#BUFFER}
}

zsh_gh_copilot_explain() {
	# based on https://github.com/stefanheule/zsh-llm-suggestions/blob/master/zsh-llm-suggestions.zsh#L71
	# check if the buffer is empty
	[ -z "$BUFFER" ] && return

	local result
	result="$(_gh_copilot_explain "$BUFFER")"
	_prompt_msg "${result:-No explanation found}"
}

zle -N zsh_gh_copilot_suggest
zle -N zsh_gh_copilot_explain
