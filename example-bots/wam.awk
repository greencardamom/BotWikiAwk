#!/usr/local/bin/gawk -bE     

#
# wam - merge {{wayback}} and {{webcite}} --> {{webarchive}}
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2018 User:GreenC -> en.wikipedia.org
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

#
# Code is from 2016 mostly. Could still be useful on wikis still using {{wayback}}. inflate() needs updating
#

BEGIN {
  BotName = "wam"
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
    stdErr("Error in wam.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logwam"
  }

  Count = 0
  main()

}

function main(article,c,i,s,a,j,pa,pc,pan,pp,hold,arg,argfield,field,sep,sep2,sep3,command,api,datetype,bn) {

  checkexists(articlename, "wam.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  datetype = setdatetype(article)  # check for {{dmy}} or {{mdy}} in article

  article = deflate(article)  # remove newlines etc..

  c = patsplit(article, field, /{[ ]?{[ ]?[Ww]ay[Bb]ack[^}]*}[ ]?}|{[ ]?{[ ]?[Ww]ay[Bb]ack[Dd]ate[^}]*}[ ]?}|{[ ]?{[ ]?[Ww]eb[Aa]rchiv[ ]?[|][^}]*}[ ]?}|{[ ]?{[ ]?[Ww]eb[Cc]ite[^}]*}[ ]?}|{[ ]?{[ ]?[Ww]eb[Cc]itation[^}]*}[ ]?}/, sep)
  for(i = 1; i <= c; i++) {
    s = split(field[i], a, "|")
    if(s < 2) continue
    delete hold
    for(j = 1; j <= s; j++) {
                                                                 # Parse old templates into hold[] array

      argfield = strip(a[j])
      argfield = stripwikicomments(argfield)
      if(j == 1) {                                               # skip leading "{{wayback"
        hold["service"] = service(argfield)
        continue
      }
      arg = getnamedarg(striparg(argfield))
      if(arg == 0) {                                             # positional parameter
        if(j == 2) {
          hold["url"] = striparg(argfield)
          split(hold["url"], pp, " ")
          hold["url"] = strip(pp[1])
        }
        if(j == 3 && hold["service"] == "wayback") {
          hold["title"] = striparg(argfield)
        }
        if(j == 4 && hold["service"] == "wayback")
          hold["date"] = striparg(argfield)
      }
      else if(arg == "posnumber") {                              # numbered positional parameter (1=, 2=)
        pc = split(argfield, pa, "=")
        if(pc > 1) {
          pan = strip(pa[1])
          if(pan == "1") {
            hold["url"] = striparg(pa[2])
            split(hold["url"], pp, " ")
            hold["url"] = strip(pp[1])
          }
          else if(pan == "2") {
            hold["title"] = striparg(pa[2])
          }
          else if(pan == "3") {
            hold["date"] = striparg(pa[2])
          }
        }
      }
      else if(arg == "url") {
        gsub(/^[ ]{0,}[Uu][Rr][Ll][ ]{0,}[=]/,"",argfield)
        hold["url"] = striparg(argfield)
        split(hold["url"], pa, " ")
        hold["url"] = strip(pa[1])
                                                                  # Fix some known formatting bugs

        if(hold["service"] == "webcite" && hold["url"] ~ /https[:]\/\/web[.]http[:]\/\/w?w?w?[.]?webcitation/)
          gsub(/^https[:]\/\/web[.]/,"",hold["url"])
        if(hold["service"] == "wayback" && hold["url"] ~ /http[:]\/\/w?w?w?[.]?webcitation[.]org\/query[?]url[=]http/)
          gsub(/^http[:]\/\/w?w?w?[.]?webcitation[.]org\/query[?]url[=]/,"",hold["url"])

      }
      else if(arg == "wayback") {
        gsub(/^[ ]{0,}[Ww]ayback[ ]{0,}[=]/,"",argfield)
        hold["date"] = striparg(argfield)
      }
      else if(arg == "date") {
        gsub(/^[ ]{0,}[Dd]ate[ ]{0,}[=]/,"",argfield)
        hold["date"] = striparg(argfield)
      }
      else if(arg == "dateformat") {
        gsub(/^[ ]{0,}[Dd]ateformat[ ]{0,}[=]/,"",argfield)
        hold["dateformat"] = striparg(argfield)
      }
      else if(arg == "text") {
        gsub(/^[ ]{0,}[Tt]ext[ ]{0,}[=]/,"",argfield)
        hold["title"] = striparg(argfield)
      }
      else if(arg == "name") {
        gsub(/^[ ]{0,}[Nn]ame[ ]{0,}[=]/,"",argfield)
        hold["title"] = striparg(argfield)
      }
      else if(arg == "tutle") {
        gsub(/^[ ]{0,}[Tt]utle[ ]{0,}[=]/,"",argfield)
        hold["title"] = striparg(argfield)
      }
      else if(arg == "tile") {
        gsub(/^[ ]{0,}[Tt]ile[ ]{0,}[=]/,"",argfield)
        hold["title"] = striparg(argfield)
      }
      else if(arg == "title") {
        gsub(/^[ ]{0,}[Tt]itle[ ]{0,}[=]/,"",argfield)
        hold["title"] = striparg(argfield)
      }
      else if(arg == "mf") {
        gsub(/^[ ]{0,}[Mm][Ff][ ]{0,}[=]/,"",argfield)
        hold["df"] = striparg(argfield)
      }
      else if(arg == "md") {
        gsub(/^[ ]{0,}[Mm][Dd][ ]{0,}[=]/,"",argfield)
        hold["df"] = striparg(argfield)
      }
      else if(arg == "mdy") {
        gsub(/^[ ]{0,}[Mm][Dd][Yy][ ]{0,}[=]/,"",argfield)
        hold["df"] = striparg(argfield)
      }
      else if(arg == "df") {
        gsub(/^[ ]{0,}[Dd][Ff][ ]{0,}[=]/,"",argfield)
        hold["df"] = striparg(argfield)
      }
      else if(arg == "nolink") {
        gsub(/^[ ]{0,}[Nn]olink[ ]{0,}[=]/,"",argfield)
        hold["nolink"] = striparg(argfield)
      }
      else if(arg == "quote") {
        gsub(/^[ ]{0,}[Qq]uote[ ]{0,}[=]/,"",argfield)
        hold["quote"] = striparg(argfield)
      }
    }

    if(istemplate(hold["date"], "date")) {          # Try to untangle embedded {{date}} subarguments
      hold["date"] = InnerDd[hold["date"]]
      if(hold["date"] ~ /mdy/) {
        hold["date"] = ""
        hold["dateformat"] = "mdy"
      }
      else if(hold["date"] ~ /dmy/) {
        hold["date"] = ""
        hold["dateformat"] = "dmy"
      }
      else if(hold["date"] ~ /iso/) {
        hold["date"] = ""
        hold["dateformat"] = "iso"
      }
      else if(hold["date"] ~ /ymd/) {
        hold["date"] = ""
        hold["dateformat"] = "ymd"
      }
      else if(hold["date"] ~ /none/) {
        hold["date"] = ""
      }
      else if(hold["date"] ~ /[|]/)
        hold["date"] = ""
    }

                                                                 # Build new webarchive template

    hold["webarchivetitle"] = hold["title"]
    hold["webarchivenolink"] = hold["nolink"]


    if(hold["service"] == "wayback") {

      if(hold["date"] == "") {  # Date missing. Get nearest available date from Wayback API
        command = "wget --header=\"Wayback-Api-Version: 2\" --post-data=\"url=" hold["url"] "&closest=before&statuscodes=200&statuscodes=203&statuscodes=206&tag=&timestamp=20070101\" -q -O- \"http://archive.org/wayback/available\""
        api = sys2var(command)
        match(str, /(.*)(timestamp["][:] ["][^"]*["])(.*)/,sep2)
        if(sep2[2] !~ /"20070101"/) {
          split(sep2[2], sep3,/["]/)
          hold["date"] = sep3[3]
        }
      }

      if(hold["date"] == "")  # Date missing. Default to "*" index
        hold["date"] = "*"

      hold["webarchiveurl"] = "https://web.archive.org/web/" hold["date"] "/" hold["url"]

      if(hold["date"] == "*") hold["webarchivedate"] = "*"
      fullnumber = substr(strip(hold["date"]),1,8)                               # 20160901
      if(isanumber(fullnumber)) {
        yeardigit = substr(fullnumber,1,4)                                       # 2016
        monthdigitz = monthdigit = substr(fullnumber,5,2)                        # 01
        daydigitz = daydigit = substr(fullnumber,7,3)                            # 09
        gsub(/^0/,"",monthdigit)                                                 # 1
        gsub(/^0/,"",daydigit)                                                   # 9
        monthname = digit2month(monthdigit)                                      # January

        if(length(fullnumber) == 4) hold["webarchivedate"] = yeardigit
        else if(length(fullnumber) == 6) hold["webarchivedate"] = monthname " " yeardigit
        else if(length(fullnumber) > 7) {
          if(hold["df"] ~ /[Yy][Ee]?[Ss]?/ || hold["df"] ~ /[Dd][Mm][Yy]/ || (datetype == "dmy" && hold["df"] == "" ) )
            hold["webarchivedate"] = daydigit " " monthname " " yeardigit        # dmy
          else if(hold["df"] ~ /[Nn][Oo]?/ || hold["df"] ~ /[Mm][Dd][Yy]/ )
            hold["webarchivedate"] = monthname " " daydigit ", " yeardigit       # mdy
          else if(hold["df"] ~ /[Ii][Ss][Oo]/ )
            hold["webarchivedate"] = yeardigit "-" monthdigitz "-" daydigitz     # iso
          else
            hold["webarchivedate"] = monthname " " daydigit ", " yeardigit       # mdy (default)
        }
      }
    }

    else if(hold["service"] == "webcite") {

      hold["webarchiveurl"] = webciteurl(hold["url"])

      if(hold["dateformat"] !~ /[Mm][Dd][Yy]|[Dd][Mm][Yy]|[Ii][Ss][Oo]|[Yy][Mm][Dd]/)
        hold["dateformat"] = datetype
      pc = split(urlElement(hold["url"],"path"),pa,"/")
      if(pc > 1) {
        if(pa[2] ~ /query/)
          hold["webarchivedate"] = hold["date"]
        else {
          hold["webciteid"] = strip(pa[2])
          command = Exe["base62"] " \"" hold["webciteid"] "\""
          rawdate = sys2var(command)
          if(rawdate == "error") {
            hold["webarchivedate"] = hold["date"]
          }
          else {
            pc = split(rawdate,pa,"|")
            if(pc == 4) {
              if(hold["dateformat"] ~ /[Mm][Dd][Yy]/)
                hold["webarchivedate"] = strip(pa[1])
              else if(hold["dateformat"] ~ /[Dd][Mm][Yy]/)
                hold["webarchivedate"] = strip(pa[2])
              else if(hold["dateformat"] ~ /[Ii][Ss][Oo]/)
                hold["webarchivedate"] = strip(pa[3])
              else if(hold["dateformat"] ~ /[Yy][Mm][Dd]/)
                hold["webarchivedate"] = strip(pa[4])
              else {
                hold["webarchivedate"] = hold["date"]
              }
            }
            else {
              hold["webarchivedate"] = hold["date"]
            }
          }
        }
      }
      else {
        hold["webarchivedate"] = hold["date"]
      }
    }

    sand = "{{webarchive |url=" hold["webarchiveurl"]
    if(length(hold["webarchivedate"]) > 0)
      sand = sand " |date=" hold["webarchivedate"]
    if(length(hold["webarchivetitle"]) > 0)
      sand = sand " |title=" hold["webarchivetitle"]
    if(length(hold["webarchivenolink"]) > 0)
      sand = sand " |nolink="
    sand = sand " }}"
    if(length(hold["quote"]) > 0)
      sand = sand " Quote: " hold["quote"]

    field[i] = sand

    sendlog(Logfile, wikiname, hold["service"] " ---- " hold["url"] " ---- " hold["webarchiveurl"] " ---- wam.awk")

  }

  articlenew = unpatsplit(field, sep)

  if(article != articlenew && length(articlenew) > 10 && c > 0) {

    articlenew = inflate(articlenew)  # Restore newlines etc..

    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.wam.txt", articlenewname)
    printf("%s", articlenew) > articlenewname
    close(articlenewname)

    gsub(bn, "editsummary.wam.txt", editsummaryname)
    templates = "templates"
    if(c == 1) templates = "template"
    printf("%s archive %s merged to {{[[template:webarchive|webarchive]]}} ([[User:Green_Cardamom/Webarchive_template_merge|WAM]])",c,templates) > editsummaryname
    close(editsummaryname)

    print c
    exit

  }

  print "0"
  exit

}

function getnamedarg(str) {


  if(str ~ /^[ ]{0,}[Dd][Ff][ ]{0,}[=]/) return "df"
  if(str ~ /^[ ]{0,}[Mm][Ff][ ]{0,}[=]/) return "mf"
  if(str ~ /^[ ]{0,}[Mm][Dd][ ]{0,}[=]/) return "md"
  if(str ~ /^[ ]{0,}[Mm][Dd][Yy][ ]{0,}[=]/) return "mdy"
  if(str ~ /^[ ]{0,}[Dd]ate[ ]{0,}[=]/) return "date"
  if(str ~ /^[ ]{0,}[Uu][Rr][Ll][ ]{0,}[=]/) return "url"
  if(str ~ /^[ ]{0,}[Dd]ateformat[ ]{0,}[=]/) return "dateformat"
  if(str ~ /^[ ]{0,}[Tt]utle[ ]{0,}[=]/) return "tutle"
  if(str ~ /^[ ]{0,}[Tt]itle[ ]{0,}[=]/) return "title"
  if(str ~ /^[ ]{0,}[Tt]ile[ ]{0,}[=]/) return "tile"
  if(str ~ /^[ ]{0,}[Nn]ame[ ]{0,}[=]/) return "name"
  if(str ~ /^[ ]{0,}[Tt]ext[ ]{0,}[=]/) return "text"
  if(str ~ /^[ ]{0,}[Ww]ayback[ ]{0,}[=]/) return "wayback"
  if(str ~ /^[ ]{0,}[Nn]olink[ ]{0,}[=]/) return "nolink"
  if(str ~ /^[ ]{0,}[Qq]uote[ ]{0,}[=]/) return "quote"

  if(str ~ /^[ ]{0,}[Bb][Oo][Tt][ ]{0,}[=]/) return "bot"
  if(str ~ /^[ ]{0,}[Aa]ccess[-]?date[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Dd]ead[-]?url[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Aa]rchive[-]?url[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Aa]rchive[-]?date[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Pp]ublisher[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Aa]uthor[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Ll]anguage[ ]{0,}[=]/) return "unknown"
  if(str ~ /^[ ]{0,}[Ww]ork[ ]{0,}[=]/) return "unknown"

  if(str ~ /^[ ]{0,}[0-9]{0,}[=]/) return "posnumber"

  if(str ~ /^[^=]*[=]/) {            # positional parameter contains {{=}} make a best guess of type
    if(str ~ /^http/) return "url"
  }

  return 0

}

#
# Given the leading part of a template, return if it's wayback or webcite
#
function service(str) {

  if(str ~ /[Ww]ay[Bb]ack|[Ww]ay[Bb]ack[Dd]ate|[Ww]eb[Aa]rchiv/) return "wayback"
  if(str ~ /[Ww]eb[Cc]ite|[Ww]eb[Cc]itation/) return "webcite"
  return "unknown"

}

#
# Given an argument fragment, strip any extra stuff
#
function striparg(str) {

  str = stripwikicomments(str)
  sub(/[}]{1}[}]{1}$/,"",str)
  str = strip(str)

  return str

}

#
# Given a webcite URL, return in long format urlencoded
#  eg. http://www.webcitation.org/65yd5AgqG?url=http%3A//www.infodisc.fr/S_Certif.php
#
#  If url is short-form (eg. http://www.webcitation.org/65yd5AgqG) determine long form via API
#
function webciteurl(url,  pa,pc,id) {

      if(url ~ /webcitation[.]org\/[^?]*[?]url[=]/)    # Already long format
        return decodeurl(url)

      pc = split(urlElement(url,"path"),pa,"/")
      if(pc > 1) {
        if(pa[2] ~ /query/)
          return url
        id = strip(pa[2])
        xml = http2var("http://www.webcitation.org/query?id=" id "&returnxml=true")
        match(xml,/<original_url>[^<]*<\/original_url>/,origurl)
        gsub(/<original_url>/,"",origurl[0])
        gsub(/<\/original_url>/,"",origurl[0])
        match(xml,/<redirected_to_url>[^<]*<\/redirected_to_url>/,redirurl)
        gsub(/<redirected_to_url>/,"",redirurl[0])
        gsub(/<\/redirected_to_url>/,"",redirurl[0])

        if(length(origurl[0]) == 0 && length(redirurl[0]) > 0)
          xurl = redirurl[0]
        else if(length(origurl[0]) > 0)
          xurl = origurl[0]
        else
          return url

        # Don't encode / : ? but everything else
        # <space> encoded as %20 not +
        # webcitation.org ignores the content of ?url= if there is a base-62 ID

        return "http://www.webcitation.org/" id "?url=" wamDecodeurl(urlencodeawk(urldecodeawk(xurl)))

      }

      return url
}

#
# Determine date type - set global Datetype = dmy or mdy
#   default mdy
#
function setdatetype(article) {
  if(article ~ /[{]{0,}[{][ ]{0,}[Uu]se[ ][Dd][Mm][Yy][ ]?[Dd]?a?t?e?s?|[{]{0,}[{][ ]{0,}[Dd][Mm][Yy]|[{]{0,}[{][ ]{0,}[Uu][Ss][Ee][Dd][Mm][Yy]/)
    return "dmy"
  return "mdy"
}

__________________________Utilities________________________________________


function digit2month(n) {

  if(n == 1) return "January"
  else if(n == 2) return "February"
  else if(n == 3) return "March"
  else if(n == 4) return "April"
  else if(n == 5) return "May"
  else if(n == 6) return "June"
  else if(n == 7) return "July"
  else if(n == 8) return "August"
  else if(n == 9) return "September"
  else if(n == 10) return "October"
  else if(n == 11) return "November"
  else if(n == 12) return "December"

}

#
# Given a URL, urldecode certain characters
#
function wamDecodeurl(url) {
        gsub(/%2[Ff]/,"/",url)
        gsub(/%3[Aa]/,":",url)
        gsub(/%3[Ff]/,"?",url)
        return url
}

