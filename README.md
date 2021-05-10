# Copy (dynamic) WordPress site to static HTML

This repo contains a couple of `Bash` shell scripts used for scraping old (unpatchable) WordPress Blog sites (only accessible from inside the a VPN) and converting it to static HTML hosted on simple web server with no PHP or MySQL/MariaDB.

## Automation

This is designed to run as a cron job so that the owner of the site can continue to use the functionality of WordPress as a CMS without the headache of having to manage continual security patches.

> `./getBlogAsStaticHTML.sh`, 

This ensures that any new content added to the WordPress Blog is made public as often as necessary.

> Cron job is defined in `/etc/crontab` and executed as root.

## Files

__`getBlogAsStaticHTL.sh`__ does all the major work of scraping the WordPress site and doing some post scrape cleanup because the WordPress themes don't always scrape nicely.

__`fixHTML.sh`__ does all the post scrape transforms (using `sed`). It accepts a path to a file or directory then applies sed command to all the HTML files in the directory.

__`fixAllBlogHTML.sh`__ recursively goes through all the children of a given directory and applies `fixHTML.sh` to each directory (and it's decendants).

For some reason the recursive fixing of HTML files in `getBlogAsStaticHTML.sh` doesn't always work, so this is used as a backup.

`$extrCSS` path to custom CSS file that contains custom override CSS that will be merged into the Blog theme's main css file to fix issues caused by moving from a dynamic site to a static site. And also to get around some of the configuration issues caused by the security setting on the archives.acu.edu.au server.

## What does `getBlogAsStaticHTL.sh` do?

1. It uses `wget` to scrape the contents of the WordPres version of a 
   given site, and convertes it to statick HTML.
2. It rewrites file names for CSS & JS files scraped by `wget` so 
   that the GET variables appended by WordPress are removed
3. It rewrites the HTML files to using transforms specified in 
   `fixHTML.sh`
4. Moves the scraped and cleaned HTML files to the public location 
   for the static site.
5. If you provide an extra CSS file (via `$extraCSS`) and a main 
   (via `$mainCSS`) file the extra CSS file will be concatinated 
   with the main CSS to ensure any missing styles are present on 
   the static verson of the iste.
5. If (as is currently the case) step three didn't properly recurse 
   through the sub-directories and rewrite the HTML, run 
   `fixAllBlogHTML.sh` on the production directory to ensure that 
   everything is correct.
6. In Copy the main.css file stored in `$blogDir/` to 
   `/var/www/myBlog/wp-content/myTheme/dist/styles/` to ensure 
   styling is correct.
7. Delete the remaining contents of `$blogDirData`
8. Log some basic stats about what the script did to 
   `$blogDir/wgetlog.txt`

## Repo

https://github.com/evanwills/wordpress-to-static-site
