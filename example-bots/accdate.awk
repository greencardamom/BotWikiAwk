#!/usr/local/bin/gawk -bE     

#
# Remove |accessdate= in CS1|2 templates in certain scenarios
#
# https://en.wikipedia.org/wiki/Wikipedia:Bots/Requests_for_approval/GreenC_bot_5
#

# The MIT License (MIT)
#    
# Copyright (c) 2018 by User:GreenC (at en.wikipedia.org)
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
  BotName = "accdate"
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  Mode = "bot"   # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                 #  run via 'project -s' to search cache for articles containing actionable matches
                 # set to anything else and it will process the article.

  IGNORECASE = 1

  ReSpace = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"
  ReCites  = "[{][ ]{0,}[{]" ReSpace "(Citation|Cite speech|Cite conference|Cite newsgroup|Cite techreport|Cite journal|Cite interview|Cite thesis|Cite bioRxiv|Cite serial|Cite episode|Cite arXiv|Cite report|Cite press release|Cite map|Cite magazine|Cite book|Cite encyclopedia|Cite sign|Cite news|Cite AV media notes|Cite AV media)" ReSpace "[|][^}]+[}][ ]{0,}[}]"
  ReCites2 = "[{][ ]{0,}[{]" ReSpace "(Cite journal|Cite books|Cite news|Cite magazine|Cite techreport|Cite thesis|Cite press release|Cite encyclopedia|Cite bioRxiv)" ReSpace "[|][^}]+[}][ ]{0,}[}]"
  ReTail = "[^|}<\n\r\t]*[^|}<\n\r\t]?"
  ReIdents = "[|]" ReSpace "(arxiv|asin|bibcode|biorxiv|citeseerx|doi|eprint|eissn|hdl|issn|jfm|jstor|lccn|mr|oclc|ol|osti|pmc|pmid|rfc|ssrn|zbl|id)" ReSpace "[=]"

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
    stdErr("Error in accdate.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logaccdate"
  }

  Count = 0
  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,count,articlenewname,editsummaryname,bn) {

  checkexists(articlename, "accdate.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  article = deflate(article)

  articlenew = accdate(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.accdate.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.accdate.txt", editsummaryname) 

    printf("Remove %s stray access-date. ([[User:GreenC bot/Job 5|GreenC bot job #5]])", Count) > editsummaryname
    close(editsummaryname)

    print Count
    exit

  }
  print "0"
  exit

}

#
# Parse article for CS1|2 templates and modify article if needed and log if needed
#
function accdate(article,  c,i,field,sep,orig,newarticle,newcite,j,reCites) {

  for(j = 1; j < 3; j++) {
    if(j == 1)
      reCites = ReCites
    else 
      reCites = ReCites2
    c = patsplit(article, field, reCites, sep)
    for(i = 1; i <= c; i++) {
      if(length(field[i]) > 0) {
        delete G
        if(j == 1) 
          newcite = accdate1(field[i])
        else if(j == 2)
          newcite = accdate2(field[i])
        if(newcite != field[i]) {
          orig = field[i]
          field[i] = newcite
          Count ++
          if(Mode == "find") {
            print "1"
            exit
          }
          else 
            sendlog(Logfile, wikiname, gsubs("\n", "", orig) " ---- " gsubs("\n","",newcite) " ---- accdate" j " in accdate.awk")
        }
      }
    }
    article = unpatsplit(field,sep)
  }

  return article
}

#
# Remove |accessdate= in {{Cite book}}, {{Cite news}} and {{Cite journal}} with no |url=. Per the documentation, 
# "Access dates are not required for links to published research papers, published books, or news articles with publication dates." 
# If a publication date is provided, remove |access date=.
#
function accdate2(tl,  debug,tls) {

  debug = 0
  
  if(debug) print "\n_______________accdate2___________________\n"

  if(isembedded(tl)) {  
    if(debug) print tl "\nSkipped: contains an unknown embedded template missed during deflate()\n----"
    return tl
  }

  tls = stripwikicomments(tl)

  # Fill G[] with |arg status
  getstatus(tls, "url")
  getstatus(tls, "access-date")
  getstatus(tls, "date")
  getstatus(tls, "year")

  if(G["status url"] == "yes") {
    if(debug) print tl "\nSkipped: status url = yes\n----"
    return tl
  }
  if(G["status accessdate"] == "no")  {
    if(debug) print tl "\nSkipped: status accessdate = no\n----"
    return tl
  }

  if(debug) print tl "\nstatus url\t\t= " G["status url"] "\nstatus access-date\t= " G["status access-date"] "\nstatus date\t\t= " G["status date"] "\nstatus year\t\t= " G["status year"]

  if(G["status url"] == "no" && G["status access-date"] == "yes" && (G["status date"] == "yes" || G["status year"] == "yes") ) 
    tl = deleteargs(tl,debug)

  if(debug) print "----"

  return tl

}

#
# Remove |accessdate= in CS1|2 templates that don't have a |url= but do have a value assigned to any of the various 'permanent-record' identifiers. 
# Excluding templates {{cite web}}, {{cite podcast}}, and {{cite mailing list}}. Normally |isbn= would be excluded from the identifier list, 
# but if a {{cite book}} it would be included.
#
function accdate1(tl,  tls,re,dest,reIdents,debug) {

  debug = 0
  
  if(debug) print "\n_______________accdate1___________________\n"

  if(isembedded(tl)) {  
    if(debug) print tl "\nSkipped: contains an unknown embedded template missed during deflate()\n----"
    return tl
  }

  tls = stripwikicomments(tl)

  # Fill G[] with |url and |access-date status
  getstatus(tls, "url")
  getstatus(tls, "access-date")

  if(G["status url"] == "yes") {
    if(debug) print tl "\nSkipped: status url = yes\n----"
    return tl
  }
  if(G["status access-date"] == "no")  {
    if(debug) print tl "\nSkipped: status access-date = no\n----"
    return tl
  }

  # special case if a {{cite book}} then include |isbn identifier
  re = "[{][{]" ReSpace "[Cc]ite [Bb]ook" ReSpace "[|]"
  if(tl ~ re) {
    reIdents = subs("|eissn", "|isbn|eissn", ReIdents)
  }
  else
    reIdents = ReIdents

 # Get identifier status
  G["status identifier"] = "no"
  re = reIdents ReSpace ReTail
  if(match(tls, re, dest)) {

    # special case for |id= identifier
    re = "[|]" ReSpace "id" ReSpace "[=]" 
    if(dest[0] ~ re && istemplate(dest[0]))  { # special case for id={{template}} assume it's an external link
      G["status identifier"] = "yes"
    }
    else if(dest[0] ~ re && ! istemplate(dest[0])) {
      G["status identifier"] = "no"
    }

    # every other identifier type
    else {
      gsub(reIdents,"", dest[0])
      dest[0] = strip(strip(dest[0]))
      if(dest[0] !~ /^[<][!]/) {
        if(!empty(dest[0])) 
          G["status identifier"] = "yes"
      }
    }
  }

  if(debug) print tl "\nstatus url\t\t= " G["status url"] "\nstatus access-date\t= " G["status access-date"] "\nstatus identifier\t= " G["status identifier"]

  if(G["status url"] == "no" && G["status access-date"] == "yes" && G["status identifier"] == "yes") 
    tl = deleteargs(tl,debug)

  if(debug) print "----"

  return tl

}

#
# Fill G[] status for an |arg in a citation tls
#
#  getstatus(tls, "date") -->
#   G["status date"] = "yes"
#   G["arg date"] = "exists"
#
#  status = yes means the arg has a valid value. No means it's an empty or invalid value or no arg exists
#  arg = exists means the argument exists in the template regardless of value. Notexists means it doesn't
#
function getstatus(tls,arg,   statusidx,argidx,argre,dest,re,dest2) {

  statusidx = "status " arg
  argidx = "arg " arg
  argre = subs("-", "[-]?", arg)

  G[statusidx] = "yes"

  if(arg == "url") { # special handling of URL
    # check for existing |url but empty or invalid data
    re = "[|]" ReSpace argre ReSpace "[=]" ReSpace ReTail
    if(match(tls, re, dest)) {  
      G[argidx] = "exists"
      re = "[|]" ReSpace argre ReSpace "[=]" ReSpace
      if(match(dest[0], re, dest2)) {
        if(empty(urlElement(strip(gsubs(dest2[0],"",dest[0])), "netloc"))) {      # no discernable domain name in url field
          if(! istemplate(dest[0]))                                               # URL not templated
            G[statusidx] = "no"
        }
      }
    }
    else
      G[argidx] = "notexists"
  }
  else {

    # check for existing |arg but empty or invalid data
    re = "[|]" ReSpace argre ReSpace "[=]" ReSpace ReTail
    if(match(tls, re, dest)) {  
      G[argidx] = "exists"
      if(dest[0] !~ /[0-9]/)  # might improve date check here
        G[statusidx] = "no"
    }
    else
      G[argidx] = "notexists"
  }

  # check for missing |arg
  if(G[statusidx] == "yes") {
    re = "[|]" ReSpace argre ReSpace "[=]"                                                                        
    if(!match(tls, re, dest)) {
      G[statusidx] = "no"
      G[argidx] = "notexists"
    }
    else
      G[argidx] = "exists"
  }
}


#
# Delete |access-date and |url from tl including key and value
#
function deleteargs(tl,debug,  re,dest) {
    re = "[|]" ReSpace "access[-]?date" ReSpace "[=]" ReSpace ReTail ReSpace
    if(match(tl, re, dest)) {
      tl = gsubs(dest[0], "", tl)
      if(debug) print "Change:\tdeleted access-date"
    }
    if(G["arg url"] == "exists") {
      re = "[|]" ReSpace "url" ReSpace "[=]" ReSpace ReTail ReSpace
      if(match(tl, re, dest)) {
        tl = gsubs(dest[0], "", tl)
        if(debug) print "Change:\tdeleted url"
      }
    }
    return tl
}


