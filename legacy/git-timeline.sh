#!/bin/bash
# I found this in an old bag o'tricks from like 5yrs ago... run it in any git managed-dir & see
#[inspired by](https://www.tothenew.com/blog/script-to-display-git-commits-for-creating-time-sheet/)
#Codebase: /d/projects/mbdt/ADO/mbdt.infrastructure-1/configs/_tools/mbdt-libs-v0.1/bash/getters/git-timeline.sh

echo -e "\n$(tput bold && tput setaf 4)ALIAS: bash $0\n"

# Define CONSTANTS
TODAY=`date +%Y%m%d`
EXPECTED_ARGS=1
E_BADARGS=65
AUTHOR_NAME_REGEX=".*"
DATE_REGEX="[1-9][0-9][0-9][0-9]-[0-1][0-9]-[0-3][0-9]"
DAY_REGEX="^[[:digit:]]{1,2}$"
FORMAT="%Cred%h%Creset  [%cd] %Cgreen(%cr) %Creset %C(bold blue)<%cL>%Creset -%C(yellow)%d%Creset %s "
PRETTY="'format:%X %h %s%n\t%<(12,trunc)%ci%x08%x08, %an <%ae>'" #2015-0917JN - replaced with FORMAT

# stupid simple way of parsing args to determine the type of query from day, date or range +/- name filter
[ $# -lt $EXPECTED_ARGS ] && git log --graph --format="$FORMAT" --since="10 days ago" --decorate=full #default - everything with simple date filter
[[ $# -eq $EXPECTED_ARGS && $1 =~ $AUTHOR_NAME_REGEX ]] && git log --graph --format="$FORMAT" --author=$1 #author search

# query by date(s) or range filter +/- name filter
[[ $# -eq $EXPECTED_ARGS && $1 =~ $DATE_REGEX ]] && git log --graph --format="$FORMAT" --after={$1}
[[ $# -gt $EXPECTED_ARGS && $# -eq 2 && $1 =~ $DATE_REGEX && $2 =~ $AUTHOR_NAME_REGEX ]] && git log --graph --format="$FORMAT" --after={$1} --author=$2
[[ $# -gt $EXPECTED_ARGS && $# -eq 2 && $1 =~ $DATE_REGEX && $2 =~ $DATE_REGEX ]] && git log --graph --format="$FORMAT" --after={$1} --before={$2}
[[ $# -gt $EXPECTED_ARGS && $# -eq 3 && $1 =~ $DATE_REGEX && $2 =~ $DATE_REGEX ]] && $3 =~ $AUTHOR_NAME_REGEX ]] && git log --graph --format="$FORMAT" --after={$1} --before=${2} --author=$3

# query by day(s) of this month or range filter +/- name filter
[[ $# -eq $EXPECTED_ARGS && $1 =~ $DAY_REGEX ]] && git log --graph --format="$FORMAT" --after={$1-%m-%Y}
[[ $# -gt $EXPECTED_ARGS && $# -eq 2 && $1 =~ $DAY_REGEX  && $2 =~ $DAY_REGEX ]] && git log --graph --format="$FORMAT" --after={$1-%m-%Y} --before={$2-%m-%Y}
[[ $# -gt $EXPECTED_ARGS && $# -eq 2 && $1 =~ $DAY_REGEX && $2 =~ $AUTHOR_NAME_REGEX ]] && git log --graph --format="$FORMAT" --after={$1-%m-%Y} --author=$2
[[ $# -gt $EXPECTED_ARGS && $# -eq 3 && $1 =~ $DAY_REGEX && $2 =~ $DAY_REGEX && $3 =~ $AUTHOR_NAME_REGEX ]] && git log --graph --format="$FORMAT" --after={$1-%m-%Y} --before={$2-%m-%Y} --author=$3

