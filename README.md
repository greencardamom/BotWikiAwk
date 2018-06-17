**BotWikiAwk** is a framework of tools and libraries for creating and running bots on Wikipedia.

* Shell tools. No language ecosystems (PhP, Perl, Python). No database systems (SQL, etc). 
* Data files in plain text with a CSV-like structure
* Manage batches of articles of any size, 50 for [[WP:BRFA]] or 50k+ for production runs
* Runs using GNU parallel making full use of multi-core CPUs
* ..or runs on the Toolforge grid across 40+ distributed computers
* Dry-run mode, diffs can be checked before uploading 
* Inline colorized diffs on the command-line 
* Re-run individual pages via a cached copy of the page (download wikisource once, run bot many)
* Installs in a single directory, easily removed
* Includes complete example bots and skeleton bots 
* Includes a general awk library developed over years of writing bots 

[Documentation](https://en.wikipedia.org/wiki/User:GreenC/BotWikiAwk)
