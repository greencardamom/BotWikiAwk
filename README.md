**BotWikiAwk** is a framework of tools and libraries for creating and running bots on Wikipedia.

* Shell tools. No ecosystems (PhP, Perl, Python). No database systems (SQL, etc) 
* Framework compatible with bots written in other languages
* Data files in plain text with a CSV-like structure
* Manage batches of articles of any size, 50 for WP:BRFA or 50k+ for production runs
* Runs using GNU parallel making full use of multi-core CPUs
* ..or runs on the Toolforge grid across 40+ distributed computers
* Dry-run mode, diffs can be checked out before uploading 
* Inline colorized diffs on the command-line 
* Installs in a single directory, easily removed
* Includes complete example bots and skeleton bots 
* Includes a general awk library developed over years of writing bots 
* Includes a command-line interface to the MediaWiki API
* In development and private use since 2016. Public June 2018

Run a bot in three commands:

	makebot ~/BotWikiBot/bots/accdate
	project -c -p accdate20181102.00001-00050
	runbot accdate20181102.00001-00050 auth

[Documentation](https://en.wikipedia.org/wiki/User:GreenC/BotWikiAwk)
