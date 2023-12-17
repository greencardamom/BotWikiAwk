#!/bin/sh

#
# Setup for BotWikiAwk
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


# Bootstrap GNU Awk 4.x +

if [ $(command -v gawk) ]; then
  awkn="gawk"
else
  awkn="awk"
fi

# Optional: add a hardcoded path to awk
#  awkn="/usr/bin/gawk"

awkloc=$("$awkn" --version)
substr="GNU Awk"

# POSIX sub-string compare - is it GNU Awk? Is it not version 1-3?
for s in "$awkloc"; do
    if case ${s} in *"${substr}"*) true;; *) false;; esac; then
        awkpath=$(command -v "$awkn")
        if [ $("${awkpath}" -v s="$s" 'BEGIN {if(s ~ /GNU Awk [123]|GNU Awk 4[.]0/) {print 0; exit}; print 1}') = 0 ]; then
            echo "GNU Awk 4.1+ required"
            awkpath=""
        fi
    else
        echo "Unable to find GNU Awk in path, setup aborting.\n . Manually set hashbangs in *.awk (~/bin, ~/scripts (including clearlogs) and ~/skeleton)\n . Manually update Exe[] pathnames in ~/lib/botwiki.awk" 
        awkpath=""
    fi
done

if [ -z "$awkpath" ]; then
  echo "Unable to determine path to awk 4.1+.\n Set awkn=\"/localpath/../gawk\" in setup.sh in the section \"add a hardcoded path to awk\"."
  exit
fi

# Load environment variables
envok=$("${awkpath}" -v awkpath="$awkpath" 'BEGIN {

  c = split(ENVIRON["AWKPATH"], a, ":")
  for(i = 1; i <= c; i++) {
    if(a[i] ~ /BotWikiAwk/) {
      inenv["awkpath"] = a[i]
      break
    }
  }
  c = split(ENVIRON["PATH"], a, ":")
  for(i = 1; i <= c; i++) {
    if(a[i] ~ /BotWikiAwk/) {
      inenv["path"] = a[i]
      break
    }
  }
  if( length(inenv["awkpath"]) == 0 || length(inenv["path"]) == 0) {
    print "0"
    exit
  }
  print "1"
}')

if [ "$envok" = "0" ]; then
  echo "Unable to find PATH and/or AWKPATH for BotWikiAwk. See setup instructions. Log-out/in."
  exit
fi

# Download wikiget, load manifest, set shebangs, create exe paths, create symlinks

"${awkpath}" -ilibrary -v awkpath="$awkpath" 'BEGIN {


  c = split(ENVIRON["AWKPATH"], a, ":")
  for(i = 1; i <= c; i++) {
    if(a[i] ~ /BotWikiAwk/) {
      inenv["awkpath"] = a[i]
      break
    }
  }
  c = split(ENVIRON["PATH"], a, ":")
  for(i = 1; i <= c; i++) {
    if(a[i] ~ /BotWikiAwk/) {
      inenv["path"] = a[i]
      break
    }
  }

  sub(/lib\/?$/, "", inenv["awkpath"])
  if(! chDir(inenv["awkpath"])) {
    stdErr("setup.sh: Unable to change directory to " inenv["awkpath"])
    exit
  }

 # download wikiget.awk
  if(!sys2var(sprintf("command -v %s","wget"))) {
    stdErr("setup.sh: Unable to find wget and cannot download wikiget.awk from GitHub. Install wikiget manually in ~/bin")
  }
  else {
    p = sys2var("wget -q -O- " shquote("https://raw.githubusercontent.com/greencardamom/Wikiget/master/wikiget.awk"))
    if(!empty(p)) {
      print p > "bin/wikiget.awk"
      close("bin/wikiget.awk")
      sys2var("chmod 700 bin/wikiget.awk")
    }
    else 
      stdErr("setup.sh: Unable to download wikiget.awk from GitHub. Install manually in ~/bin")
  }

  botwikifile = "lib/botwiki.awk"
  syscfgfile = "lib/syscfg.awk"

  # set default path
  fp = readfile(botwikifile)
  if(sub(/Home[ ]*[=][ ]*\"\/home\/adminuser\/BotWikiAwk\/bots\//, "Home = \"" inenv["awkpath"] "bots/", fp)) {
    print fp > botwikifile
    close(botwikifile)
  }

  manfp = readfile("manifest")
  if(empty(manfp)) {
    stdErr("setup.sh: Unable to find manifest")
    exit
  }
  s = splitn(manfp, a)
  for(i = s; i > 0; i--) {
    delete b

   # set Exe[] paths
    if(a[i] ~ /^dependencies/) {
      fp = readfile(syscfgfile)
      if(fp !~ /\][ ]*[=][ ]*[.]{3,}/) 
        continue
      stdErr("\nSet Exe[] paths")
      c = split(splitx(a[i], "[=]", 2), b, " ")
      for(j = 1; j <= c; j++) {  
        b[j] = strip(b[j])
        p = strip(sys2var(sprintf("command -v %s",b[j])))
        re = "Exe\\[\"" b[j] "\"\\][ ]*[=][ ]*[.]{3,}"
        if(! p) {
          stdErr("  . Warning: Unable to find path for Exe[\"" b[j] "\"] in " syscfgfile " - please add it manually")
          sub(re, "Exe[\"" b[j] "\"] = ", fp)  
        }
        else {
          if(sub(re, "Exe[\"" b[j] "\"] = \"" p "\"", fp)) {
            stdErr("  Adding Exe[\"" b[j] "\"] = \"" p "\"")
            Exe[b[j]] = p
          }
        }
      }
      print fp > syscfgfile
      close(syscfgfile)
    }

   # set shebangs and create symlinks
    else if(a[i] ~ /^awkbangs/) {
      if(awkpath == "/usr/local/bin/gawk")
        continue
      stdErr("\nSet shebang to #!" awkpath)
      c = split(splitx(a[i], "[=]", 2), b, " ")
      for(j = 1; j <= c; j++) {
        # create symlinks
        if(b[j] !~ "scripts") {
          if(! checkexists(splitx(b[j], ".", 1))) {
            chDir(splitx(b[j], "/", 1))
            command = "ln -s " splitx(b[j], "/", 2) " " splitx(splitx(b[j], "/", 2), ".", 1)
            sys2var(command)
            chDir("..")
          }
        }
        # set shebangs
        fp = readfile(strip(b[j]) )
        if(sub(/^[#][!]\/usr\/local\/bin\/[g]?awk/, "#!" awkpath, fp)) {
          print fp > b[j]
          stdErr(" Updated shebang of " strip(b[j]) )
        }
        else
          stdErr(" Did not update shebang of " strip(b[j]) )
        close(b[j])
      }      
    }
  }
}'

echo "\nSetup done."
