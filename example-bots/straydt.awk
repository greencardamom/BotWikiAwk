#!/usr/local/bin/gawk -bE     

# Delete stray {{dead link}} templates 
#   Fix this problem: https://phabricator.wikimedia.org/T154541 
#   Error-check WaybackMedic 

# The MIT License (MIT)
#    
# Copyright (c) 2016-2018 by User:Green Cardamom (at en.wikipedia.org)
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
  BotName = "straydt"
}

@include "botwiki.awk"
@include "library.awk"
@include "atools.awk"

BEGIN {

  Mode = "bot"           # set to "find" or "finddups" and it will search only and exit with a 1 (found something) or 0 (found nothing)
                         #  run via 'project -s' to search cache for articles containing the bug
                         # set to anything else and it will process the article.

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "hs:l:n:")) != -1) {
      opts++
      if(C == "s")                 #  -s <file>      article.txt source to process
        articlename = verifyval(Optarg)
      if(C == "l")                 #  -l <dir/>      Directory where logging is sent
        logdir = verifyval(Optarg)
      if(C == "n")                 #  -n <name>      Wikipedia name of article
        wikiname = verifyval(Optarg)
      if(C == "h") {
        usage()
        exit
      }
  }

  if( ! opts || articlename == "" ) {
    stdErr("Error in straydt.awk (1)")
    print "0"
    exit
  }

  if(wikiname == "" || logdir == "")
    Logfile = "/dev/null" 
  else {
    if(substr(logdir, length(logdir), 1) != "/")
      logdir = logdir "/"
    Logfile = logdir "logstraydt"
  }

  main()

}

function main(article,c,i,field,sep,re,articlenew,loop,dt,articlenewname,editsummaryname,templates,url,startcs) {

  checkexists(articlename, "straydt.awk main()", "exit")
  article = readfile(articlename)
  if(length(article) < 10) {
    print "0"
    exit
  }

  article = deflate(article)

  dead = "[{][ ]{0,1}[{][ ]*[Dd][Ee][Aa][Dd][ -]?[Ll][Ii][Nn][Kk][^}]*[}][ ]{0,1}[}]"
  cbignore = "[{][ ]{0,1}[{][ ]*[Cc][Bb][Ii][Gg][Nn][Oo][Rr][Ee][^}]*[}][ ]{0,1}[}]"
  deadcbignore = dead "[ ]*" cbignore
  deadcbignoredead = dead "[ ]*" cbignore "[ ]*" dead
  eitherdeadcbignore = "(" deadcbignore "|" dead ")"

  # The "xxxre" are defined in atools.awk

  # Wayback

  re[1]  = iare "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[2]  = "[[][ ]?" iare "[^]]*[]][ ]*" eitherdeadcbignore
  re[3]  = eitherdeadcbignore "[ ]*[[][ ]?" iare "[^]]*[]]"

  # WebCite

  re[4]  = wcre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[5]  = "[[][ ]?" wcre "[^]]*[]][ ]*" eitherdeadcbignore
  re[6]  = eitherdeadcbignore "[ ]*[[][ ]?" wcre "[^]]*[]]"

  # Archive.is

  re[7]  = isre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[8]  = "[[][ ]?" isre "[^]]*[]][ ]*" eitherdeadcbignore
  re[9]  = eitherdeadcbignore "[ ]*[[][ ]?" isre "[^]]*[]]"

  # Library of Congress

  re[10]  = locgovre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[11]  = "[[][ ]?" locgovre "[^]]*[]][ ]*" eitherdeadcbignore
  re[12]  = eitherdeadcbignore "[ ]*[[][ ]?" locgovre "[^]]*[]]"

  # Portugal

  re[13]  = portore "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[14]  = "[[][ ]?" portore "[^]]*[]][ ]*" eitherdeadcbignore
  re[15]  = eitherdeadcbignore "[ ]*[[][ ]?" portore "[^]]*[]]"

  # Stanford

  re[16]  = stanfordre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[17]  = "[[][ ]?" stanfordre "[^]]*[]][ ]*" eitherdeadcbignore
  re[18]  = eitherdeadcbignore "[ ]*[[][ ]?" stanfordre "[^]]*[]]"

  # Archive-It.org

  re[19]  = archiveitre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[20]  = "[[][ ]?" archiveitre "[^]]*[]][ ]*" eitherdeadcbignore
  re[21]  = eitherdeadcbignore "[ ]*[[][ ]?" archiveitre "[^]]*[]]"

  # BibAlex

  re[22]  = bibalexre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[23]  = "[[][ ]?" bibalexre "[^]]*[]][ ]*" eitherdeadcbignore
  re[24]  = eitherdeadcbignore "[ ]*[[][ ]?" bibalexre "[^]]*[]]"

  # National Archives (UK)

  re[25]  = natarchivesukre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[26]  = "[[][ ]?" natarchivesukre "[^]]*[]][ ]*" eitherdeadcbignore
  re[27]  = eitherdeadcbignore "[ ]*[[][ ]?" natarchivesukre "[^]]*[]]"

  # Icelandic Archives

  re[28]  = vefsafnre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[29]  = "[[][ ]?" vefsafnre "[^]]*[]][ ]*" eitherdeadcbignore
  re[30]  = eitherdeadcbignore "[ ]*[[][ ]?" vefsafnre "[^]]*[]]"

  # Europa Archives (Ireland)

  re[31]  = europare "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[32]  = "[[][ ]?" europare "[^]]*[]][ ]*" eitherdeadcbignore
  re[33]  = eitherdeadcbignore "[ ]*[[][ ]?" europare "[^]]*[]]"

  # Perma.CC Archives

  re[34]  = permaccre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[35]  = "[[][ ]?" permaccre "[^]]*[]][ ]*" eitherdeadcbignore
  re[36]  = eitherdeadcbignore "[ ]*[[][ ]?" permaccre "[^]]*[]]"

  # Perma.CC Archives (2)

  re[37]  = permacc2re "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[38]  = "[[][ ]?" permacc2re "[^]]*[]][ ]*" eitherdeadcbignore
  re[39]  = eitherdeadcbignore "[ ]*[[][ ]?" permacc2re "[^]]*[]]"

  # Proni Web Archives

  re[40]  = pronire "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[41]  = "[[][ ]?" pronire "[^]]*[]][ ]*" eitherdeadcbignore
  re[42]  = eitherdeadcbignore "[ ]*[[][ ]?" pronire "[^]]*[]]" 

  # UK Parliament

  re[43]  = parliamentre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[44]  = "[[][ ]?" parliamentre "[^]]*[]][ ]*" eitherdeadcbignore
  re[45]  = eitherdeadcbignore "[ ]*[[][ ]?" parliamentre "[^]]*[]]" 

  # UK Web Archive (British Library)

  re[46]  = ukwebre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[47]  = "[[][ ]?" ukwebre "[^]]*[]][ ]*" eitherdeadcbignore
  re[48]  = eitherdeadcbignore "[ ]*[[][ ]?" ukwebre "[^]]*[]]"

  # Athens University 

  re[49]  = greecere "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[50]  = "[[][ ]?" greecere "[^]]*[]][ ]*" eitherdeadcbignore
  re[51]  = eitherdeadcbignore "[ ]*[[][ ]?" greecere "[^]]*[]]"

  # Canada

  re[52]  = canadare "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[53]  = "[[][ ]?" canadare "[^]]*[]][ ]*" eitherdeadcbignore
  re[54]  = eitherdeadcbignore "[ ]*[[][ ]?" canadare "[^]]*[]]"

  # Catalonian Archive

  re[55]  = catalonre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[56]  = "[[][ ]?" catalonre "[^]]*[]][ ]*" eitherdeadcbignore
  re[57]  = eitherdeadcbignore "[ ]*[[][ ]?" catalonre "[^]]*[]]"

  # Estonian Web Archive

  re[58]  = estoniare "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[59]  = "[[][ ]?" estoniare "[^]]*[]][ ]*" eitherdeadcbignore
  re[60]  = eitherdeadcbignore "[ ]*[[][ ]?" estoniare "[^]]*[]]"

  # National Archives USA (NARA)

  re[61]  = narare "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[62]  = "[[][ ]?" narare "[^]]*[]][ ]*" eitherdeadcbignore
  re[63]  = eitherdeadcbignore "[ ]*[[][ ]?" narare "[^]]*[]]"

  # Singapore Archives

  re[64]  = singaporere "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[65]  = "[[][ ]?" singaporere "[^]]*[]][ ]*" eitherdeadcbignore
  re[66]  = eitherdeadcbignore "[ ]*[[][ ]?" singaporere "[^]]*[]]"

  # Slovenian Archives

  re[67]  = slovenere "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[68]  = "[[][ ]?" slovenere "[^]]*[]][ ]*" eitherdeadcbignore
  re[69]  = eitherdeadcbignore "[ ]*[[][ ]?" slovenere "[^]]*[]]"
  
  # Freezepage

  re[70] = freezepagere "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[71] = "[[][ ]?" freezepagere "[^]]*[]][ ]*" eitherdeadcbignore
  re[72] = eitherdeadcbignore "[ ]*[[][ ]?" freezepagere "[^]]*[]]"

  # National Archives US 

  re[73] = webharvestre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[74] = "[[][ ]?" webharvestre "[^]]*[]][ ]*" eitherdeadcbignore
  re[75] = eitherdeadcbignore "[ ]*[[][ ]?" webharvestre "[^]]*[]]"

  # National Archives Australia

  re[76] = nlaaure "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[77] = "[[][ ]?" nlaaure "[^]]*[]][ ]*" eitherdeadcbignore
  re[78] = eitherdeadcbignore "[ ]*[[][ ]?" nlaaure "[^]]*[]]"

  # WikiWix

  re[79] = wikiwixre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[80] = "[[][ ]?" wikiwixre "[^]]*[]][ ]*" eitherdeadcbignore
  re[81] = eitherdeadcbignore "[ ]*[[][ ]?" wikiwixre "[^]]*[]]"

  # York University Archives

  re[82] = yorkre "[^ ]*[ ][ ]*" eitherdeadcbignore
  re[83] = "[[][ ]?" yorkre "[^]]*[]][ ]*" eitherdeadcbignore
  re[84] = eitherdeadcbignore "[ ]*[[][ ]?" yorkre "[^]]*[]]"
  
  # Add new archives above in re[?] and in "allre" below

  allre = iare "|" wcre "|" isre "|" locgovre "|" portore "|" stanfordre "|" archiveitre "|" bibalexre "|" natarchivesukre "|" freezepagere "|" slovenere "|" singaporere "|" narare "|" estoniare "|" catalonre "|" canadare "|" greecere "|" ukwebre "|" parliamentre "|" pronire "|" permaccre "|" europare "|" vefsafnre "|" webharvestre "|" wikiwixre "|screenshots[.]com"

  re[85]  = eitherdeadcbignore "[ ]*{{[ ]?[Ww]ebarchive[^}]*}}"
  re[86]  = "{{[ ]?[Ww]ebarchive[^}]*}}[ ]*" eitherdeadcbignore

 # The number for start of templates hard-coded in loop below

  startcs = 87
  re[87] = "{{[ ]{0,}[Cc]ite[^}]+}}[ ]*" eitherdeadcbignore
  re[88] = "{{[ ]{0,}[Cc]ita[^}]+}}[ ]*" eitherdeadcbignore
  re[89] = "{{[ ]{0,}[Vv]cite[^}]+}}[ ]*" eitherdeadcbignore
  re[90] = "{{[ ]{0,}[Vv]ancite[^}]+}}[ ]*" eitherdeadcbignore
  re[91] = "{{[ ]{0,}[Hh]arvrefcol[^}]+}}[ ]*" eitherdeadcbignore
  re[92] = "{{[ ]{0,}[Cc]itation[^}]+}}[ ]*" eitherdeadcbignore

  articlenew = article

  # Find/Fix duplicates
  articlenew = removedups1(articlenew, deadcbignore)
  articlenew = removedups2(articlenew, deadcbignore, deadcbignoredead)
  if(Mode == "funddups") {
    print "0"
    exit
  }
 
  for(loop = 1; loop <= length(re) ; loop++) {
    c = patsplit(articlenew, field, re[loop], sep)
    if(c > 0) {
      for(i = 1; i <= c; i++) {
        if(field[i] !~ allre)                            # Abort if link is not an archive
          continue
        if(match(field[i], cbignore, dt)) {              # Abort if {{cbignore}} is not a bot=medic  
          if(dt[0] !~ /medic/)
            continue
        }
        if(field[i] ~ freezepagere) {                    # Abort if freezepage.com URL without ?url=http.. it's probably dead
          if(field[i] !~ "[?]url[=][Hh][Tt][Tt][Pp]")
            continue
        }

        if(match(field[i], deadcbignore, dt) == 0)       # Match on {{dead}} or {{dead}}{{cbignore}}
          match(field[i], dead, dt)
        if(countsubstring(field[i], dt[0]) != 1) 
          continue
        if(loop >= startcs) { # CS1|2 templates
          if(field[i] ~ /[Aa]rchive[-]?url[ ]*[=][ ]*[Hh][Tt][Tt][Pp]/) {
            field[i] = subs(dt[0],"",field[i])        
            count++
            if(Mode == "find") {
              print "1"
              exit
            }
            else {
              if(match(field[i], /[Aa]rchive[-]?url[ ]*[=][ ]*[Hh][Tt][Tt][Pp][^ |\]}]*[^ |\]}]/, url)) {
                url[0] = strip(url[0])
                gsub(/[Aa]rchive[-]?url[ ]*[=][ ]*/,"",url[0])
                sendlog(Logfile, wikiname, url[0] " ---- straydt.awk", "noclose")
              }
              else
                sendlog(Logfile, wikiname, "unknown1 (" loop ") ---- straydt.awk", "noclose")
              close(Logfile)
            }
          }
        }
        else {
          field[i] = subs(dt[0],"",field[i])
          count++
          if(Mode == "find") {
            print "1"
            exit
          }
          else 
            sendlog(Logfile, wikiname, "unknown2 (" loop ") ---- straydt.awk")
        }
      }
    }
    if(c > 0)
      articlenew = unpatsplit(field, sep)
  }

  if(count > 0) {
    articlenew = webcitelong(articlenew)
  }

# print articlenew

  if(article != articlenew && length(articlenew) > 10 && count > 0) {

    articlenew = inflate(articlenew)
   
    articlenewname = editsummaryname = articlename

    bn = basename(articlename) "$"

    gsub(bn, "article.straydt.txt", articlenewname) 
    printf("%s", articlenew) > articlenewname 
    close(articlenewname)

    gsub(bn, "editsummary.straydt.txt", editsummaryname) 
    templates = "templates"
    if(count == 1) templates = "template"
    printf("Removed %s redundant {{dead link}} %s ([[User:Green_Cardamom/WaybackMedic_2|Wayback Medic 2]])", count, templates) > editsummaryname
    close(editsummaryname)

    print count
    exit

  }

  print "0"
  exit

}


#
# Remove duplicate pairs of {{dead}}{{cbignore}} created by bug in Medic
#  Example: Line 58: https://en.wikipedia.org/w/index.php?title=Timeline_of_the_2005_French_riots&type=revision&diff=804086878&oldid=801068132
#
function removedups1(article,deadcbi, re,c,field,sep,i,dest) {

  re = "(" deadcbi "){2,}"
  c = patsplit(article, field, re, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(match(field[i], deadcbi, dest) > 0) {
        field[i] = dest[0]
        count++
        if(Mode == "finddups") {
          print "1"
          exit
        }
        else 
          sendlog(Logfile, wikiname, "removedups1 ---- straydt.awk")
      }
    }
    article = unpatsplit(field, sep)
  }
  return article

}

#
# Remove duplicate pairs of {{dead}}{{cbignore}}{{dead}} created by bug in Medic
#  Example: Line 58: https://en.wikipedia.org/w/index.php?title=Timeline_of_the_2005_French_riots&type=revision&diff=804086878&oldid=801068132
#
function removedups2(article,deadcbi,deadcbidead,  c,field,sep,i,dest) {

  c = patsplit(article, field, deadcbidead, sep)
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(match(field[i], deadcbi, dest) > 0) {
        field[i] = subs(dest[0], "", field[i])
        count++
        if(Mode == "finddups") {
          print "1"
          exit
        }
        else 
          sendlog(Logfile, wikiname, "removedups2 ---- straydt.awk")
      }
    }
    article = unpatsplit(field, sep)
  }
  return article

}

#
# Parse article for webcite URLs and if not in long form then expand to long form.
#
function webcitelong(article, c,i,field,sep) {

  c = patsplit(article, field, /https?[:]\/\/w?w?w?[.]webcitation[.]org[^ |\]]*[^ |\]]/,sep)     
  if(c > 0) {
    for(i = 1; i <= c; i++) {
      if(length(field[i]) > 0) {
        newurl = webciteurl(field[i])
        if(newurl != field[i]) 
          field[i] = newurl
      }
    }
    newarticle = unpatsplit(field,sep)
    return newarticle
  }
  return article
}

#
# Given a webcite URL, return in long format urlencoded
#  eg. http://www.webcitation.org/65yd5AgqG?url=http%3A//www.infodisc.fr/S_Certif.php
#
#  If url is short-form (eg. http://www.webcitation.org/65yd5AgqG) determine long form via API
#
function webciteurl(url,  pa,pc,id) {

      if(url ~ /webcitation[.]org\/[^?]*[?]url[=]/)    # Already long format
        # return decodeurl(url)
        return url

      if(Mode == "find") # Do this to avoid calling the API
        return "none"

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

        return "http://www.webcitation.org/" id "?url=" urlencodeawk(urldecodeawk(xurl), "url") 
        
      }

      return url
}

