**BotWikiAwk** is a framework of tools and libraries for creating and running bots on Wikipedia.

* Bot management tools compatible with bots written in any language
* .. and/or libraries for bots written in awk
* Non-SQL. Data files in plain-text
* Manage batches of articles of any size, 50 for WP:BRFA or 50k to unlimited for production runs
* Runs using GNU parallel making full use of multi-core CPUs
* ..or on the Toolforge grid across 40+ distributed computers
* Dry-run mode, diffs can be checked out before uploading 
* Inline colorized diffs on the command-line 
* Re-run individual pages via a cached copy of the page (download wikisource once, run bot many)
* Installs in a single directory, easily removed
* Includes complete example bots and skeleton bots 
* Includes a general awk library developed over years of writing bots 
* Includes a standalone command-line program to interface with the MediaWiki API
* In development and private use since 2016. Public June 2018

Example run a 50k-article bot with three commands:

	makebot ~/BotWikiBot/bots/accdate
	project -c -p accdate20181102.00001-50000
	runbot accdate20181102.00001-50000 auth

[Documentation](https://en.wikipedia.org/wiki/User:GreenC/BotWikiAwk)
