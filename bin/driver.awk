#!/usr/local/bin/gawk -bE

# Create data files/directories and launch bot

# The MIT License (MIT)
#
# Copyright (c) 2018 by User:GreenC (at en.wikipedia.org)
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

BEGIN {

  # skip any bots that have a custom version of this utility
  if(BotName ~ "(medic|wm2") {
    print "See driverm.awk"
    exit
  }

  _cliff_seed = "0.00" splitx(sprintf("%f", systime() * 0.000001), ".", 2)

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "hd:p:n:a:m:e:")) != -1) {
      opts++
      if(C == "p")                 #  -p <project>   Use project name. Default in project.cfg
        pid = verifypid(Optarg)
      if(C == "n")                 #  -n <name>      Name to process.
        namewiki = verifyval(Optarg)
      if(C == "d")                 #  -d <y|n>       Dry run. "y" = push changes to Wikipedia.
        dryrun = verifyval(Optarg)
      if(C == "a")                 #  -a <filename>  Optional auth filename if running via Toolforge
        authfile = verifyval(Optarg)
      if(C == "e")                 #  -e <0|1|2>     Optional engine type if running via Toolforge
        engine = verifyval(Optarg)

      if(C == "h") {
        usage()
        exit
      }
  }

  if( pid ~ /error/ || ! opts || namewiki == "" ) {
    usage()
    exit
  }

# library.awk .. load Project[] paths via project.cfg
  setProject(pid)

  if( ! checkexe(Exe["wikiget"], "wikiget") || ! checkexe(Exe["date"], "date") || ! checkexe(Exe["cp"], "cp"))
    exit

# Running on Toolforge grid with job-array
  if(namewiki == "_gridarray") {
    namewiki = jobarray(authfile)
    if(empty(namewiki)) {
      stdErr("driver.awk: unable to deterime namewiki from job-array")
      exit
    }
  }

# Create temp directory
  nano = substr(sys2var( Exe["date"] " +\"%N\""), 1, 6)
  rndn = randomnumber(99)
  if(length(rndn) == 1)
    rndn = "0" rndn
  wm_temp = Project["data"] "wm-" sys2var( Exe["date"] " +\"%m%d%H%M%S\"") nano rndn "/"
  if(!mkdir(wm_temp)) {
    stdErr("driver.awk: unable to create temp file " wm_temp)
    exit
  }

# Save wikisource
  print getwikisource(namewiki, "dontfollow") > wm_temp "article.txt"
  close(wm_temp "article.txt")
  stripfile(wm_temp "article.txt", "inplace")

  command = Exe["cp"] " " shquote(wm_temp "article.txt") " " shquote(wm_temp "article.txt.2")
  sys2var(command)

# Save namewiki
  print namewiki > wm_temp "namewiki.txt"
  close(wm_temp "namewiki.txt")

# Create index.temp entry (re-assemble when done with "project -j")

  parallelWrite(namewiki "|" wm_temp, Project["indextemp"], engine)

# Run project and save result to /wm_temp/article.BotName.txt

  # This stderr is required when running on Toolforge so it can monitor when the job-array is complete
  # Good idea in general, anyway, to monitor when a worker is complete.
  stdErr("\n"namewiki"\n")

  command = Exe[BotName] " -s " shquote(wm_temp "article.txt") " -n " shquote(namewiki) " -l " shquote(Project["meta"])
  changes = sys2var(command)
  if(changes) {
    stdErr("    Found " changes " change(s) for " namewiki)
    parallelWrite(namewiki, Project["discovered"], engine)
    # sendlog(Project["discovered"], namewiki, "")
  }
  else {
    if(checkexists(wm_temp "article." BotName ".txt")) {
      removefile(wm_temp "article." BotName ".txt")
    }
  }

# Push changes to Wikipedia with 'wikiget -E'

  if(checkexists(wm_temp "article." BotName ".txt") && dryrun == "y" && stopbutton() == "RUN" ) {
    article = wm_temp "article." BotName ".txt"
    summary = readfile(wm_temp "editsummary." BotName ".txt")
    if(length(summary) < 5)
      summary = "Edit by " BotName

    command = Exe["timeout"] " 20s " Exe["wikiget"] " -E " shquote(namewiki) " -S " shquote(summary) " -P " shquote(article) " -l en"
    result = sys2var(command)

    if(result ~ /[Ss]uccess/) {
      prnt("    driver.awk: wikiget status: Successful. Page uploaded to Wikipedia. " namewiki)
      parallelWrite(namewiki, Project["discovereddone"], engine)
      # print namewiki >> Project["discovereddone"]
      # close(Project["discovereddone"])
    }
    else if(result ~ /[Nn]o[-][Cc]hange/ ) {
      prnt("    driver.awk: wikiget status: No change. " namewiki)
      parallelWrite(namewiki, Project["discoverednochange"], engine)
      # print namewiki >> Project["discoverednochange"]
      # close(Project["discoverednochange"])
    }

    else {  # Try 2

      prnt("    driver.awk: Try 2")
      sleep(2)
      result = sys2var(command)

      if(result ~ /[Ss]uccess/) {
        prnt("    driver.awk: wikiget status: Successful. Page uploaded to Wikipedia. " namewiki)
        parallelWrite(namewiki, Project["discovereddone"], engine)
        # print namewiki >> Project["discovereddone"]
        # close(Project["discovereddone"])
      }
      else if(result ~ /[Nn]o[-][Cc]hange/ ) {
        prnt("    driver.awk: wikiget status: No change. " namewiki)
        parallelWrite(namewiki, Project["discoverednochange"], engine)
        # print namewiki >> Project["discoverednochange"]
        # close(Project["discoverednochange"])
      }
      else {
        prnt("    driver.awk: wikiget status: Failure ('" result "') uploading to Wikipedia. " namewiki)
        parallelWrite(namewiki, Project["discoverederror"], engine)
        # print namewiki >> Project["discoverederror"]
        # close(Project["discoverederror"])
      }
    }
  }

}

#
# Print and log messages
#
function prnt(msg) {
  if( length(msg) > 0 ) {
    stdErr(msg)
    parallelWrite(strftime("%Y%m%d %H:%M:%S") " " msg, Home "driver.log", engine)
    # print(strftime("%Y%m%d %H:%M:%S") " " msg) >> Home "driver.log"
    # close(Home "driver.log")
  }
}

#
# Return wikiname in auth file coresponding to ENVIRON["SGE_TASK_ID"] set by job-array in runbot.awk
#
function jobarray(authfile) {

  if(empty(ENVIRON["SGE_TASK_ID"]))
    return
  if( ! checkexe(Exe["tail"], "tail") || ! checkexe(Exe["head"], "head") )
    return

  # Quickest method
  command = Exe["tail"] " -n +" ENVIRON["SGE_TASK_ID"] " " authfile " | " Exe["head"] " -n 1"
  return sys2var(command)
}

function usage() {

  print ""
  print "Driver - create data files and launch " BotName ".awk"
  print ""
  print "Usage:"
  print "       -p <project>   Project name. Optional, defaults to project.cfg"
  print "       -n <name>      Name to process. Required"
  print "       -d <y|n>       Dry run. '-d y' means push changes to Wikipedia."
  print "       -a <authfile>  Optional auth filename if running via Toolforge"
  print "       -h             Help"
  print ""
  print "Example: "
  print "          driver -n \"Charles Dickens\" -p cb14feb16.001-100 -d y"
  print ""
}

