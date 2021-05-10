#!/bin/sh

# ===============================================
# This file contains all the transforms required to get the static
# version of the WordPress site looking and behaving like the
# dynamic source version of the WordPress site.
#
# It does NOT handle any of the scraping it merely transforms
# what is already on disc (after the scraping has completed).
# ===============================================


# -----------------------------------------------
# @var $path - Local file system path to be processed
#
# NOTE: If path doesn't end with a slash, a slash is
#	added
# -----------------------------------------------
path=$(echo $1 | sed 's/\/*$/\//')


# -----------------------------------------------
# @var $htmlGlob - Glob for HTML files
# -----------------------------------------------

htmlGlob=$path'*.html*'

# -----------------------------------------------
# @var $htmlFileCount - Number of HTML files in the current
#		directory
# -----------------------------------------------

htmlFileCount=$(ls $path | grep -c '\.html')


if [ $htmlFileCount -gt 0 ]
then	# This directory contains HTML files

	# echo '$htmlGlob: '$htmlGlob
	# echo '$htmlFileCount: '$htmlFileCount

	notQ='[^"'"']\+"
	isQ='["'"']\+"

	# -----------------------------------------------
	# @var $cleanAssetFileName - Full sed regular expression
	#		for cleaning up URLs with GET variables
	#		appended to them
	# -----------------------------------------------

	cleanAssetFileName='s/\(\.\(css\|js\)\)\(%3F\|?\)'$notQ'\('$isQ'\)/\1\4/ig'

	# Rewrite file names to remove GET variables
	sed -i "$cleanAssetFileName" $htmlGlob


	# ===================================================
	# Other rewrites needed to ensure user interface and
	# behaviour of static version of the WordPress blog site
	# matches go here.


	# -----------------------------------------------
	# @var $backgroundImg2ImgTag - Regular expression for
	#		converting background image styles to
	#		image tags.
	#
	# This is only nececessary if Content Security Policy
	# (CSP) blocks inline styles.
	# -----------------------------------------------

	backgroundImg2ImgTag='s/<div[ \t]\+class[ \t]*=[ \t]*"\([^"]\+\)"[ \t]\+style[ \t]*=[ \t]*"[ \t]*background-image:[ \t]*url('"'\?\([^')]\+\)'\?[ \t]*)[ \t]*"'"[ \t]*>/<div class="\1 bg-block"><img src="\2" class="bg-block--img \1--img" alt="" \/>/ig';

	# Rewrite elements with background images to use
	# nested <IMG /> tags
	sed -i "$backgroundImg2ImgTag" $htmlGlob;


	# -----------------------------------------------
	# @var $connectBtn - Regular expression for appending
	#		a "Connect with us" button to the right
	#		sidebar
	# -----------------------------------------------

	connectBtn='s/\(<aside class="sidebar\)\(">\)/\1 w--connect-w-us\2\n<a href="https:\/\/www.acu.edu.au\/international-students\/contact-international-student-support\/ask-a-question" class="connect-w-us-btn">Connect with us<\/a>\n/ig'

	# Add "Connect with us" button to replace connect with us form
	sed -i "$connectBtn" $htmlGlob;


	# -----------------------------------------------
	# @var $privacyURL - Regular expression for updating
	#		the URL for the "Privacy Policy" link
	#               in the page footer
	# -----------------------------------------------

	privacyURL='s/http:\/\/www\.acu\.edu\.au\/policy\/governance\/privacy_policy_and_procedure\/privacy_policy/https:\/\/www.acu.edu.au\/privacy/ig'

	# Add "Connect with us" button to replace connect with us form
	sed -i "$privacyURL" $htmlGlob;


	# -----------------------------------------------
	# @var $contactURL - Regular expression for updating
	#		the "Contact" link in the page footer
	# -----------------------------------------------

	contactURL='s/index.html%3Fp=72\.html/https:\/\/www.acu.edu.au\/international-students\/contact-international-student-support\/ask-a-question/ig'

	# Add "Connect with us" button to replace connect with us form
	sed -i "$contactURL" $htmlGlob;


	# Fix year in copyright text in footer
	sed -i 's/2017\( Australian Catholic University\.\)/'$year'\1/ig' $htmlGlob;

	# echo '$cleanAssetFileName: "'$cleanAssetFileName'"'
	# echo '$backgroundImg2ImgTag: "'$backgroundImg2ImgTag'"'
fi