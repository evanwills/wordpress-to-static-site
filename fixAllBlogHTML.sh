#!/bin/sh

# =========================================================
# This file is used for rerunning the recursive transforms needed to
# make the static version of the website work as well as the dynamic
# WordPress version.
#
# It should not be necessary to run this script directly.
# =========================================================

blogDir="$1"



if [ -z $blogDir ]
then	echo; echo;
	echo 'No directory supplied';
	echo; echo;
	exit;
fi

if [ ! -d $blogDir ]
then	echo; echo;
	echo 'Supplied string ("'$blogDir'") is not a valid directory';
	echo; echo;
	exit;
fi


SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"




# -----------------------------------------------
# @function fixHTML() recursively go through
#		directories and rewrite HTML files so
#		that linked assets don't have GET
#		variables in the file name and rewrite
#		HTML elements with inline background
#		image styles to have nested image tags
#		with the background image's URL as the
#		image src
#
# @param {string} file system path from which to
#		start cleaning HTML files
#
# @return void
# -----------------------------------------------

fixHTML ()
{
	# -----------------------------------------------
	# @var $path - Local file system path to be processed
	#
	# NOTE: If path doesn't end with a slash, a slash is
	#	added
	# -----------------------------------------------
	path=$(echo $1 | sed 's/\/*$/\//')

	/bin/sh $DIR/fixHTML.sh $path

	# Recurse through child directories to ensure all HTML
	# files are cleaned up.
	for dirPath in $path*;
	do	if [ -d $dirPath ]
		then	if [ "$dirPath" != '.' ]
			then	if [ "$dirPath" != '..' ]
				then	# This is a normal directory
					# Clean inside this one
					fixHTML $dirPath
				fi
			fi
		fi
	done
}