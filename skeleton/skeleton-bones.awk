#!/usr/local/bin/gawk -bE     

#
# XXXXXX - bot description
#

# The MIT License (MIT)
#    
# Copyright (c) ZZZZZZ
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
  BotName = "XXXXXX"
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  Mode = "bot"   # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                 #  in "find" mode, run via 'project -s' to search local cache for articles containing actionable matches
                 # set to anything else and it will process the article.

  IGNORECASE = 1

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
    stdErr("Error in XXXXXX.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logXXXXXX"
  }

  Count = 0
  main()

}

function main(  article,articlenew,articlenewname,editsummaryname,bn) {

  checkexists(articlename, "XXXXXX.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  articlenew = XXXXXX(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.XXXXXX.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.XXXXXX.txt", editsummaryname) 

    printf("%s edits by XXXXXX", Count) > editsummaryname  # Customize the edit summary to be more specific
    close(editsummaryname)

    print Count
    exit

  }
  print "0"
  exit

}

#
# XXXXXX - main function
#
function XXXXXX(article,  c,i,field,sep,orig,newarticle,newcite,j,reCites) {

  # do something to 'article'

  # to create log entry two methods, these do the same:
  #  . print wikiname " ---- " data1 " ---- " data2 " ---- in XXXXXX.awk" >> Logfile
  #  . sendlog(Logfile, wikiname, data1 " ---- " data2 " ---- in XXXXXX.awk")

  # increase global Count for each change     
  #   Count++

  return article

}

