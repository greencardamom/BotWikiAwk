#!/usr/local/bin/gawk -E     

# Convert short-form wikiwix.com URLs to long-form

# The MIT License (MIT)
#    
# Copyright (c) 2018 by User:Green Cardamom (at en.wikipedia.org)
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

BEGIN { # Bot cfg

  _defaults = "home      = /home/admin/bots/wikiwixlong/ \
               email     = sample@example.com \
               version   = 1.0 \
               copyright = 2024"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "wikiwixlong"
  Home = G["home"]
  Agent = "Ask me about " BotName " - " G["email"]
  Engine = 0

}

@include "botwiki.awk"
@include "library.awk"

BEGIN { # Bot run

  Mode = "bot"   # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                 #  run via 'project -s' to search cache for articles containing actionable matches
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
    stdErr("Error in wikiwixlong.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logwikiwixlong"
  }

  Count = 0
  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,count,articlenewname,editsummaryname,bn) {

  checkexists(articlename, "wikiwixlong.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  article = deflate(article)

  articlenew = wikiwixlong(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.wikiwixlong.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.wikiwixlong.txt", editsummaryname) 
    links = "URLs"
    if(Count == 1) links = "URL"
    printf("Reformat %s wikiwix.com URLs ([[User:GreenC/WaybackMedic_2.1|Wayback Medic 2.1]])", Count) > editsummaryname
    close(editsummaryname)

    print Count
    exit

  }

  print "0"
  exit

}

#
# Parse article for webcite URLs and if not in long form then expand to long form.
#
function wikiwixlong(article, c,i,field,sep,orig,re,newarticle) {

  c = patsplit(article, field, /[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Ww][Ii][Kk][Ii][Ww][Ii][Xx][.][Cc][Oo][Mm][:]?[8]?[04]?[48]?[30]?[^ |\]}<\n\t]*[^ |\]}<\n\t]/, sep)
  for(i = 1; i <= c; i++) {
    if(length(field[i]) > 0) {
      newurl = wikiwixurl(field[i])
      if(newurl != field[i]) {
        orig = field[i]
        field[i] = newurl
        Count ++
        if(Mode == "find") {
          print "1"
          exit
        }
        else 
          sendlog(Logfile, wikiname, orig " ---- " newurl " ---- wikiwixlong.awk")
      }
    }
  }
  newarticle = unpatsplit(field,sep)
  return newarticle
}

#
# Given a wikiwix URL, return in long format 
#  eg. http://archive.wikiwix.com/cache/20180329074145/http://www.linterweb.fr
#      http://archive.wikiwix.com/cache/?url=http://www.mairie-koudougou.net/&title=Site%20officiel
#      http://archive.wikiwix.com/cache/?url=http%3A%2F%2Fwww.ladepeche.fr%2Farticle%2F2010%2F10%2
#
# API: http://archive.wikiwix.com/cache/?url=http://www.linterweb.fr&apiresponse=1
#
function wikiwixurl(url,  origurl,baseurl,baseurlx,apiurl,command,json,a,doublex) {

      if(url ~ /\/\/archive[.]wikiwix[.]com\/cache\/[0-9]{4,14}/)    # Already long format
        return url

      if(Mode == "find") # Do this to avoid calling the API 
        return "none"

      origurl = url
      if(url ~ /url[=]http[%]253A[%]252F[%]252F/)   # Double encoded 
        url = urldecodeawk(url, "url")
      url = striptitle(url)
      baseurl = aurltourl(url)
      baseurlx = urlencodeawk(urldecodeawk(baseurl), "url")
      apiurl = "http://archive.wikiwix.com/cache/?url=" baseurlx "&apiresponse=1"
      command = Exe["wget"] Wget_opts "-q -O- " shquote(apiurl)
      json = sys2var(command)
      split(json, a, /["]/)
      if(a[14] ~ /[0-9]{4,14}/) {
        return "http://archive.wikiwix.com/cache/" a[14] "/" baseurlx
      }
      else
        return origurl
      return origurl
}


#
# Given a wikiwix URL return the URL in the ?url= argument
#
function aurltourl(url,  dest) {

  if(match(url, /cache\/[?]url[=][^$]*[^$]/, dest)) {
    dest[0] = gsubs("cache/?url=", "", dest[0])
    return dest[0]
  }
  return url

}

#
# If URL is: http://archive.wikiwix.com/cache/?url=http://www.mairie-koudougou.net/&title=Site%20officiel
#  The trailing "&title=...$" is a WikiWix argument and not part of the URL itself. Strip it off.
#
function striptitle(url,  dest,a) {

  gsub(/[&]apiresponse[=][0-9]/, "", url)
  if(match(url, /[&]title[=][^<$]*[^<$]/, dest)) {
    if(split(dest[0], a, /[&][^=]*[=]/) == 2) 
      return strip(gsubs(dest[0], "", url))
  }
  return url
}


# 
# Given a URL, urldecode certain characters
# 
function decodeurl(url) {
        gsub(/%2[Ff]/,"/",url)
        gsub(/%3[Aa]/,":",url)
        gsub(/%3[Ff]/,"?",url)
        return url    
}

