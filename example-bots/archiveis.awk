#!/usr/local/bin/gawk -bE     

# Convert short-form archive.is URLs to long-form per RFC

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
  BotName = "archiveis"
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  Mode = "bot"   # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                 #  run via 'project -s' to search cache for articles containing actionable matches
                 # set to anything else and it will process the article.

  # archive.is, archive.today, archive.li and archive.fo
  Re = "[Hh][Tt][Tt][Pp][Ss]?[:]//[Ww]?[EeWw]?[BbWw]?[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.]([Tt][Oo][Dd][Aa][Yy]|[Ii][Ss]|[Ll][Ii]|[Ff][Oo])[/]"

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
    stdErr("Error in archiveis.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logarchiveislong"
  }

  Count = 0
  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,count,articlenewname,editsummaryname,templates,bn) {

  checkexists(articlename, "archiveis.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  article = deflate(article)

  articlenew = archiveis(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.archiveis.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.archiveis.txt", editsummaryname) 
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
# Parse article for archive.is URLs and if not in long form then expand to long form.
#
#
function archiveis(article, c,i,field,sep,orig,sre) {

  sre = Re "[^ |\\]}\n\t]*[^ |\\]}\n\t]"

  c = patsplit(article, field, sre, sep)     
  for(i = 1; i <= c; i++) {
    if(length(field[i]) > 0) {
      newurl = archiveisurl(field[i])
      if(newurl != field[i]) {
        orig = field[i]
        field[i] = newurl
        Count ++
        if(Mode == "find") {
          print "1"
          exit
        }
        else 
          sendlog(Logfile, wikiname, orig " ---- " newurl " ---- archiveis.awk")
      }
    }
  }
  newarticle = unpatsplit(field,sep)
  return newarticle
}

#
# Given a archive.is URL, return in long format urlencoded
#  eg. http://archive.is/Swibo -> http://archive.is/20130508084054/http://indiestatik.com/
#
#  If url is short-form (eg. http://www.webcitation.org/65yd5AgqG) determine long form via API
#
function archiveisurl(url,  pa,pc,id,sre,c,origurl,step2,field,sep,dest) {

      # Already long format
      # http://archive.is/Fcxt/
      if(split(url, a, "/") > 4)
        return url

      if(Mode == "find") # Do this to avoid calling the API 
        return "none"

      xml = http2var(url)

      if(length(xml) == 0) {
        sendlog(Logfile, wikiname, url " ---- warning : url not working ---- archiveis.awk")
        return url
      }

      # <input id="SHARE_LONGLINK" style="width:600px" value="http://archive.fo/2013.01.25-092321/http://www.hollywood.com/celebrity/186117/Irving_Allen"
      re2 = "[<]input[ ]id[ ]?[=][ ]?[\"][ ]?[Ss][Hh][Aa][Rr][Ee][_ ]?[Ll][Oo][Nn][Gg][Ll][Ii][Nn][Kk][\"][^v]*value[ ]?[=][ ]?[\"][^\"]*[\"]"

      if(match(xml, re2, dest) > 0) {
        if(split(dest[0], a, "\"") > 0) {
          a[6] = convertxml(strip(a[6]))                                            # remove xml codes
          if(a[6] ~ "^[Hh][Tt][Tt][Pp]")
            patsplit(a[6], field, "/", sep)
            gsub(/[.]|[-]|[:]/,"",sep[3])                                           # remove "." and "-" from timestamp
            step2 = unpatsplit(field, sep)
            if( match(step2, /^[Hh][Tt][Tt][Pp][^0-9]*[0-9]{8,14}\//, dest) > 0) {  # encode path portion
              origurl = strip(subs(dest[0], "", step2))

              if(url ~ /^[Hh][Tt][Tt][Pp][Ss]/)
                sub(/^[Hh][Tt][Tt][Pp][:]/,"https:",dest[0])

              if(url ~ /^[Hh][Tt][Tt][Pp][Ss]?[:]\/\/archive[.]is/)
                sub(/^[Hh][Tt][Tt][Pp][Ss]?[:]\/\/archive[.](today|fo|li)/,"https://archive.is",dest[0])
              else if(url ~ /^[Hh][Tt][Tt][Pp][Ss]?[:]\/\/archive[.]li/)
                sub(/^[Hh][Tt][Tt][Pp][Ss]?[:]\/\/archive[.](today|fo|is)/,"https://archive.li",dest[0])
              else if(url ~ /^[Hh][Tt][Tt][Pp][Ss]?[:]\/\/archive[.]today/)
                sub(/^[Hh][Tt][Tt][Pp][Ss]?[:]\/\/archive[.](is|fo|li)/,"https://archive.today",dest[0])

#              return dest[0] urlencodeawk(urldecodeawk(origurl), "url")  # creates too many botwar problems with IABot
              return dest[0] origurl
            }
            else
              return url            
        }
      }
  
      return url
}


# 
# Given a URL, urldecode certain characters
# 
function decodeurl(url) {
        gsub(/%2[Ff]/, "/"   , url)
        gsub(/%3[Aa]/, ":"   , url)
        gsub(/%3[Ff]/, "?"   , url)
        gsub(/%3[Dd]/, "="   , url)
        gsub(/%26/   , "\\&" , url)
        gsub(/%2[Bb]/ , "+" , url)
        return url    
}

