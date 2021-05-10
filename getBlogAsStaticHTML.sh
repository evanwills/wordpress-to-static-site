#!/bin/sh

# =========================================================
# This file does the all actual work of scraping and transforming
# a WordPress blog (or any other dynamic site) into static HTML
#
# It can be run manually but is intended to be run via a cron job.
#
# It does NOT handle moving the static site to another server.
# For moving the whole site, I recommend using rsync.
# =========================================================


# =========================================================
# START: Setting up variables

# -----------------------------------------------
# @var $isTest - Whether or not to run the script
#		in test mode
#
# (In test mode wget is not run and files are not
#  moved at the end)
# -----------------------------------------------

isTest=$(echo "$1" | grep -i 'test' | sed 's/^test$/1/i')

# echo '$isTest: '$isTest

# exit;

# -----------------------------------------------
# @var $blogRoot - Local path to the root of the
#		blog site
# -----------------------------------------------

blogRoot='/var/www/internationalblog';

# -----------------------------------------------
# @var $blogDir - Local path to where wget will store
#		all the blogs pages
# -----------------------------------------------

blogDir=$blogRoot'/blogSrc';


# -----------------------------------------------
# @var $themeAssetDir - Local path to where the output
#		of wget will be stored
# -----------------------------------------------

themeAssetDir=$blogDir'/wp-content/themes/my-theme/dist'


# -----------------------------------------------
# @var $blogDirData - Local path to where the output
#		of wget will be stored
# -----------------------------------------------

blogDirData=$blogDir'/myblog.example.com/'


# -----------------------------------------------
# @var $extraCSS - Extra css declarations not in the main
#		CSS
#
# NOTE: When this script was originally implemented, the
#       theme the blog used had a lot of inline #styles in
#       the <head> block. The server hosting the static
#       version of the blog had Content Security Policy
#       rules to prevent inline JS & CSS. Thus it was
#       necessary to create a custom style sheet that
#       contained all the inline styles so that styling
#       would not be lost on the static site.
#
#       The file specified in $extraCSS is concatinated
#       with the main CSS file to ensure these styles work
#       in the static version.
# -----------------------------------------------

extraCSS=$blogDir'/extra.css'


# -----------------------------------------------
# @var $mainCSS - The blog's primary/main css file
#		(to which the extra CSS will be appended)
# -----------------------------------------------

mainCSS=$themeAssetDir'/main.css'

# -----------------------------------------------
# @var $blogScrapeLog - Path to log file for this script
# -----------------------------------------------

blogScrapeLog=$blogDir'/blogScrape.log';

# -----------------------------------------------
# @var $wStartT - Unix timestamp for start of script
# -----------------------------------------------

wStartT=$(date '+%s')


# -----------------------------------------------
# @var $flags List of standard flags to pass to wget
# -----------------------------------------------

flags='--mirror --convert-links --html-extension --no-parent --page-requisites'; #  --timestamping


# -----------------------------------------------
# @var $blogRootURL - Base URL for blog site
# -----------------------------------------------

blogRootURL='https://myblog.example.com/';


# -----------------------------------------------
# @var $userName - Name of user who owns static site files
# -----------------------------------------------

userName='evwills';


# -----------------------------------------------
# @var $groupName - Name of group that owns static site files
# -----------------------------------------------

groupName='webdev';


year=$(date '+%Y')


SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
DIR="$( cd -P "$( dirname "$SOURCE" )" >/dev/null 2>&1 && pwd )"


#  END:  Setting up variables
# =========================================================
# START: Function declarations



# -----------------------------------------------
# @function cleanFileName() recursively go through
#		directories and rewrite filenames
#		where GET variables have been appended
#		to the file name
#
# @param {string} file system path from which to
#		start cleaning file names
#
# @return void
# -----------------------------------------------
cleanFileName ()
{
	path="$1/"

	for f in $path*;
	do	# [[ -e $f ]] || continue
		# echo '$f: '$f
		if [ -f $f ]
		then	fileOnly=$(echo $f | sed 's/^\([^\/]\+\/\)\+//i')
			pathOnly=$(echo $f | sed 's/^\(\([^\/]\+\/\)\+\).*$/\1/i')
			cleanFile=$(echo $fileOnly | sed 's/^\([^?]\+\)\(?.*\)*$/\1/i')
			if [ "$fileOnly" != "$cleanFile" ]
			then	# echo '------------------------';
				# echo 'Full path: '$f
				# echo 'Path only: '$pathOnly
				# echo 'File only: '$fileOnly
				# echo 'Clean file: '$cleanFile
				# echo
				# echo "mv $f $pathOnly$cleanFile;";
				mv $f $pathOnly$cleanFile
				# echo '------------------------';
			fi
		else	if [ -d $f ]
			then	if [ "$f" != '.' ]
				then	if [ "$f" != '..' ]
					then	cleanFileName $f
					fi
				fi
			fi
		fi
	done
}

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

# -----------------------------------------------
# @function revStr() reverse the order of characters
#		in a string
#
# @param {string} A string to be reversed
#
# @return {string}
# -----------------------------------------------
revStr () {
	num="$1"
	len=${#num}

	for((i=$len-1;i>=0;i--));
	do	rev="$rev${num:$i:1}";
	done

	echo $rev
}

# -----------------------------------------------
# @function commaSepNum() comma separate thousands
#		in a number
#
# @param {string} A string to be reversed
#
# @return {string}
# -----------------------------------------------
commaSepNum () {
	num=$(revStr $1)
	num=$(echo $num | sed 's/\([0-9]\{3\}\)/\1,/g')
	num=$(echo $num | sed 's/,$//g')

	echo $(revStr $num)
}

# -----------------------------------------------
# @function plural() Make a word plural if the number
#		provided is greater or less than 1
#
# @param {integer} Number to be compared
# @param {string} Word to be pluralised
#
# @return {string}
# -----------------------------------------------
plural () {
	num=$1
	word=$2
	output=$num' '$word

	if [ $num -gt 1 ]
	then 	output=$output's'
	else	if [ $num -lt 1 ]
		then	output=$output's'
		fi
	fi
	echo $output
}

# -----------------------------------------------
# @function seconds() Convert seconds into hours,
#		minutes & seconds
#
# @param {integer} Number of seconds ellapsed
#
# @return {string}
# -----------------------------------------------
seconds () {
	num="$1"
	num=$(($1 * 1))
	output=''
	if [ $num -gt 3600 ]
	then	hrs=$(($num / 3600))
		tmp=$(($hrs * 3600))
		num=$(($num - $tmp))
		output=$(plural $hrs 'hour')
	fi
	if [ $num -gt 60 ]
	then 	min=$((num / 60))
		tmp=$(($min * 60))
		num=$(($num - $tmp))
		if [ "$output" != '' ]
		then	output=$output', '
		fi
		output=$output$(plural $min 'minute')
	fi
	if [ $num -gt 0 ]
	then 	if [ "$output" != '' ]
		then	output=$output', '
		fi
		output=$output$(plural $num 'second')
	fi
	echo $output
}

# -----------------------------------------------
# @function ellapsed() Render a human readable
#		representation of time ellapsed for
#		a given step in the script
#
# @param {integer} Number of seconds ellapsed
#
# @return {string}
# -----------------------------------------------
ellapsed () {
	tmpS=$1
	tmpSc=$(commaSepNum $tmpS)
	tmpMin=$(seconds $tmpS)

	echo $tmpSc' seconds to complete ('$tmpMin')'
}

# -----------------------------------------------
# @funciton padMsg() Adds padding characters to a
#		message string to ensure the message
#		is the correct length
#
# @param {string} Message string to be padded
#
# @return {string} String of exactly 15 characters
# -----------------------------------------------

padMsg () {
	input=$(echo "$1" | sed 's/./#/g')
	len=$(expr length "$input")
	len=$((13 - $len))

	sep=':#'
	for((i=$len;i>0;i--))
	do	sep="$sep#"
	done

	echo $sep
}

# -----------------------------------------------
# @function report() writes logging output to a log file
#
# @param {string} Message to be logged
# @param {string,int} Modifier for the message
#
# @return {void}
# -----------------------------------------------
report () {
	msg=$(echo "$1" | sed 's/^[\t ]\+|[\t ]\+$//g')
	mod=$(echo $"$2" | grep '^\(date\|[0-9]\+\)$')
	mType=$(echo $msg | grep '^\(start\|end\)$')
	# echo '$msg:  '$msg
	# echo '$mod:   '$mod
	# echo '$mType: '$mType

	if [ -z "$msg" ]
	then	echo >> $blogScrapeLog
	else	if [ "$mType" == 'start' ]
		then	# -- We have a start block --
			echo >> $blogScrapeLog;
			echo '======================================' >> $blogScrapeLog;
			echo >> $blogScrapeLog;
			echo >> $blogScrapeLog;
		else	if [ "$mType" == 'end' ]
			then	# -- We have a end block --
				echo >> $blogScrapeLog;
				echo '======================================' >> $blogScrapeLog;
				echo >> $blogScrapeLog;
				echo >> $blogScrapeLog;
			else	if [ -z "$mod" ]
				then	# -- We have a simple message --
					echo '                - '$msg >> $blogScrapeLog
				else	# -- We have a complex message --

					if [ "$mod" == 'date' ]
					then
						suffix=$(date '+%Y-%m-%d %H:%M:%S')
					else	suffix=$(ellapsed $mod)
					fi

					echo "$msg$(padMsg "$msg")$suffix" >> $blogScrapeLog
				fi
			fi
		fi
	fi
}

# -----------------------------------------------
# @function finishReport() Finishes the logging for
#		the current run of the script and
#		cleans up the padding characters
#
# @returns {void}
# -----------------------------------------------
finshReport () {
	report 'end'
	sed -i 's/#/ /g' $blogScrapeLog
}

# -----------------------------------------------
# @function startReport() Make sure log file exists
#		Then initialise logging for this
#		scritp run
#
# @returns {void}
# -----------------------------------------------
startReport () {
	if [ ! -f $blogScrapeLog ]
	then	echo '' > $blogScrapeLog;
		echo 'Created log file for download:' $blogScrapeLog;
	fi
	report 'start'
}


#  END:  Function declarations
# =========================================================
# START: Getting envrionment ready


if [ "$isTest" == '1' ]
then	isTest=1
else	isTest=0
fi


# - - - - - - - - - - - - - - - - - - - - - - - -
# Move to static blog's dir
cd $blogDir;

if [ ! -f $blogScrapeLog ]
then	echo '' > $blogScrapeLog;
	echo 'Created log file for download:' $blogScrapeLog;
fi


# exit;



#  END:  Getting envrionment ready
# =========================================================
# START: Mirroring site


startReport


if [ $isTest -eq 1 ]
then	report 'Start script' 'date'
	report 'Skipping mirror process'

	# -----------------------------------------------
	# @var $wEndT - Unix timestamp for when `wget`
	#		completed its work
	# -----------------------------------------------

	wEndT=$(date '+%s')
else
	report 'Start wGet' 'date'

	# - - - - - - - - - - - - - - - - - - - - - - - -
	# Make sure the destination directory is empty
	report 'Empty source directory.'
	rm -rf $blogDirData/*;

	# - - - - - - - - - - - - - - - - - - - - - - - -
	# Get the whole (blogRootURL) blog site

	report 'Start scrape.'
	wget $flags $noNew $blogRootURL;

	# -----------------------------------------------
	# @var $wEndT - Unix timestamp for when `wget`
	#		completed its work
	# -----------------------------------------------

	wEndT=$(date '+%s')

	report 'End wGet' 'date'
	report 'wGet took' $(($wEndT - $wStartT))
fi


#  END:  Mirroring site
# =========================================================
# START: cleaning mirrored static site




report 'Start clean-up'

# - - - - - - - - - - - - - - - - - - - - - - - -
# Cleanup URLs

# echo '$cleanAssetFileName: '$cleanAssetFileName;

cd $blogDirData



# - - - - - - - - - - - - - - - - - - - - - - - -
# Cleanup file names

report 'Rewrite file names in wp-content.'
cleanFileName ./wp-content

report 'Fix HTML.'
fixHTML $blogDirData



#  END:  cleaning mirrored static site
# =========================================================
# START: Move mirrored static site to production location



if [ $isTest -eq 1 ]
then	report 'Skipping move to prod'
else
	# Fix file permissions so that, if necessary, other people
	# can edit the scraped files
	report 'Fix file permissions.'
	chown -R $userName.$groupName $blogDirData*

	# Move lates files to production directory.
	report 'Move scraped files to PROD.'
	mv --no-target-directory $blogDirData* $blogRoot/

	if [ -f "$extraCSS" ]
	then	if [ -f "$mainCSS" ]
		then
			# Overwrite the last stylesheet with stylesheet containing
			# extra declarations from inline styles in HTML to ensure
			# normal branding.
			report 'Concatinate extra CSS file.'
			cat $mainCSS $extraCSS > $mainCSS
		fi
	fi

	if [ -f "$blogDir/arrow.png" ]
	then	# For some reason the arrow image isn't downloaded during scrape.
		# Copy a saved version to the correct location.
		report 'Copy arrow image file.'
		cp $blogDir/arrow.png $themeAssetDir/images/
	fi

	# `2020/page/2.html` is known to have background images in the
	# WordPress version of the site but should have an `<img />`
	# with a `bg-block--img` class
	testCount=$(grep --count 'bg-block--img' $blogRoot'/2020/page/2.html')
	testCount=$(($testCount * 1))

	# Lets see if we have an image block with the appropriate class.
	if [ $testCount -eq 0 ]
	then	# No image tags with a `bg-block--img` class were
		# found lets try again to fix the HTML.

		report 'Cleanup failed to fix deep HTML pages.'
		report 'Running fixblogRootURLHTML.sh to try and fix the problem.'

		# Backup fixing HTML if deep pages don't get updated
		# properly by `fixHTML()`
		/bin/sh $DIR/fixAllBlogHtml.sh $blogRoot
	fi
fi



#  END:  Move mirrored static site to production location
# =========================================================
# START: Finish report



# -----------------------------------------------
# @var $cleanUpT- Unix timestamp for when whole script
#              completed its work
# -----------------------------------------------

cleanUpT=$(date '+%s')

report 'End clean-up' 'date'
report 'clean-up took' $(($cleanUpT - $wEndT))
report
report 'Total time' $(($cleanUpT - $wStartT))
finshReport

tail -n 25 $blogScrapeLog;
