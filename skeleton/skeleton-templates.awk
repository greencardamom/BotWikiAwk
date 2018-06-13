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

 # Regex for citation templates. Customize ReCites for the templates you wish to target 
  ReSpace = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"
  ReTemplate = "[{]" ReSpace "[{][^}]+[}]" ReSpace "[}]"
  ReCites  = "[{][ ]{0,}[{]" ReSpace "(Citation|Cite speech|Cite conference|Cite newsgroup|Cite techreport|Cite journal|Cite interview|Cite thesis|Cite bioRxiv|Cite serial|Cite episode|Cite arXiv|Cite report|Cite press release|Cite map|Cite magazine|Cite book|Cite encyclopedia|Cite sign|Cite news|Cite AV media notes|Cite AV media)" ReSpace "[|][^}]+[}][ ]{0,}[}]"

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

  article = deflate(article)

  articlenew = XXXXXX(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
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
#   . extract templates in article and do something to each. Return modified article.
#
function XXXXXX(article,  c,field,sep,i) {

  c = patsplit(article, field, reCites, sep)
  for(i = 1; i <= c; i++) {

    if(field[i] !~ /[{][{][^{]*[{][{]/) {  # skip embeded templates not found by deflate()

      # do something with the template as contained in field[i] 

      # Create a log entry to track bot activity. Two methods these are the same:
      #  . print wikiname " ---- " data1 " ---- " data2 " ---- in XXXXXX.awk" >> Logfile
      #  . sendlog(Logfile, wikiname, data1 " ---- " data2 " ---- in XXXXXX.awk")

      # increase global Count for each change 
      #   Count++

    }
  } 
  article = unpatsplit(article)

  return article

}

__________________________Utilities________________________________________

#
# deflate - collapse select but common things so that embedded templates don't interfere with parsing 
#
#   . You will still need to double-check each citation in the main code - deflate() can't get them all:
#
#        if(template ~ /[{][{][^{]*[{][{]/) { skip processing unable to parse due to embedded template }
#
#   . creates global arrays InnerDd[], InnerId[], InnerSd[]
#
function deflate(article,   c,i,field,sep,inner,re,loopy,j,codename) {

  # Replace "{{date|May 2017}}" with "dateZzPp1" and populate global array InnerDd["dateZzPp1"] = "{{date|May 2017}}"
  re = "[{]" ReSpace "[{]" ReSpace "date[^}]*[}]" ReSpace "[}]"
  c = patsplit(article, field, re, sep)      
  while(i++ < c) {
    re = "[{]" ReSpace "[{][^{]*[{]" ReSpace "[{]"
    if(field[i] ~ re) 
      continue
    codename = "dateZzPp" i
    InnerDd[codename] = field[i]
    field[i] = codename
  }
  if(c > 0) article = unpatsplit(field, sep)

  # Replace "|id={{template|data}}" with "|id=idQqYy1" and populate global array InnerId["idQqYy1"] = "|id={{template|data}}"
  # Repeat for other commonly templated arguments
  split("id|ref|url|author|title|work|publisher|contribution|quote|website|editor|series", loopy, /[|]/)
  for(j in loopy) {
    i = c = 0
    re = "[|]" ReSpace loopy[j] ReSpace "[=]" ReSpace ReTemplate
    c = patsplit(article, field, re, sep)
    while(i++ < c) {
      if(match(field[i], ReTemplate, inner) ) {
        re = "[{]" ReSpace "[{][^{]*[{]" ReSpace "[{]"
        if(field[i] ~ re) 
          continue
        codename = loopy[j] "QqYy" i
        field[i] = gsubs(inner[0], codename, field[i])
        InnerId[codename] = inner[0]
      }
    }
    if(c > 0) article = unpatsplit(field, sep)
  }

  # Replace "{{template}}" with "aAxXQq1" and populate global array InnerSd["aAxXQq1"] = "{{template}}"
  # Repeat for other common templates
  i = 0
  split("{{=}}|{{!}}|{{'}}|{{snd}}|{{spnd}}|{{sndash}}|{{spndash}}|{{Spaced en dash}}|{{spaced en dash}}|{{·}}|{{•}}|{{\\}}|{{en dash}}|{{em dash}}|{{-'}}", loopy, /[|]/)
  for(j in loopy) {
    i++
    codename = "aAxXQq" i
    InnerSd[codename] = loopy[j]
    article = gsubs(InnerSd[codename], codename, article)
  }
  return article

}
#
# Re-inflate article in reverse order
#
function inflate(articlenew, i) {

    for(i in InnerSd) 
      articlenew = gsubs(i, InnerSd[i], articlenew)
    for(i in InnerId) 
      articlenew = gsubs(i, InnerId[i], articlenew)
    for(i in InnerDd) 
      articlenew = gsubs(i, InnerDd[i], articlenew)

    return articlenew
}



