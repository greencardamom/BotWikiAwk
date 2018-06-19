#!/usr/local/bin/gawk -bE     

# Merge template {{cite additional archived pages}} --> {{webarchive|format=addlarchives}} 

# The MIT License (MIT)
#    
# Copyright (c) 2016 by User:Green Cardamom (at en.wikipedia.org)
#   
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR                   
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

BEGIN {
  BotName = "citeaddl"
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  Mode = "bot"   # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                 #  run via 'project -s' to search cache for articles containing actionable matches
                 # set to anything else and it will process the article.


  Re = "{{[ ]{0,}[Cc]ite[ ]?[Aa]dditional[ ]?[Aa]rchived[ ][Pp]ages[^}]*}}"

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "hs:l:n:")) != -1) {
      opts++
      if(C == "s")                 #  -s <file>      article.txt source to process.
        articlename = verifyval(Optarg)
      if(C == "l")                 #  -l <dir/>      Directory where logging is sent.. end with "/"
        logdir = verifyval(Optarg)
      if(C == "n")                 #  -n <name>      Wikipedia name of article
        wikiname = verifyval(Optarg)
      if(C == "h") {
        usage()
        exit
      }
  }

  if( ! opts || articlename == "" ) {
    stdErr("Error in citeaddl.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logciteaddl"
  }

  Count = 0
  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,count,articlenewname,editsummaryname,templates,bn) {

  checkexists(articlename, "citeaddl.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  article = deflate(article)

  articlenew = citeaddl(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.citeaddl.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.citeaddl.txt", editsummaryname) 
    links = "URLs"
    if(Count == 1) links = "URL"
    printf("Reformat %s %s (cf. [[Wikipedia:Using_archive.is#Use_within_Wikipedia|Archive.is usage]]) ([[User:Green_Cardamom/WaybackMedic_2.1|Wayback Medic 2.1]])", Count, templates) > editsummaryname
    close(editsummaryname)

    print Count
    exit

  }

  print "0"
  exit

}

#
# Do the merge
#
function citeaddl(article, c,i,field,sep,orig,sre) {

  c = patsplit(article, field, Re, sep)     
  for(i = 1; i <= c; i++) {
    orig = field[i]
    gsub(/[Cc]ite [Aa]dditional [Aa]rchived [Pp]ages[ ]?/,"webarchive |format=addlarchives ", field[i])
    gsub(/[Aa]rchive[-]?url/, "url", field[i])
    gsub(/[Aa]rchive[-]?date/, "date", field[i])
    if(orig != field[i]) {
      Count++
      sendlog(Logfile, wikiname, orig " ---- citeaddl.awk")
    }
  }
  newarticle = unpatsplit(field,sep)
  return newarticle

}

