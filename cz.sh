#!/usr/bin/env bash

## ARGUMENT PARSER
## 	For this application, the arguments should'b be so flexible, because it has
##  a specific propurse. No need to put too much arguments

OPTIONS="h,a,d,j:N"
LONG_OPTIONS="help,ammend,description,json:,no-display-emoji"

eval -- set -- $(getopt --name "${BASH_SOURCE}" --options "${OPTIONS}" \
						--longoptions "${LONG_OPTIONS}" -- "${@}")
unset OPTIONS LONG_OPTIONS

## OPTIONS SETUP
## 	This section will asing/overwrite values to the options variables, most of
##  is bolean variables that the script will use to know how to build the git
##  commit command

is_ammend=0
is_description=0
types_json="${HOME}/.local/share/committizen_emoji_sh/types.json"
jqcmd_build_fzf_table='.[] | .emoji + "|" + .name + "|" + .description'
jqcmd_display_selected='"\n" + .emoji + " " + .name + ": " + .description + "\n"'
jqcmd_gen_prefix_msg='.code + " " + .name'

while true
do
	case "${1}" in
		"-h" | "--help")
			echo
			echo "${BASH_SOURCE} - v1.4.0"
			echo
			echo "I was anoyed that the cz-emoji tool was written in Javascript"
			echo "and depends on NPM, PNPM or whatever you use to manage your node"
			echo "packages, so I made my own commit cittizen script with emoji"
			echo "support using only bash and some system utilities. Feel free"
			echo "to contribute at https://github.com/kevinmarquesp/committizen_emoji_sh"
			echo
			echo "Command Options:"
			echo "  -h --help         Displays this help message."
			echo "  -a --ammend       Ammends the commit to the last one"
			echo "  -d --description  Ask for a longer description after commit"
			echo "  -j --json [PATH]  Path to the types.json file with the commit types."
			echo "                      (Current setted as ${types_json})"
			echo
			echo "Context Prompt:"
			echo "  A helper information that helps the developer know what the"
			echo "  commit message is related to. Could be a file name or a custom"
			echo "  tag, for an example."
			echo
			echo "Commit Prompt:"
			echo "  The commit message (duh) that git will use to commit the current"
			echo "  changes. It's recommended that this message has less than 80"
			echo "  characters length, you need to be specific."
			echo
			echo "Description Prompt:  (optional)"
			echo "  If you've setted the -d or --description flag on the command"
			echo "  this script will ask for another message to put in the commit"
			echo "  body. Use this to detail what this changes does and warnings."
			echo
			exit
		;;

		"-a" | "--amend")
			is_ammend=1
			shift
		;;

		"-d" | "--description")
			is_description=1
			shift
		;;

		"-j" | "--json")
			types_json="${2}"
			shift 2
		;;

		"-N" | "--no-display-emoji")
			jqcmd_build_fzf_table='.[] | .name+"|"+.description'
			jqcmd_display_selected='"\n" + .name + ": " + .description + "\n"'
			shift
		;;

		"--")
			break
		;;
	esac
done

## SCRIPT BODY
##  For stylish propurses, it should try to import the user's aliases, then
##  start the proces: Use fzf + jq to prompt the user, then ask for the message
##  description strings. At the end, construct a commit command string and
##  execute that!

shopt -s expand_aliases
set -e

[ -e "${HOME}/.bashrc" ] && . "${HOME}/.bashrc"
[ -e "${HOME}/.bash_aliases" ] && . "${HOME}/.bash_aliases"
[ -e "${HOME}/.aliasrc" ] && . "${HOME}/.aliasrc"

type_idx=$(jq "${jqcmd_build_fzf_table}" "${types_json}" |
	nl -v 0 |
	column -ts "|" |  #convert the lines into a text table
	sed 's/"//g' |  #remove the " characters generated by the column command
	fzf |
	sed 's/^ *\([0-9]*\).*$/\1/')  #remove everything, but the index numbers

[ -z "${type_idx}" ] &&  #exit if any type was selected
	exit

#this line just display the selected type, just to help the user identify his/her choices...
printf "\033[0;33m%s\033[0m\n\n" \
	"$(jq -r ".[${type_idx}] | ${jqcmd_display_selected}" "${types_json}")"

printf "context: \033[0;36myour commit message is related to what?\n"
printf " \033[0;32m$\033[0m "
read ri_contextstr
echo

printf "mmessage: \033[0;32m******************************************************\033[0;33m***************\033[0;31m*****\n"
printf " \033[0;32m$\033[0m "
read ri_messagestr
echo

[ -z "${ri_messagestr}" ] &&  #exit the user doesn't specify any commit message
	exit

if [ $is_description = 1 ]
then
	printf "description: \033[0;36mchange details, explain what this commit does better\n"
	printf " \033[0;32m$\033[0m "
	read ri_descriptionstr
	echo
fi

description_opt=""
ammend_opt=""
context_part=":"
prefix_part=$(jq -r ".[${type_idx}] | ${jqcmd_gen_prefix_msg}" "${types_json}")

#build the commit options and parts based on the input strings and/or user options
[ -n "${ri_descriptionstr}" ] &&
	description_opt="-m '${ri_descriptionstr}'"
[ $is_ammend = 1 ] &&
	ammend_opt="--amend"
[ -n "${ri_contextstr}" ] &&
	context_part=" (${ri_contextstr}):"

commit_cmd="git commit ${ammend_opt} '${prefix_part}${context_part} ${ri_messagestr}' ${description_opt}"

#display the command string and then execute it
printf "\033[0;30m${commit_cmd}\033[0m\n\n"
eval "${commit_cmd}"
