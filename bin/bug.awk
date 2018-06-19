#!/usr/local/bin/gawk -bE   

#
# Debug routines for botwikiawk 
#

# The MIT License (MIT)
#
# Copyright (c) 2016-2018 by User:GreenC (at en.wikipedia.org)
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

# get bot name from current directory
BEGIN {
  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  # skip any bots that have a custom version 
  if(BotName == "waybackmedic") { 
    print "See bugm.awk"
    exit        
  }

  type = "view"                    # Defaults
  difftype = "c"
  capturetype = "a"

  Optind = Opterr = 1 
  while ((C = getopt(ARGC, ARGV, "vrp:n:d:c:t:")) != -1) { 
      opts++
      if(C == "p")                 #  -p <project>   Use project name. No default.
        pid = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process
        name = verifyval(Optarg)

      if(C == "v")                 #  -v             View paths. Default. Name required.
        type = "view"

      if(C == "r")                 #  -r             Run bot using data cache. Name required.
        type = "run"

      if(C == "d") {               #  -d <type>      Diff. Type is "c" for color (default) or "p" for plain text
        difftype = verifyval(Optarg)
        type = "diff"
      }

      if(C == "c") {               #  -c <type>      Capture output to clipboard. "a" for article.txt and "w" for article.BotName.txt
        type = "capture"
        capturetype = verifyval(Optarg)
      }

      if(C == "t") {               #  -t <filename>  Create a master file across multiple project directories. eg. create a single "discovered" from all projects listed in <filename>
        projfile = verifyval(Optarg)
        type = "master"
      }

      if(C == "h") {
        usage()
        exit
      }
  }

  if(opts == 0) {
    usage()
    exit
  }


 # No options or an empty -p given
  if( pid ~ /error/ ){
    usage()
    exit
  }

  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg
  
  delete Inx

  if(type ~ /view/) {
    view(name)
    exit
  }

  if(type ~ /run/) {
    run(name)
    exit
  }

  if(type ~ /master/) {
    masterfile(projfile, Config["default"]["meta"])  # set file to collate in the function 
    exit
  }

  if(type ~ /diff/) {
    diff(name, difftype)
    exit
  }

  if(type ~ /capture/) {
    cap(name, capturetype)
    exit
  }

}


#
# cap - send file to stdout for capture by clip
#
function cap(name, type,    command) {

  if( ! checkexe(Exe["cat"], "cat") )
    return 

  getindex(name)

  if(type ~ /^a$/) 
    command = Exe["cat"] " " shquote(Inx["path"] "article.txt")
  else if(type ~ /^w$/) 
    command = Exe["cat"] " " shquote(Inx["path"] "article." BotName ".txt")

  system(command)

}

#
# diff - show inline diffs
#
function diff(name, type,   command) {

  getindex(name)

  if(!checkexists(Inx["path"] "article." BotName ".txt")) {
    print "No changes found"
    return
  }

  if(type ~ /c/) {
    if( ! checkexe(Exe["coldiff"], "coldiff"))
      return
    command = Exe["coldiff"] " " shquote(Inx["path"] "article.txt") " " shquote(Inx["path"] "article." BotName ".txt")
  }
  else {
    if( ! checkexe(Exe["diff"], "diff"))
      return
    command = Exe["diff"] " " shquote(Inx["path"] "article.txt") " " shquote(Inx["path"] "article." BotName ".txt")
  }

  system(command)

}

#
# run - run the bot
#
#   . auto-runs clearlogs to keep log files from gaining duplicates
#
function run(name,   command,cwd,changes) {

  getindex(name)
  if(!empty(name)) {

   # clear log files
    cwd = ENVIRON["PWD"]
    if(! chDir(Project["meta"])) {
      stdErr("bug.awk run(): Unable to change dir to " Project["meta"])
      exit      
    }
    print name > "auth.bugrun"
    close("auth.bugrun")
    sys2var("./clearlogs auth.bugrun")
    chDir(cwd)

   # run bot 
    stdErr("\n" name  "\n")
    command = Exe[BotName] " -n " shquote(name) " -s " shquote(Inx["path"] "article.txt") " -l " shquote(Project["meta"])
    changes = sys2var(command)
    if(changes) {
      stdErr("    Found " changes " change(s) for " name)
      sendlog(Project["discovered"], name, "")
    }
    else {
      if(checkexists(Inx["path"] "article." BotName ".txt")) {
        removefile(Inx["path"] "article." BotName ".txt")
      }
    }
  }

}


#
# view - view the paths for a processed article
#
function view(name) {

  getindex(name)
  if(!empty(name)) {
    print "Name: " Inx["name"]
    print "Meta: cd " shquote(Project["meta"])
    print "Data: cd " shquote(Inx["path"])
    print "Run : bug -p " shquote(pid) " -n " shquote(name) " -r"
  }

}

#
# getindex - given a name, retrieve the data path from the index file
#
function getindex(name,  id) {

  id = whatistempid(name)
  if(length(name)) 
    Inx["name"] = strip(name)
  if(length(id))
    Inx["path"] = strip(id)
  
  if(Inx["name"] == "" || Inx["path"] == "") {
    stdErr("bug.awk getindex(): Unable to find " Inx["name"] " in " Project["index"])
    exit
  }
}


#
# masterfile - print to screen contents of a file across multiple projects. 
#
#  . First create a file with a list of project ID's and run with the -t <filename> switch
#  . Useful for creating a master discovered file for example across multiple projects
#
function masterfile(projfile, mid,    c,a,i, fp) {

  fp = "newaltarch.mosaic"  #==> the master file to target

  if(! checkexists(projfile) ) {
    print("Error unable to find " projfile )
    return 0
  }

  for(i = 1; i <= splitn(projfile, a, i); i++) {
    if(length(a[i]) > 1)  {
      if(checkexists(mid a[i] "/" fp))
        print strip(readfile(mid a[i] "/" fp))
    }
  }
}

#
# usage
#
function usage() {

  print ""
  print "Bug - routines to help debug."
  print ""              
  print "Usage:"
  print "       -n <name>      Name to process. Required"
  print "       -p <project>   Project name. Optional (default in project.cfg)"
  print ""           
  print "       -v             View name paths. Default."
  print "       -r             Run bot for this name in '-d n' mode (don't upload to Wiki)." 
  print "       -c <a|w>       Dump contents of article.txt (a) or article." BotName ".txt (w) to screen"
  print "       -d <type>      Diff. Type = c (default: color) or p (plain text)" 
  print "       -t <filename>  Create a master file across all project directories listed in filename" 
  print ""
  print "Examples: debug -n \"George Wash\" -d c"                 
  print ""

}



