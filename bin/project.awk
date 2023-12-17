#!/usr/local/bin/gawk -bE   

#
# Initialize and manage a project (ie. a batch of articles to process)
#

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

# -------------------------------------------------

# Derive the bot's name and home dir from the current directory
# The bot's home dir should have the same name as the bot
#   eg. /home/admin/bot/accdate is the home directory for a bot called accdate.awk
# Then you can run this utility after cd'ing to the ~/accdate directory
# See the file SETUP for meaning of the Engine parameter

BEGIN {

  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]
  for(_i=1;_i<_pwdC;_i++) _a = _a _pwdA[_i] "/"
  Home = _a
  Agent = "Ask me about " BotName
  Engine = 0

}

@include "botwiki.awk"
@include "library.awk"
@include "json.awk"

BEGIN {

  # skip any bots that have a custom version of this utility
  if(BotName ~ "(medic|wm2") {
    print "See driverm.awk"
    exit
  }

  Optind = Opterr = 1 
  while ((C = getopt(ARGC, ARGV, "jyicxhp:d:m:s:u:")) != -1) { 
      opts++
      if(C == "p")                 #  -p <project>   Use project name. No default.
        pid = verifypid(Optarg)
      if(C == "d")                 #  -d <data dir>  Data directory. Defaults to default.data in project.cfg
        did = verifyval(Optarg)
      if(C == "m")                 #  -m <data dir>  Meta directory. Defaults to default.meta in project.cfg
        mid = verifyval(Optarg)
      if(C == "c")                 #  -c             Create project files. -p required
        type = "create"
      if(C == "x")                 #  -x             Delete project files. -p required
        type = "delete"
      if(C == "j")                 #  -j             Re-assemble index file after all driver's completed. -p required
        type = "assemble"
      if(C == "s") {               #  -s <filename>  Search for a string inside a file in the data directory
        type = "checkstring"        
        searchfile = verifyval(Optarg)
      }
      if(C == "u") {               #  -u <filename>  Search for a string inside a file in the meta directory
        type = "metacheck"        
        searchfile = verifyval(Optarg)
      }
      if(C == "i")                 #  -i             Build index from scratch from data directory. -p required
        type = "index"
      if(C == "y")                 #  -y             Check for corruption in data files. -p required
        type = "corrupt"

      if(C == "h") {
        usage()
        exit
      }
  }

 # No options or an empty -p given
  if( type == "" || (type ~ /delete|create|index|corrupt|assemble/ && pid == "") || pid ~ /error/ ) {
    usage()
    exit
  }

  if( ! checkexe(Exe["mkdir"], "mkdir") || ! checkexe(Exe["head"], "head") || ! checkexe(Exe["tail"], "tail") || ! checkexe(Exe["cp"], "cp"))
    exit

 # Load default Data and Meta from project.cfg 
  if(did == "") 
    did = Config["default"]["data"]
  if(mid == "") 
    mid = Config["default"]["meta"]
  if(did == "" || mid == "") {
    stdErr("project.awk Error: Unable to determine Data or Meta directories. Create project.cfg with default.data and default.meta")
    exit
  }

  if(type ~ /checkstring/) {
    if(length(searchfile) > 0)
      check_string(searchfile, pid, did, mid)
    exit
  }
  if(type ~ /metacheck/) {
    if(length(searchfile) > 0)
      check_stringmeta(searchfile, pid, did, mid)
    exit
  }

  if(type ~ /index/ ) {
    makeindex(pid,did,mid)
    exit
  }

  if(type ~ /corrupt/ ) {
    corruption(pid,did,mid)
    exit
  }

  if(type ~ /assemble/ ) {
    assemble(pid,did,mid)
    exit
  }


  if(type ~ /delete/) {
    deleteproject(pid,mid,did)
    exit
  }
  
 # Everything following is type = create

 # Check everything looks ok
  if(substr(did,length(did),1) != "/" || substr(mid,length(mid),1) != "/") {
    stdErr("project.awk Error: data and meta should end in a trailing slash. Maybe check project.cfg for default.data/meta")
    exit
  }

 # Make Data and Meta directories
  if(checkexists(did pid)) 
    stdErr("project.awk Error: Data directory already exists: " did pid)
  else {
    stdErr("OK Creating " did pid)
    sys2var(Exe["mkdir"] " " did pid)
    checkexists(did pid, "project.awk", "exit")
  }
  if(checkexists(mid pid)) 
    stdErr("project.awk Error: Meta directory already exists: " mid pid)
  else {
    stdErr("OK Creating " mid pid)
    sys2var(Exe["mkdir"] " " mid pid)
    checkexists(mid pid, "project.awk", "exit")
  }

  newprojcfg("project.cfg")

 # Create .auth file 
  split(pid,a,".")
  if(checkexists(mid a[1] ".auth")) {
    if(a[2] ~ /[0-9]{1,5}[-][0-9]{1,5}/) {
      c = split(a[2],b,"-")
      if(c == 2 && strip(b[1]) ~ /^[0-9]+$/ && strip(b[2]) ~ /^[0-9]+$/) {
        start = strip(b[1])
        end = strip(b[2])
        if(! checkexists(mid pid "/auth")) {
          # head -n 750 meta/births1870.auth | tail -n 250 > /home/adminuser/wi-awb/meta/births1870.501-750/auth
          command = Exe["head"] " -n " end " " mid a[1] ".auth | " Exe["tail"] " -n " int( int(end) - int( int(start) - 1) ) " > " mid pid "/auth"
          sys2var(command)
          checkexists(mid pid "/auth", "project.awk", "exit")
        }
        else            
          stdErr("project.awk - Auth file " mid pid "/auth already exists. Not creating new one.")
      }           
      else                       
        stdErr("project.awk - (1) Project ID doesn't take the form Name.####-#### - Unable to create " mid pid "/auth")
    }   
    else
      stdErr("project.awk - (2) Project ID doesn't take the form Name.####-#### - Unable to create " mid pid "/auth")
  }
  else {
    stdErr("project.awk - Unable to find " mid a[1] ".auth - Unable to create " mid pid "/auth")
  }

  print "Copying scripts to " mid pid
  if(checkexists("scripts/cl.awk")) {
    command = Exe["cp"] " scripts/cl.awk " mid pid
    sys2var(command)
    command = Exe["cp"] " scripts/clearlogs " mid pid
    sys2var(command)
  }
  else {
    stdErr("Warning: unable to find scripts/cl.awk")
  }


}

#
# newprojcfg - write new project.cfg
#
function newprojcfg(cfgname,  i,a,c,re) {

  # Remove leading and trailing blank lines
  print stripfile(Home cfgname) > Home cfgname ".orig"
  close(Home cfgname ".orig")
  checkexists(Home cfgname ".orig", "project.awk", "exit")

  # Set new default
  re = "^default[.]id"   

  for(i = 1; i <= splitn(Home cfgname ".orig", a, i); i++) {
    if(a[i] ~ re) {
      a[i] = "default.id = " pid
      break
    }
  }
  c = length(a)
  if(i == c) 
    stdErr("Unable to set default.id")
  else
    stdErr("OK Setting default.id = " pid)

  # Create new .data and .meta 
  a[c + 1] = pid ".data = " did pid "/"
  a[c + 2] = pid ".meta = " mid pid "/"

  stdErr("OK Writing new " cfgname)

  if(checkexists(Home cfgname)) 
    removefile(Home cfgname)

  i = 0
  while(i++ < c + 2) 
    print a[i] >> Home cfgname

  close(Home cfgname)

}

#
# nameisinfile - return 1 if name is in file
#
function nameisinfile(name, filen,    s, a, re) {

  checkexists(filen, "project.awk nameisinfile()", "exit")

  re = "^" regesc2(strip(name)) "$"
  while ((getline s < filen ) > 0) {
    split(s, a, "|")
    if(strip(a[1]) ~ re) {
      close(filen)
      return 1
    }
  }
  close(filen)
  return 0
}

#
# makeindex - make an index file based on content in data directory
#
#   . Useful if the index becomes corrupted 
#   . Won't work right if the bot was run more than once
#
function makeindex(pid,did,mid,    data,meta,a) {

  data = did pid "/"
  meta = mid pid "/"

  if( ! checkexe(Exe["ls"], "ls") )
    exit

  if( ! checkexists(data) || ! checkexists(meta) ) {
    print "Unable to find " data " OR " meta
    exit
  }
  if(checkexists(meta "index")){
    print "File exists, aborting."
    print "To delete: rm " meta "index"
    exit
  }

  # list directories only
  # https://stackoverflow.com/questions/14352290/listing-only-directories-using-ls-in-bash-an-examination
  c = split( sys2var(Exe["ls"] " -d1 " data "wm*/"), a, "\n")
  while(i++ < c) {
    if( ! checkexists(a[i] "namewiki.txt") )
      stdErr("Unable to find " a[i] "namewiki.txt")
    else 
      print strip(readfile(a[i] "namewiki.txt")) "|" a[i] >> meta "index"
  }
  close(meta "index")

}

#
# corruption - check for data corruption. 
#
#   . if namewiki string is not contained in article.txt 
#
function corruption(pid,did,mid,    data,meta,a,namewiki,command) {

  data = did pid "/"
  meta = mid pid "/"

  if( ! checkexe(Exe["ls"], "ls") || ! checkexe(Exe["grep"], "grep"))
    exit

  if( ! checkexists(data) || ! checkexists(meta) ) {
    print "Unable to find " data " OR " meta
    exit
  }

  # list directories only
  # https://stackoverflow.com/questions/14352290/listing-only-directories-using-ls-in-bash-an-examination
  c = split( sys2var(Exe["ls"] " -d1 " data "wm*/"), a, "\n")
  while(i++ < c) {
    if( ! checkexists(a[i] "namewiki.txt") )
      stdErr("Unable to find " a[i] "namewiki.txt")
    else {
      namewiki = readfile(a[i] "namewiki.txt") 
      gsub(/["]/,"\\\"",namewiki)
      command = Exe["grep"] " -c \"" namewiki "\" " a[i] "article.txt"
      if(sys2var(command) == "0") {
        print a[i]
      }
    }
  }
  close(meta "index")

}


#
# assemble - assemble index from index.temp post-GNU parallel 
#
#   . given an index and index.temp, this will merge into index leaving only uniq entries 
#   . if there are duplicates the version in index.temp takes precedent over version in index
#
function assemble(pid,did,mid,   data,meta,indextemp,indexmain,d,a,c,i,j,outfile,gold,debug) {

  debug = 0

  data = did pid "/"
  meta = mid pid "/"

  if( ! checkexe(Exe["mv"], "mv") || ! checkexe(Exe["cp"], "cp"))
    exit

  outfile = mktemp(meta "index.XXXXXX", "u")
  checkexists(meta "index.temp", "project.awk assemble(): Unable to find " meta "index.temp", "exit")

  if(!checkexists(meta "index")) {                          # If no index, just rename file
    sys2var(Exe["mv"] " " shquote(meta "index.temp") " " shquote(meta "index") )
    exit
  }

  sys2var(Exe["cp"] " " meta "index " meta "index.orig")

  for(i = 1; i <= splitn(meta "index.temp", a, i); i++) {
    if(length(a[i]) > 5) {
      indextemp[i]["name"] = splitx(a[i], "|", 1)
      indextemp[i]["full"] = a[i]
    }
    c++
  }
  for(i = 1; i <= splitn(meta "index", a, i); i++) {
    if(length(a[i]) > 5) {
      indexmain[i]["name"] = splitx(a[i], "|", 1)
      indexmain[i]["full"] = a[i]
    }
    d++
  }

  if( debug ) {
    print "index.temp   = " c
    print "index.orig   = " d
  }

  # If a record exists in both index and index.temp, replace the record in index with the one from index.temp
  i = j = 0
  gold = "no"
  while(i++ < d) {
    while(j++ < c) {
      if( indexmain[i]["name"] == indextemp[j]["name"] ) {
        if(length(indextemp[j]["full"]) > 5) {
          print indextemp[j]["full"] >> outfile
          close(outfile)
          gold = "yes"
          break
        }
      }
    }
    if(gold == "no") {
      if(length(indexmain[i]["full"]) > 5) {
        print indexmain[i]["full"] >> outfile
        close(outfile)
      }
    }
    else gold = "no"
    j = 0
  }

  # If a record exists in index.temp but not index, add it to index
  i = j = 0
  gold = "no"
  while(j++ < c) {
    while(i++ < d) {
      if( indexmain[i]["name"] == indextemp[j]["name"] ) {
        gold = "yes"
        break
      }
    }
    if(gold == "no") {
      if(length(indextemp[j]["full"]) > 5) {
        print indextemp[j]["full"] >> outfile
        close(outfile)
      }
    }
    else gold = "no"
    i = 0
  }

  system("")  # flush buffer
  if( debug )
    print "index        = " wc(outfile)
  removefile(meta "index")
  sys2var(Exe["mv"] " " shquote(outfile) " " shquote(meta "index") )  

}

#
# deleteproject - delete project
#
function deleteproject(pid,mid,did,    i,c,re,a,cfgname) {

  if( ! checkexe(Exe["mv"], "mv") )
    exit

  cfgname = "project.cfg"

 # Delete Data and Meta directories
  if( ! checkexists(did pid)) 
    stdErr("project.awk Error: Data directory doesn't exist: " did pid)
  else {
    stdErr("OK Deleting " did pid)
    removefile(did pid, "-r")
  }
  if( ! checkexists(mid pid)) 
    stdErr("project.awk Error: Meta directory doesn't exist: " mid pid)
  else {
    stdErr("OK Deleting " mid pid)
    removefile(mid pid, "-r")
  }

 # Remove .meta and .data lines from project.cfg but leave default.* lines untouched 
  if(checkexists(Home cfgname ".out"))
    removefile(cfgname ".out")
  if(checkexists(Home cfgname ".orig"))
    removefile(cfgname ".orig")
  if(checkexists(Home cfgname))
    command = Exe["mv"] " " shquote(Home cfgname) " " shquote(Home cfgname ".orig")
  else {
    stdErr("project.awk Error: Unable to find " shquote(Home cfgname) )
    return
  }
  stdErr("OK Making backup " shquote(cfgname) " -> " shquote(cfgname ".orig") )
  sys2var(command)
  system("")
  re = "^" regesc2(pid) "[.](data|meta)"     
  for(i = 1; i <= splitn(Home cfgname ".orig", a, i); i++) {
    if(a[i] ~ re) { # delete if re matches 
    }
    else {
      print a[i] >> Home cfgname ".out"
    }
  }
  close(Home cfgname ".out")
  if(checkexists(Home cfgname ".out")) {
    print stripfile(Home cfgname ".out") > Home cfgname
    close(Home cfgname)
    stdErr("OK Removed data & meta lines from " cfgname " (default.id untouched)")
  }
  else {
    stdErr("Unable to modify " shquote(cfgname) " - restoring backup")
    sys2var(Exe["mv"] " " shquote(Home cfgname ".orig") " " shquote(Home cfgname) )
  }
}

#
# check_stringmeta - search for string "re" in <filename> in meta directory
#  
function check_stringmeta(filename, pid, did, mid,    re,c,files,stampdir,i,command,count) {

  stdErr("Processing " pid)

  if( ! checkexe(Exe["ls"], "ls") || ! checkexe(Exe["grep"], "grep"))
    exit

 # Be careful with escaping as unsure how grep responds 
  #re = "[|][ ]url[ ][=][ ]http[^{}]*[{][{][ ]?dead[ ]link"
  re = "Check 6[.]2"

  files = sys2var(Exe["ls"] " " shquote(did pid "/"))
  if(pid == "") {
    print "\nRequires -p <projectid> .. available project IDs:\n"
    print files
    print ""
    exit
  }

  count = 0

  if(checkexists(mid pid "/" stampdir[i] "/" filename)) {

    #
    # Grep version for generic searches
    #

    command = Exe["grep"] " -ciE \"" re "\" " shquote(mid pid "/" stampdir[i] "/" filename)

    count = sys2var(command)

    if(count > 0) {

      command = Exe["grep"] " -iE \"" re "\" " shquote(mid pid "/" stampdir[i] "/" filename)
      print sys2var(command)
    }
  }
}

#
# check_string - search for string "re" in <filename> in data directory
#
function check_string(filename, pid, did, mid,    re,c,files,stampdir,i,command,count) {

  stdErr("Processing " pid)

  if( ! checkexe(Exe["ls"], "ls") || ! checkexe(Exe["grep"], "grep"))
    exit

 # Be careful with escaping as unsure how grep responds 
  re = "[|][ ]url[ ][=][ ]http[^{}]*[{][{][ ]?dead[ ]link"

  files = sys2var(Exe["ls"] " " shquote(did pid "/"))
  if(pid == "") {
    print "\nRequires -p <projectid> .. available project IDs:\n"
    print files
    print ""
    exit
  }

  count = 0

  for(i = 1; i<= splitn(files, stampdir, i); i++) {
    if(checkexists(did pid "/" stampdir[i] "/" filename)) {

#
# Grep method for generic searches
      # command = Exe["grep"] " -ciE \"" re "\" " did pid "/" stampdir[i] "/" filename

#
# Awk module method with "Mode = find" set at top of bot
#
      command = "/home/adminuser/wmnim/wm2/modules/straydt/straydt -s " shquote(did pid "/" stampdir[i] "/" filename)    

#      print did pid "/" stampdir[i] "/" filename 

      count = sys2var(command)

      if(count > 0) {
#         print did pid "/" stampdir[i] "/" filename
        newid = whatistempid(did pid "/" stampdir[i], mid pid "/index")
        if(newid !~ /^0$/)
          print newid
#        print newid " ( cd " did pid "/" stampdir[i] " )"
      }
    }
  }
}

function usage() {

  print ""
  print "Project - manage projects."
  print ""
  print "Usage:"
  print "       -p <project>   Project name."
  print "       -d <data dir>  Data directory. Defaults to default.data in project.cfg"
  print "       -m <meta dir>  Meta directory. Defaults to default.meta in project.cfg"
  print "       -c             Create project files. -p required"
  print "       -x             Delete project files. -p required"
  print "       -j             Re-assemble index file after all drivers (via parallel) is completed. -p required." 
  print "       -s <filename>  Find a string (defined in source) in <filename> in the data directory"
  print "       -u <filename>  Find a string (defined in source) in <filename> in the meta directory"
  print "       -i             Try to re-build index from ~/data files. CAUTION: won't work if duplicates in data. -p required"
  print "       -y             Check for data corruption. See project.awk source for description. -p required"
  print ""
  print "       -h             Help"
  print ""
  print "Path names for -d and -m end with trailing slash."
  print ""

}



