#
# botwikiawk - library for framework
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2024 by User:GreenC (at en.wikipedia.org)
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

@include "syscfg"  # Paths to external programs and static strings

BEGIN {

  # Stop button page - your stop button page. Change to blank string if not using a stop button.
  # This is a global default. You can override it for certain bots by adding StopButton to the bot's
  # "Code block" below, see the example.

  # StopButton = ""
  StopButton = "https://en.wikipedia.org/wiki/User:name/button"

  # Your user page

  UserPage = "https://en.wikipedia.org/wiki/User:name"

  # Your email address (for notifying when stop button is pressed when running from cron etc)
  # Use the default Exe["to_email"] defined in syscfg.awk - or set a different one here

  if(!empty(Exe["to_email"]))
    UserEmail = Exe["to_email"]
  else
    UserEmail = "sample@example.com"

  # Optional location of bot configuration vs. in the top BEGIN{} section of the bot

  if(empty(Agent) && empty(Engine)) { 

    switch(BotName) {

      case "mybot":                                             # Custom bot paths  
        Home = "/home/adminuser/bots/" BotName "/"  
        Agent = UserPage " (ask me about " BotName ")"
        Engine = 0
        break

      default:                                                  # Default both paths
        Home = "/home/adminuser/bots/" BotName "/"  
        Agent = UserPage " (ask me about " BotName ")"
        Engine = 0
        break
    }  

  }

  # Bot executable 

  Exe[BotName]  = Home BotName

  # Bot setup routines
  
  if(BotName != "makebot") {
    if(! checkexists(Home)) {
      stdErr("No known bot '" BotName "'. Run botwikiawk commands while in the home directory of the bot.")
      exit
    } 
    if(Engine != 3) {
      delete Config
      readprojectcfg()
    }
  }
 
}

#
# readprojectcfg - read project.cfg into Config[]
#
function readprojectcfg(  a,b,c,i,p) {

  if(checkexists(Home "project.cfg", "botwiki.awk")) {
    for(i = 1; i <= splitn(Home "project.cfg", a, i); i++) {
      if(a[i] ~ /^[#]/)                        # Ignore comment lines starting with #
        continue
      else if(a[i] ~ /^default.id/) {
        split(a[i],b,"=")
        Config["default"]["id"] = strip(b[2])
      }
      else if(a[i] ~ /[.]data/) {
        split(a[i], b, "=")
        p = gensub(/[.]data$/,"","g",strip(b[1]))
        Config[p]["data"] = strip(b[2])
      }
      else if(a[i] ~ /[.]meta/) {
        split(a[i], b, "=")
        p = gensub(/[.]meta$/,"","g",strip(b[1]))
        Config[p]["meta"] = strip(b[2])
      }
    }
  }

  if(length(Config) == 0) {
    stdErr("botwiki.awk readprojectcfg(): Unable to find project.cfg")
    exit
  }

}

#
# setProject - given a project ID, populate global array Project[]
#
#   Example:
#      setProject(id)
#      print Project["meta"] Project["data"] Project["id"]
#
function setProject(pid) {

        delete Project  # Global array

        if(pid ~ /error/) {
          stdErr("Unknown project id. Using default in project.cfg")
          Project["id"] = Config["default"]["id"]
        }
        else if(pid == "" || pid ~ /unknown/ )  
          Project["id"] = Config["default"]["id"]
        else
          Project["id"] = pid

        for(o in Config) {
          if(o == Project["id"] ) {         
            for(oo in Config[o]) {
              if(oo == "data")
                Project["data"] = Config[o][oo]          
              else if(oo = "meta")
                Project["meta"] = Config[o][oo]          
            }
          } 
        } 

        if(Project["data"] == "" || Project["id"] == "" || Project["meta"] == "" ) {
          stdErr("botwiki.awk setProject(): Unable to determine Project")
          exit
        }

        Project["auth"]   = Project["meta"] "auth"
        Project["index"]  = Project["meta"] "index"
        Project["indextemp"]  = Project["meta"] "index.temp"
        Project["discovered"] = Project["meta"] "discovered"                   # Articles that have changes made 
        Project["discovereddone"] = Project["meta"] "discovered.done"          # Articles successfully uploaded to Wikipedia
        Project["discoverederror"] = Project["meta"] "discovered.error"        # Articles generated error during upload
        Project["discoverednochange"] = Project["meta"] "discovered.nochange"  # Articles with no change during upload
}

#
# verifypid - check if -p has no value. Usage in getopt()
#
function verifypid(pid) {
  if(pid == "" || substr(pid,1,1) ~ /^[-]/)
    return "error"
  return pid
}

#
# verifyval - verify any command-line argument has valid value. Usage in getopt()
#
function verifyval(val) {
  if(val == "" || substr(val,1,1) ~/^[-]/) {
    stdErr("Command line argument has an empty value when it should have something.")
    exit
  }
  return val
}

#
# sendlog - log (append) a line in a text file
#
#   . if you need more than 2 columns (ie. name|msg) format msg with separators in the string itself. 
#   . if flag="noclose" don't close the file (flush buffer) after write. Useful when making many
#     concurrent writes, particularly running under GNU parallel.
#   . if flag="space" use space as separator 
#
function sendlog(database, name, msg, flag,    safed,safen,safem,sep) {

  safed = database
  safen = name
  safem = msg
  gsub(/"/,"\42",safed)
  gsub(/"/,"\42",safen)
  gsub(/"/,"\42",safem)

  if(flag ~ /space/)
    sep = " " 
  else
    sep = " ---- "

  if(length(safem))
    print safen sep safem >> database
  else
    print safen >> database

  if(flag !~ /noclose/)
    close(database)
}

#
# getwikisource - download plain wikisource. 
#
# . default : follows "#redirect [[new name]]" at en.wikipedia.org
# . optional: redir = "follow/dontfollow"
# . optional: hostname = "en" or "commons" etc
# . optional: domain = "wikipedia.org" or "wikimedia.org" etc
# . optional: revid = revision ID
#
# . Returns a proto-tuple see tup() in library.awk 
#
function getwikisource(namewiki,redir,domain,hostname,revid,    f,ex,k,a,b,command,urlencoded,r,redirurl) {

  if(redir !~ /follow|dontfollow/)
    redir = "dontfollow"

  if(! domain)
    domain = "wikipedia.org"
  if(! hostname)
    hostname = "en"

  urlencoded = urlencodeawk(strip(namewiki))

  # See notes on action=raw at: https://phabricator.wikimedia.org/T126183#2775022

  if(empty(revid))
    command = "https://" hostname "." domain "/w/index.php?title=" urlencoded "&action=raw"
  else
    command = "https://" hostname "." domain "/w/index.php?title=" urlencoded "&action=raw&oldid=" revid

  f = http2var(command)
  if(length(f) < 5 && empty(revid)) {                                    # Bug in ?action=raw - sometimes it returns a blank page
    command = "https://" hostname "." domain "/wiki/Special:Export/" urlencoded

    f = http2var(command)
    if(tolower(f) !~ /[#][ ]{0,}redirect[ ]{0,}[[]/) {
      split(f, b, /<text (xml|bytes)[^>]*>|<\/text/)
      f = convertxml(b[2])
    }
  }

  if(tolower(f) ~ /[#][ ]{0,}redirect[ ]{0,}[[]/) {
    print "Found a redirect:"
    match(f, /[#][ ]{0,}[Rr][Ee][^]]*[]]/, r)
    print r[0]
    if(redir ~ /dontfollow/) {
      # print namewiki " : " r[0] >> "redirects"
      return "REDIRECT" SUBSEP r[0]
    }
    gsub(/[#][ ]{0,}[Rr][Ee][Dd][Ii][^[]*[[]/,"",r[0])
    redirurl = strip(substr(r[0], 2, length(r[0]) - 2))

    command = "https://" hostname "." domain "/w/index.php?title=" urlencodeawk(redirurl) "&action=raw"
    f = http2var(command)
  }
  return strip(f) SUBSEP ""

}

#
# validate_datestamp - return "true" if 14-char datestamp is a valid date
#
function validate_datestamp(stamp,   vyear, vmonth, vday, vhour, vmin, vsec) {

  if(length(stamp) == 14) {

    vyear = substr(stamp, 1, 4)
    vmonth = substr(stamp, 5, 2)
    vday = substr(stamp, 7, 2)
    vhour = substr(stamp, 9, 2)
    vmin = substr(stamp, 11, 2)    
    vsec = substr(stamp, 13, 2)

    if (vyear !~ /^(19[0-9]{2}|20[0-9]{2})$/) return "false"
    if (vmonth !~ /^(0[1-9]|1[012])$/) return "false"
    if (vday !~ /^(0[1-9]|1[0-9]|2[0-9]|3[01])$/) return "false"
    if (vhour !~ /^(0[0-9]|1[0-9]|2[0123])$/) return "false"
    if (vmin !~ /^(0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$/) return "false"
    if (vsec !~ /^(0[0-9]|1[0-9]|2[0-9]|3[0-9]|4[0-9]|5[0-9])$/) return "false"

  }
  else
    return "false"

  return "true"

}

#
# whatistempid - return the path/tempid of a name
#
#   . given first field of an index file, return second field
#   . 'indexfile' is optional, if not given use Project["index"]
#   . this function uses global vars INDEXA and INDEXC for performance caching
#       caution observed if accessing multiple index files in the same program 
#
#   Example:
#      > grep "George Wash" $meta/index
#        ==> George Wash|/home/adminuser/wi-awb/temp/wi-awb-0202173111/
#      print whatistempidcache("George Wash")
#        ==> /home/adminuser/wi-awb/temp/wi-awb-0202173111/
#
function whatistempid(name,indexfile,   i,a,b) {

  if(empty(INDEXC)) {
    if(empty(indexfile))
      indexfile = Project["index"]
    if(! checkexists(indexfile) ) {
      stdErr("botwiki.awk (whatistempid): Error unable to find " shquote(indexfile) " for " name )
      return
    }
    for(i = 1; i <= splitn(indexfile, a, i); i++) {
      split(a[i], b, /[|]/)
      INDEXA[strip(b[1])] = strip(b[2])
    }
    INDEXC = length(INDEXA)
  }
  return INDEXA[name]
}

#
# bell - ring bell
#
#   . Exe["bell"] defined using full path/filenames to play a sound
#     eg. Exe["bell"] = "/usr/bin/play -q /home/adminuser/scripts/chord.wav"
#
function bell(  a,i,ok) {

  c = split(Exe["bell"], a, " ")

  if(!checkexists(a[1])) return

  for(i = 2; i <= c; i++) {
    if(tolower(a[i]) ~ /[.]wav|[.]mp3|[.]ogg/) {
      if(!checkexists(a[i])) 
        continue
      else {
        ok = 1
        break
      }
    }
  }
  if(ok) sys2var(Exe["bell"])

}

#
# deflateUniversal
#
# Similar to deflate() but works in any wiki language.
# It will encode any template it finds embeded within a preset collection of template names defined by ReCites 
#
# Example: "{{cite web|title={{whatever}}|author={{Sono}}}}" becomes "{{cite web|title=DefNonOrdCiteAa1.1z|author=DefNonOrdCiteAa1.2z}}"
#          DefNonOrdCiteAa["DefNonOrdCiteAa1.1z"] = "{{whatever}}"
#          DefNonOrdCiteAa["DefNonOrdCiteAa1.2z"] = "{{Sono}}"
#
# inflate() will restore
#
# Requires ReCites to be defined globally eg. 
#          ReCites = "[{][ ]{0,}[{]" ReSpace "(Cita web|Citeweb|Web cite)" ReSpace "[|][^}]+[}][ ]{0,}[}]"
#
function deflateUniversal(article,   c,i,field,sep,inner,inner2,r,k,open,open2,embed,a,cc,ii,newtl,codename,ReSpace,ReTemplate,ReEmbedded,ti) {

  ti = IGNORECASE
  IGNORECASE = 1

  ReSpace    = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"
  ReTemplate = "[{]" ReSpace "[{][^}]+[}]" ReSpace "[}]"
  ReEmbedded = "[{]" ReSpace "[{][^{]*[{]" ReSpace "[{]"
  # ReCites is defined globally

  # Collapse newlines
  #gsub("\n"," zzCRLFzz",article)

  r = 0

  for(k = 1; k <= 5; k++) {  # Check for up to 5 embedded templates in a cite template (including 2-layer deep)

    c = patsplit(article, field, ReCites, sep)

    for(i = 1; i <= c; i++) {

      if(countsubstring(field[i], "{{") == 1) # no more embedded
        continue

      open1 = open2 = embed = 0
      r++

      cc = split(field[i], a, "")
      for(ii = 1; ii <= cc; ii++) {

        if(a[ii] == "{" && open1 == 1 && open2 == 1) {
          a[ii] = "_HIDEO_"
          embed = 1
        }

        if(a[ii] == "}" && embed == 1) 
          a[ii] = "_HIDEC_"

        if(a[ii] == "{" && open1 == 1 && open2 == 0)
          open2 = 1

        if(a[ii] == "{" && open1 == 0 && open2 == 0)
          open1 = 1

      }

      newtl = join(a, 1, length(a), "")
      gsub("_HIDEO__HIDEO_", "_HIDESETO_", newtl)
      gsub("_HIDEC__HIDEC_", "_HIDESETC_", newtl)
      gsub("_HIDEO_", "{", newtl)
      gsub("_HIDEC_", "}", newtl)
      if(newtl ~ "_HIDESETO_" && newtl ~ "_HIDESETC_") {
        if(match(newtl, "_HIDESETO_.*$", inner) > 0) {
          if(newtl ~ "^[{][{][^{]+[{]") continue # safety checks
          if(inner[0] !~ "_HIDESETC_") continue
          codename = "DefNonOrdCiteAa1." r "z"
          if(countsubstring(inner[0], "_HIDESETO_") == 2) {  # embedded within embedded
            inner[0] = subs("_HIDESETO_", "{{", inner[0])
            if(match(inner[0], "_HIDESETO_.*$", inner2) > 0) {
              newtl = gsubs(inner2[0], codename, newtl)
              gsub("_HIDESETO_", "{{", inner2[0])
              gsub("_HIDESETC_", "}}", inner2[0])
              gsub("_HIDESETO_", "{{", newtl)
              gsub("_HIDESETC_", "}}", newtl)
              DefNonOrdCiteAa[codename] = inner2[0]
              field[i] = newtl
            }
          }
          else {
            newtl = gsubs(inner[0], codename, newtl)
            gsub("_HIDESETO_", "{{", inner[0])
            gsub("_HIDESETC_", "}}", inner[0])
            gsub("_HIDESETO_", "{{", newtl)
            gsub("_HIDESETC_", "}}", newtl)
            DefNonOrdCiteAa[codename] = inner[0]
            field[i] = newtl
          }
        }
      }
    }
    article = unpatsplit(field,sep)
  }
  IGNORECASE = ti
  return article

}

#
# Encode certain templates to plain-text. Map encodings to global tables so they can be restored by inflate()
#
#    eg. {{cite web |date={{date|1970}} | title=Year}} --> {{cite web |date=DefNonOrdGenAa1.1 | title=Year}}
#        DefNonOrdGenAa["DefNonOrdGenAa1.1"] = "{{date|1970}}"
#
#  There are three tables DefOrdGenAa[], DefNonOrdGenAa[], DefNonOrdCiteAa[]. The word "Def" means deflate.
#     The words "Ord" and "NonOrd" mean "Ordered" and "NonOrdered". The words "Gen" and "Cite" mean "Generic".
#     Thus DefOrdGenAa means in the Deflate proc, an Ordered/Generic table, with identifier Aa.  
#
#  Tables can be "Ordered" or "NonOrdered". Ordered tables are exspensive to create, they are only used when later   
#     needed to identify the specific encoded string in the wikisource. Most are "NonOrdered" as the encoding exists 
#     merely to convert embedded templates to plain text to make regex parsing easier. 
#  Tables can be "Generic" or "Cite". Generic means the encoding is done on the entire wikisource. Cite means the 
#     encoding is limited to a certain sub-set of citation argument names.
#
#  Encoding format: given DefOrdGenAa1.1, the first 1 is the position in the split list (see below for DefOrdGenAa 
#     eg. "=" is 1, "!" is 2, etc). The .1 is the count in the article. 
#     So if there were 5 {{!}} they would be coded DefOrdGenAa2.1z -> DefOrdGenAa2.5z .. the "z" helps since 2.1 and 2.11
#     are ambiguous in the wikisource (is the trailing "1" part of the source or code?). The "z" is an end-of-string marker.

function deflate(article,opt,   c,i,field,sep,inner,re,loopy,j,codename,ReSpace,ReTemplate,ReEmbedded,ti) {

  ti = IGNORECASE
  IGNORECASE = 1 

  ReSpace    = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"
  ReTemplate = "[{]" ReSpace "[{][^}]+[}]" ReSpace "[}]"
  ReEmbedded = "[{]" ReSpace "[{][^{]*[{]" ReSpace "[{]"

  # Collapse newlines 
  gsub("\n"," zzCRLFzz",article)  

  # 1. Ordered/Generic
  #    "{{template|data}}" --> "DefOrdGenAa1.1" and populate global array DefOrdGenAa["DefOrdGenAa1.1"] = "{{template|data}}"

    # Caution: add new entries to end of split string - order is relevant

  split("=|!", loopy, /[|]/)

  for(j in loopy) {
    re = "[{]" ReSpace "[{]" ReSpace regesc3(loopy[j]) ReSpace "[}]" ReSpace "[}]|[{]" ReSpace "[{]" ReSpace regesc3(loopy[j]) ReSpace "[|][^}]*[}]" ReSpace "[}]"
    c = patsplit(article, field, re, sep)
    if(c > 0) {
      for(i = 1; i <= c; i++) {
        if(field[i] ~ ReEmbedded)
          continue
        codename = "DefOrdGenAa" j "." i "z"
        DefOrdGenAa[codename] = field[i]
        field[i] = codename
      }
      article = unpatsplit(field, sep)
    }
  }

  # 2. Non-ordered/Generic
  #    "{{template|data}}" --> "DefNonOrdGenAa1.1" and populate global array DefNonOrdGenAa["DefNonOrdGenAa1.1"] = "{{template|data}}"

  listre = "("

  # Each listre has a trailing "|"

  # Inline templates
  listre = listre regesc3("'") "|snd|spnd|sndash|spndash|spaced en dash|" regesc3("·") "|" regesc3("•") "|" regesc3("\\") "|en dash|em dash|" regesc3("-'") "|"
  # {{Date}}
  listre = listre "date|"
  # {{Subscription required}}
  listre = listre "Locked content|Pay|Paywall|Premium access|Premium content|Required subscription|Requires subscription|Restricted access|Subreq|Subscribers only|Subscription|Subscription needed|Subscription only|Subscription required|Subscription-required|Subscriptionrequired|"
  # {{Registration required}}
  listre = listre "Reg|Registration|Registration needed|Registration-required|Regreq|"
  # {{HighBeam}}
  listre = listre "highbeam"

  # last entry has no trailing "|"

  listre = listre ")"

  re = "[{]" ReSpace "[{]" ReSpace listre ReSpace "[}]" ReSpace "[}]|[{]" ReSpace "[{]" ReSpace listre ReSpace "[|][^}]*[}]" ReSpace "[}]"
  c = patsplit(article, field, re, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(field[i] ~ ReEmbedded)
        continue
      codename = "DefNonOrdGenAa1." i "z"
      DefNonOrdGenAa[codename] = field[i]
      field[i] = codename
    }
    article = unpatsplit(field, sep)
  }
 
  # 3. Non-ordered/Cite
  #    Encode given templates within citations with no ordering. eg:
  #    "|id={{template|data}}" --> "|id=DefNonOrdCite1.1" and populate global array DefNonOrdCite["DefNonOrdCite1.1"] = "|id={{template|data}}"

  listre = "(id|ref|url|author|title|work|publisher|contribution|quote|website|editor|series)"

  re = "[|]" ReSpace listre ReSpace "[=]" ReSpace ReTemplate               
  c = patsplit(article, field, re, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(match(field[i], ReTemplate, inner) ) {
        if(field[i] ~ ReEmbedded)
          continue
        codename = "DefNonOrdCiteAa1." i "z"
        field[i] = gsubs(inner[0], codename, field[i])
        DefNonOrdCiteAa[codename] = inner[0]
      }
      article = unpatsplit(field, sep)
    }
  }

  # 4. Ordered/Cite
  #  None needed yet

  # Within URLs, convert Wikipedia magic characters to percent-encoded

  if(opt == "magic") {
    c = patsplit(article, field, "http[^ <|\\]}\n\t]*[^ <|\\]}\n\t]", sep)
    if(c > 0) {
      for(i = 1; i <= c; i++) {
        if(match(field[i], /DefOrdGenAa1[.][0-9]{1,2}z/, dest))   # DefOrdGenAa1.?z is {{=}} is "=" is %3D
          field[i] = gsubs(dest[0], "%3D", field[i])
        if(match(field[i], /DefOrdGenAa2[.][0-9]{1,2}z/, dest))   # DefOrdGenAa2.?z is {{!}} is "|" is %7C
          field[i] = gsubs(dest[0], "%7C", field[i])
      }
      article = unpatsplit(field, sep)
    }             
  }

  IGNORECASE = ti

  return article

}
#
# Re-inflate article in reverse order
#
function inflate(articlenew, i) {

    for(i in DefOrdGenAa)
      articlenew = gsubs(i, DefOrdGenAa[i], articlenew)
    for(i in DefNonOrdGenAa)
      articlenew = gsubs(i, DefNonOrdGenAa[i], articlenew)
    for(i in DefNonOrdCiteAa)
      articlenew = gsubs(i, DefNonOrdCiteAa[i], articlenew)

    gsub(/[ ]zzCRLFzz/,"\n",articlenew)

    return articlenew
}


#
# Return true if s is an encoded template
#  Optional second argument: date, template, static (ie. ZzPp, QqYy, aAxXQq - respective)
#            
function istemplate(s, code) {

  if(code == "date") {
    if(s ~ /ZzPp/) return 1
  }
  else if(code == "template") {
    if(s ~ /QqYy/) return 1
  }
  else if(code == "static") {
    if(s ~ /aAxXQq/) return 1       
  }    
  else {
    if(s ~ /ZzPp|QqYy|aAxXQq/) return 1       
  }
  return 0
}

#
# isembedded - given a template, return true if it contains an embedded template
#    Example:
#        print isembedded( "{{cite web|date{{august 1|mdy}}" }} ==> 1
#
function isembedded(tl) {
  if (tl ~ /[{][{][^{]*[{][{]/)
    return 1
  return 0
}

#
# stopbutton - check status of stop button page
#
#  . return RUN or STOP
#  . stop button page URL defined globally as 'StopButton' in botwiki.awk BEGIN{} section
#
function stopbutton(button,bb,  command,butt,i) {

  if(empty(StopButton)) return "RUN" # stop button disabled

 # convert https://en.wikipedia.org/wiki/User:GreenC_bot/button
 #         https://en.wikipedia.org/w/index.php?title=User:GreenC_bot/button
  if(urlElement(StopButton, "path") ~ /^\/wiki\// && urlElement(StopButton, "netloc") ~ /wikipedia[.]org/)
    StopButton = subs("/wiki/", "/w/index.php?title=", StopButton)

  command = "timeout --foreground 20s wget -q -O- " shquote(StopButton "&action=raw")
  button = sys2var(command)

  if(button ~ /[Aa]ction[ ]{0,}[=][ ]{0,}[Rr][Uu][Nn]/)
    return "RUN"      

  butt[2] = 2; butt[3] = 20; butt[4] = 60; butt[5] = 240
  for(i = 2; i <= 5; i++) {
    if(length(button) < 2) {           
      stdErr("Button try " i " - ", "n")
      sleep(butt[i], "unix")
      button = sys2var(command)          
    }  
    else break       
  }

  if(length(button) < 2) {              
    stdErr("Aborted Button (page blank? wikipedia down?) - ", "n")        
    return "RUN"               
  }

  if(button ~ /[Aa]ction[ ]{0,}[=][ ]{0,}[Rr][Uu][Nn]/)
    return "RUN"

  stdErr("ABORTED by stop button page. " name)
  while(bb++ < 5)  {                                          
    bell()
    sleep(2)
    bell()
    sleep(4)
  }
  if(Engine == 0)
    sleep(864000, "unix")          # sleep up to 24 days .. no other way to stop GNU parallel from running
  else
    sleep(600, "unix")             # sleep 10 minutes .. for running from cron
  return "STOP"
}

#
# Upload page to Wikipedia
#
#   Example:
#      upload(fp, a[i], "Convert SHORTDESC magic keyword to template (via [[User:GreenC bot/Job 9|shorty]] bot)", G["log"], BotName, "en")
#
# Return 0 if page was not modified for any reason. Return 1 if page was modified.
#
function upload(wikisource, wikiname, summary, logdir, botname, lang, project,    name,command,result,debug,article,i,re,dest,tries,retval) {

    debug = 0  # 0 = off, 1 = list discoveries don't upload, 2 = print stderr msgs

    name = strip(wikiname)

    if(empty(project))
      project = "wikipedia"

    if(debug == 1) {
      stdErr("Found " name)
      print name >> logdir "discovered"
      return 0
    }

    # {{bots|deny=<botlist>}}
    if(match(wikisource, /[{][{][ ]*[Bb]ots[ \t]*[\n]?[ \t]*[|][^}]*[}]/, dest)) {
      re = regesc3(botname) "bot"
      if(dest[0] ~ re) {
        print name " ---- " sys2var(Exe["date"] " +\"%Y%m%d-%H:%M:%S\"") " ---- Error: Bot deny" >> logdir "error"
        return 0
      }
    }

    if(debug == 2) printf("  startbutton - ")
    if(stopbutton() != "RUN") {
      print name " ---- " sys2var(Exe["date"] " +\"%Y%m%d-%H:%M:%S\"") " ---- Stop Button" >> logdir "error"
      if(!empty(UserEmail) && !empty(Exe["mailx"]))
        sys2var(Exe["mailx"] " -s \"NOTICE: " botname " bot halted by stop button.\" " UserEmail " < /dev/null")
      return 0
    }
    if(debug == 2) print "endbutton"

    article = logdir "article"
    print wikisource > article
    close(article)

    if(!empty(name)) {

      tries = 3
      for(i = 1; i <= tries; i++) {

        command = "timeout --foreground 20s " Exe["wikiget"] " -E " shquote(name) " -S " shquote(summary) " -P " shquote(article) " -l " shquote(lang) " -z " shquote(project)
        if(debug == 2) stdErr(command)
        result = sys2var(command)

        if(result ~ /[Ss]uccess/) {
          if(debug == 2) stdErr(botname ".awk: wikiget status: Successful. Page uploaded to Wikipedia. " name)
          print name >> logdir "discovered"
          close(logdir "discovered")
          retval = 1
          break
        }
        else if(result ~ /[Nn]o[-]?[Cc]hange/ ) {
          if(debug == 2) stdErr(botname ".awk: wikiget status: No change. " name)
          print name >> logdir "nochange"
          close(logdir "nochange")
          retval = 0
          break
        }
        else if(i == 3) {
          if(debug == 2) stdErr(botname ".awk: wikiget status: Failure ('" result "') uploading to Wikipedia. " name)
          print name " ---- " sys2var(Exe["date"] " +\"%Y%m%d-%H:%M:%S\"") " ---- upload fail: " result >> logdir "error"
          close(logdir "error")
          retval = 0
          break
        }

        if(debug == 2) printf("Try " i ": " name " - ")
        sleep(2)
      }
    }
    removefile(article)
    return retval
}

#
# Write to file in parallel environment account for file locks                  
#
#  eng 1 or 2 is Toolforge. eng 0 is none or GNU parallel
#         
function parallelWrite(msg, file, eng,    command) {

  if( (eng == 1 || eng == 2 || eng == 3) && !empty(Exe["zotkill"]) ) {
    command = "echo " shquote(msg) " | " Exe["zotkill"] " " shquote(file)
    sys2var(command)
  }
  else {
    print msg >> file
    close(file)
  }
}
