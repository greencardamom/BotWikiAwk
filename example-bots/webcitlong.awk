#!/usr/local/bin/gawk -bE

# Convert short-form Webcite URLs to long-form

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

BEGIN { # Bot cfg

  _defaults = "home      = /home/admin/bots/webcitlong/ \
               email     = sample@example.com \
               version   = 1.0 \
               copyright = 2024"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "webcitlong"
  Home = G["home"]
  Agent = "Ask me about " BotName " - " G["email"]
  Engine = 0

}

@include "botwiki.awk"
@include "library.awk"

BEGIN { # Bot run

  Mode = "bot"    # set to "find" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                  #  run via 'project -s' to search cache for articles containing actionable matches
                  # set to anything else and it will process the article.

  Verifylong = 0  # if an existing URL is already long format, verify if the long portion matches the API long portion
                  # this option is resource heavy as it will trigger a WebCite API call on every webcitation.org URL 

                  # For tracking changes across runs to detect/prevent bot wars with IABot
  Warfile = "/home/adminuser/wmnim/wm2/modules/webcitlong/warfile.log"

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "hvs:l:n:")) != -1) {
      opts++
      if(C == "s")                 #  -s <file>      article.txt source to process.
        articlename = verifyval(Optarg)
      if(C == "l")                 #  -l <dir/>      Directory where logging is sent.. end with "/"
        logdir = verifyval(Optarg)
      if(C == "n")                 #  -n <name>      Wikipedia name of article
        wikiname = verifyval(Optarg)
      if(C == "v")                 #  -v             Verify any existing long porting matches API results
        Verifylong = 1
      if(C == "h") {
        usage()
        exit
      }
  }

  if( ! opts || articlename == "" ) {
    stdErr("Error in webcitlong.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null"
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logwebcitlong"
  }

  Count = 0
  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,count,articlenewname,editsummaryname,templates,bn) {

  checkexists(articlename, "webcitlong.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  if(exists(Warfile))              # Used by botwar() - read once per session
    WarfileFP = readfile(Warfile)

  delete Spacebug 
  Sb = 0
  delete T 
  Tb = 0

  article = deflate(article)

  articlenew = webcitelong(article)
  if(length(Spacebug) > 0)
    articlenew = fixspacebug(articlenew)
  if(length(T) > 0) {
    articlenew = fixurlarg(articlenew)
  }

  if(article != articlenew && length(articlenew) > 10 && Count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.webcitlong.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.webcitlong.txt", editsummaryname) 
    links = "URLs"
    if(Count == 1) links = "URL"
    printf("Reformat %s %s (cf. [[Wikipedia:Using_WebCite#Use_within_Wikipedia|WebCite usage]]) ([[User:Green_Cardamom/WaybackMedic_2|Wayback Medic 2]])", Count, templates) > editsummaryname
    close(editsummaryname)

    print Count
    exit

  }

  print "0"
  exit

}

#
# Reset url= to match archiveurl= so IABot doesn't edit war..
#
function fixurlarg(article,  cite2,c,i,k,dest,desturl,j,url,field,sep,newarticle) {

  cite2 = "[{][{][ ]{0,}[Cc]ite[^}]+}}|[{][{][ ]{0,}[Cc]ita[^}]+}}|[{][{][ ]{0,}[Vv]cite[^}]+}}|[{][{][ ]{0,}[Vv]ancite[^}]+}}|[{][{][ ]{0,}[Hh]arvrefcol[^}]+}}|[{][{][ ]{0,}[Cc]itation[^}]+}}"

  #T[Tb]["wcnewurl"] = https://www.webcitation.org/" id "?url=" xurl frag[0]
  #T[Tb]["wcquery"] =  xurl
  #T[Tb]["wcfrag"] = frag[0]

  c = patsplit(article, field, cite2, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(length(field[i]) > 0) {
        k = 0
        if(match(field[i], /[|][ ]*[Aa]rchive[-]?url[ ]*[=][ ]*https[:]\/\/www[.]webcitation[.]org[^ }|\n\t]*[^ }|\n\t]/, dest) > 0) {
          sub(/[|][ ]*[Aa]rchive[-]?url[ ]*[=][ ]*/, "", dest[0])
          dest[0] = strip(dest[0])
          for(j in T) {
            if(T[j]["wcnewurl"] == dest[0]) {
              if(match(field[i], /[|][ ]*[Uu]rl[ ]*[=][ ]*[Hh][Tt][Tt][Pp][^ }|\n\t]*[^ }|\n\t]/, desturl) > 0) {
                url = strip(desturl[0])
                sub(/[|][ ]*[Uu]rl[ ]*[=][ ]*/, "", url)
                url = strip(url)
                field[i] = subs(url, T[j]["wcquery"] T[j]["wcfrag"], field[i])
                k++
              }
            }
          }
        }
      }
    }
    newarticle = unpatsplit(field,sep)
  }  
  return newarticle


}

#
# Parse article for webcite URLs and if not in long form then expand to long form.
#
function webcitelong(article, c,i,field,sep,orig,re,newarticle) {

  c = patsplit(article, field, /[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Ww][Ee][Bb][Cc][Ii][Tt][Aa][Tt][Ii][Oo][Nn][.][Oo][Rr][Gg][^ <|\]}\n\t]*[^ <|\]}\n\t]/, sep)
  for(i = 1; i <= c; i++) {
    if(length(field[i]) > 0) {
      newurl = webciteurl(strip(field[i]))
      if(newurl != field[i]) {
        orig = field[i]
        field[i] = newurl
        Count ++
        if(Mode == "find") {
          print "1"
          exit
        }
        else 
          sendlog(Logfile, wikiname, orig " ---- " newurl " ---- webcitlong.awk")
      }
    }
  }
  newarticle = unpatsplit(field,sep)
  return newarticle
}

#
# Given a webcite URL, return in long format urlencoded
#  eg. http://www.webcitation.org/65yd5AgqG?url=http%3A//www.infodisc.fr/S_Certif.php
#
#  If url is short-form (eg. http://www.webcitation.org/65yd5AgqG) determine long form via API
#
function webciteurl(url,  pa,pc,id,command,olurl,xurl,xurlbase,olurlbase,alreadylong,frag,chop) {

      if(url ~ /webcitation[.]org\/[^?]*[?][Uu][Rr][Ll][=]/ && Verifylong == 0)    # Already long format
        return url

      if(Mode == "find") # Do this to avoid calling the API 
        return "none"

      # Fragment from original URL
      match(url, /[#][^$]*$/, frag)
      if(!empty(frag[0]))
        frag[0] = urldecodeawk(frag[0])

      pc = split(urlElement(url,"path"),pa,"/")          

      if(pc > 1) { 
        if(pa[2] ~ /query/)
          return url
        id = strip(pa[2]) 

        # head -c needed to work around API bug that sends endless stream of data for certain IDs (eg. 5ZprY4O4g)
        # head will break the stream after 1024 bytes leaving wget with no output stream causing it to cease
        command = Exe["wget"] Wget_opts "-q -O- 'http://www.webcitation.org/query?id=" id "&returnxml=true' | " Exe["head"] " -c 1024"
        xml = sys2var(command)

        # <queryresult><error>Invalid snapshot ID 6ZQeKsigm requested.</error></queryresult>
        if(xml ~ /[<]error[>][ \\n\\t]{0,}[Ii]nvalid snapshot ID/) 
          return url

        match(xml,/<original_url>[^<]*<\/original_url>/,origurl)
        gsub(/<original_url>/,"",origurl[0])
        gsub(/<\/original_url>/,"",origurl[0])
        match(xml,/<redirected_to_url>[^<]*<\/redirected_to_url>/,redirurl)
        gsub(/<redirected_to_url>/,"",redirurl[0])
        gsub(/<\/redirected_to_url>/,"",redirurl[0])
     
        if(length(strip(origurl[0])) == 0 && length(strip(redirurl[0])) > 0)
          xurl = strip(redirurl[0])
        else if(length(strip(origurl[0])) > 0)
          xurl = strip(origurl[0])
        else
          return url

        xurl = urldecodeawk(xurl)

        # Log if original long URL doesn't match API long URL
        if(url ~ /webcitation[.]org\/[^?]*[?]url[=]/ && Verifylong == 1) {   

         # orig URL via the webcite url including frag and encoding
          match(url, /[?][Uu][Rr][Ll][=].*$/, dest)
          gsub(/[?][Uu][Rr][Ll][=]/,"",dest[0])
          # olurl = decodeurl(urlencodepython(urldecodepython(strip(dest[0]))))
          olurl = urldecodeawk(strip(dest[0]))
          if(olurl ~ /['][']/)  {     # URL needs to have space added at end 
            Spacebug[Sb++] = url
            return url
          }

         # Try to remove tracking garbage to avoid bot war with Primefac. 
         # See User_talk:Primefac#PrimeBot17_and_bot_war and User:PrimeBOT/Task_17#Regex_updates
         # "At the moment I have confirmation for the bot to clear utm_, cmpid, and mbid, but I also occasionally run manual scans 
         #  for CNDID, sp_rid, sp_mid, WT.ec_id, and sp(Mailing|User|Job|Report|Pod)Id"
         # Update: skip processing if onwiki url doesn't contain tracking but WebCite API url does

          trackRe = "([?]|[&])([Uu][Tt][Mm][_])|([Cc][Mm][Pp][Ii][Dd])|([Mm][Bb][Ii][Dd])|(Cc][Nn][Dd][Ii][Dd])|([Ss][Pp][_][MmRr][Ii][Dd])|([Ww][Tt][.][Ee][Cc][_][Ii][Dd])|([Ss][Pp](Mailing|User|Job|Report|Pod)[Ii][Dd])"
          if(olurl !~ trackRe && xurl ~ trackRe)
            # gsub(/[?|&]utm_(source|medium|campaign)[=][^&#$]*[^&#$]/,"",xurl)
            return url

         # Remove trailing "?" since the API seems to add it sometimes
          if(substr(xurl, length(xurl), 1) == "?" && substr(olurl, length(olurl), 1) != "?") 
            sub(/[?]$/,"",xurl)

         # Re-add trailing "/" since the API seems to strip it
          if(substr(xurl, length(xurl), 1) != "/" && substr(olurl, length(olurl), 1) == "/") 
            xurl = xurl "/"

         # Remove trailing "/" since the API seems to add it
          if(substr(xurl, length(xurl), 1) == "/" && substr(olurl, length(olurl), 1) != "/") 
            sub(/\/$/,"",xurl)

         # orig URL no-frag no-encoding
          olurlbase = olurl
          sub(/[#][^$]*$/, "", olurlbase)
          olurlbase = tolower(urldecodeawk(olurlbase))

         # xurl (via API) no-frag no-encoding
          xurlbase = xurl
          sub(/[#][^$]*$/, "", xurlbase)
          xurlbase = tolower(urldecodeawk(xurlbase))

#print "url: " url
#print "frag0: " frag[0]
#print "olurlbase: " olurlbase
#print "xurlbase: " xurlbase

          if(olurlbase != xurlbase || frag[0] != urldecodeawk(frag[0])) {


            if(frag[0] != urldecodeawk(frag[0]))          # double encoding error
              frag[0] = urldecodeawk(frag[0])

            xurl = encoderes(xurl)
            frag[0] = encoderes(frag[0])

            Tb++
            T[Tb]["wcnewurl"] = "https://www.webcitation.org/" id "?url=" xurl frag[0]
            T[Tb]["wcquery"] =  xurl
            T[Tb]["wcfrag"] = frag[0]

            if(botwar(wikiname " ---- " url " ---- https://www.webcitation.org/" id "?url=" xurl frag[0] " ---- longmismatch ---- webcitlong.awk")) 
              sendlog(Logfile, wikiname, url " ---- https://www.webcitation.org/" id "?url=" xurl frag[0] " ---- botwar ---- webcitlong.awk")
            sendlog(Logfile, wikiname, url " ---- https://www.webcitation.org/" id "?url=" xurl frag[0] " ---- longmismatch ---- webcitlong.awk")
            sendlog(Warfile, wikiname, url " ---- https://www.webcitation.org/" id "?url=" xurl frag[0] " ---- longmismatch ---- webcitlong.awk")

           # URL contains unencoded "[]" = mark it with a "@" so fixencodebug() can chop off the trailing portion
            if(olurlbase ~ /[[]/ && olurlbase !~ /[]]/) {
              chop = "@"
            }

            return "https://www.webcitation.org/" id "?url=" xurl frag[0] chop
          }
        }      
        else if(url !~ /webcitation[.]org\/[^?]*[?]url[=]/) {
          xurl = encoderes(xurl)
          frag[0] = encoderes(frag[0])
          return "https://www.webcitation.org/" id "?url=" xurl frag[0]
        }
      }

      return url
}

#
# Check warfile.log for previous attempt to make the same edit in the same article
#
function botwar(logstr, a,i) {

  if(length(strip(WarfileFP)) == 0) 
    return 0
  for(i = 1; i <= splitn(WarfileFP, a, i); i++) {
    if(logstr == strip(a[i])) 
      return 1
  }
  return 0

}

# 
# Add a space at end of URL at certain characters
#
function fixspacebug(article,  i) {

  for(i in Spacebug) {
    if(length(Spacebug[i]) > 0) {
      if(Spacebug[i] ~ /['][']/) {
        newstr = subs("''", " ''", Spacebug[i])
        if(newstr != Spacebug[i])
          Count ++
      }
      article = subs(Spacebug[i], newstr, article)
    }
  }

  return article
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

#
# Given a URL, encode reserved characters for Wiki
#
function encoderes(url) {

        gsub(/[ ]/,"%20",url)
        gsub(/["]/,"%22",url)
        gsub(/[']/,"%27",url)
        gsub(/[<]/,"%3C",url)
        gsub(/[>]/,"%3E",url)
        gsub(/[[]/,"%5B",url)
        gsub(/[]]/,"%5D",url)
        gsub(/[{]/,"%7B",url)
        gsub(/[}]/,"%7D",url)
        gsub(/[|]/,"%7C",url)

        return url
}

