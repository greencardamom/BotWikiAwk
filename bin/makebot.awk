#!/usr/local/bin/gawk -bE

#
# Create a new bot
#

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

  if(empty(ARGV[1])) 
    usage()
  sub(/\/$/, "", ARGV[1])
  if(checkexists(ARGV[1])) {
    print "makebot.awk: directory or file exists"
    exit
  }

  if( ! checkexe(Exe["cp"], "cp") || ! checkexe(Exe["chmod"], "chmod") || ! checkexe(Exe["ln"], "ln") || ! checkexe(Exe["date"], "date"))
    exit

  botpath = strip(dirname(ARGV[1]))
  botname = strip(basename(ARGV[1]))
  bwapath = strip(dirname(sys2var("which makebot.awk")))
  sub(/bin\/$/, "", bwapath)

  if(botpath == "./") {
    stdErr("makebot.awk: Error: complete path/botname required")
    usage()
  }

  if(botname ~ /[ ]/ || botpath ~ /[ ]/) 
    stdErr("makebot.awk: Warning: in this version of BotWikiAwk it should work but has not been fully tested using <space> in path/botname")

  if(checkexists(bwapath)) {
    if(mkdir(ARGV[1])) {
      if(mkdir(ARGV[1] "/scripts")) {
        stdErr("\n  Copying " shquote(bwapath "scripts/") "*")
        sys2var(Exe["cp"] " " shquote(bwapath "scripts/") "* " shquote(ARGV[1] "/scripts"))
        stdErr("  mkdir " ARGV[1] "/meta")
        mkdir(ARGV[1] "/meta")  
        stdErr("  mkdir " ARGV[1] "/data")
        mkdir(ARGV[1] "/data")  
        stdErr("  Creating skeleton bot " shquote(ARGV[1] "/" botname ".awk"))
        fp = makeskeleton(getskeletonname(), botname, bwapath)
        if(!empty(fp))
          print fp > ARGV[1] "/" botname ".awk"
        else {
          stdErr("makebot.awk: Unable to create " shquote(ARGV[1] "/" botname ".awk"))
          exit
        }
        close(ARGV[1] "/" botname ".awk")
        sys2var(Exe["chmod"] " 750 " shquote(ARGV[1] "/" botname ".awk"))
        sys2var(Exe["ln"] " -s " shquote(ARGV[1] "/" botname ".awk") " " shquote(ARGV[1] "/" botname))
        if(checkexists(ARGV[1] "/" botname))
          stdErr(botname " ready. To delete, 'rm -r " ARGV[1] "'")
        else
          stdErr("makebot.awk: Unknown error creating symlink")
      }
      else {
        stdErr("makebot.awk: Error: unable to create " ARGV[1] "/scripts")
        exit
      }

      makeprojcfg()

    }
    else {
      stdErr("makebot.awk: Error: unable to create " ARGV[1])
      exit
    }
  }
  else {
    stdErr("makebot.awk: Error: Unable to dynamically determine BotWikiAwk home directory\n")
    stdErr("Ensure ~/BotWikiAwk/bin directory is in PATH.")
    exit
  }
}

function makeskeleton(skeletonname, botname,bwapath,   fp) {
  fp = readfile(bwapath "/skeleton/skeleton-" skeletonname ".awk")
  if(empty(fp)) return ""
  fp = gsubs("XXXXXX", botname, fp)
  fp = gsubs("ZZZZZZ", sys2var(Exe["date"] " +\"%B %Y\""), fp)
  return fp
}

function getskeletonname(  resp) {
  print  "\nWhat type of skeleton?"
  print  "  1. Bare bones"
  print  "  2. Bot for templates"
  printf "\n[1-2]: "

  getline resp < "-"
  if(resp == 2) 
    return "templates"
  return "bones"  

}

function makeprojcfg() {

  print "# Default project name" > ARGV[1] "/project.cfg"
  print "default.id = " >> ARGV[1] "/project.cfg"
  print "# Default directories" >> ARGV[1] "/project.cfg"
  print "default.data = " ARGV[1] "/data/" >> ARGV[1] "/project.cfg"
  print "default.meta = " ARGV[1] "/meta/" >> ARGV[1] "/project.cfg"
  print "# For each project, create a .data and .meta line" >> ARGV[1] "/project.cfg"
  print "" >> ARGV[1] "/project.cfg"
  close(ARGV[1] "/project.cfg")

}

function usage() {

  print ""
  print "makebot - make a new bot"
  print ""
  print "   makebot <path/botname>"
  print ""
  print "   Example: makebot /usr/admin/bots/chkcite"
  print ""

  exit
}


