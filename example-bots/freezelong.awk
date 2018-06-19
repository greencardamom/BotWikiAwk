#!/usr/local/bin/gawk -bE     

# Convert short-form freezepage.com URLs to long-form

# The MIT License (MIT)
#    
# Copyright (c) 2017 by User:Green Cardamom (at en.wikipedia.org)
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
  BotName = "freezelong"
}

@include "botwiki.awk"
@include "library.awk"


BEGIN {

  Mode = "bot"   # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                 #  run via 'project -s' to search cache for articles containing actionable matches
                 # set to anything else and it will process the article.

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
    stdErr("Error in freezelong.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logfreezelong"
  }

  Count = 0
  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,count,articlenewname,editsummaryname,templates,bn) {

  checkexists(articlename, "freezelong.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  article = deflate(article)

  articlenew = freezelong(article)

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.freezelong.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.freezelong.txt", editsummaryname) 
    links = "URLs"
    if(Count == 1) links = "URL"
    printf("Reformat %s %s ([[User:Green_Cardamom/WaybackMedic_2.1|Wayback Medic 2.1]])", Count, templates) > editsummaryname
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
function freezelong(article, c,i,field,sep,orig,re) {

  c = patsplit(article, field, /[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Ff][Rr][Ee][Ee][Zz][Ee][Pp][Aa][Gg][Ee][.][Cc][Oo][Mm][:]?[8]?[04]?[48]?[30]?[^ |\]}\n\t]*[^ |\]}\n\t]/, sep)
  for(i = 1; i <= c; i++) {
    if(length(field[i]) > 0) {
      newurl = freezeurl(field[i])
      if(newurl != field[i]) {
        orig = field[i]
        field[i] = newurl
        Count ++
        if(Mode == "find") {
          print "1"
          exit
        }
        else 
          sendlog(Logfile, wikiname, orig " ---- " newurl " ---- freezelong.awk")
      }
    }
  }
  newarticle = unpatsplit(field,sep)
  return newarticle
}

#
# Given a freezepage URL, return in long format 
#  eg. http://www.freezepage.com/1476643019VQWHMCLASH?url=http://www.recordreport.com.ve/publico/anglo/
#
function freezeurl(url,  c, i, field, command, xml) {

      if(url ~ /freezepage[.]com\/[^?]*[?]url[=]/)    # Already long format
        return url

      if(Mode == "find") # Do this to avoid calling the API 
        return "none"

      command = Exe["wget"] Wget_opts "-q -O- '" url "'"
      xml = sys2var(command)
      
      c = patsplit(xml, field, /[<][Aa] href[^>]*[>]/)
      for(i in field) {
        if(field[i] ~ /http/) 
          # href="http://www.recordreport.com.ve/publico/anglo/"
          if( match(field[i], /["]http[^"]*[^"]/, dest) > 0) {
            gsub(/^["]/,"",dest[0])
            if(dest[0] !~ /w3[.]org|freezepage[.]com/)
              return url "?url=" urlencodeawk(urldecodeawk(dest[0]), "url") 
          }
      }

      return url
}

