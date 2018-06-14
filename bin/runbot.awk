#!/usr/local/bin/gawk -bE   

#
# Run bot
#
#  Pass project ID as first arg and name of file to process as second
#  if optional third argument is "dry" it won't push changes to wikipedia
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

# get bot name
BEGIN {
  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]

  _engine = 0  # 0 = GNU parallel
               # 1 = Toolforge grid

  _delay = "0.5"  # parallel delay between each worker startup
  _procs = "20"   # max number of parallel workers at a time

}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  dateb = sys2var("date +'%s'")

  if(ARGC < 3) {
    print "Runbot - run the bot"
    print "\n\tUsage: runbot <pid> <filename>"
    print "\n\tExample: runbot accdate20180101.001-900 auth\n"
    exit
  }

  pid = ARGV[1]
  fid = ARGV[2]

  setProject(pid)     # library.awk .. load Project[] paths via project.cfg
                      # if -p not given, use default noted in project.cfg

  if(! checkexe(Exe["parallel"], "parallel") || ! checkexe(Exe["driver"], "driver") || ! checkexe(Exe["mv"], "mv") || ! checkexe(Exe["project"], "project") || ! checkexe(Exe["date"], "date") || ! checkexe(Exe["wc"], "wc") )
    exit
  checkexists(Project["meta"] fid, "runbot.awk checkexists()", "exit")
  checkexists(Project["meta"] "cl.awk", "runbot.awk checkexists()", "exit")
  checkexists(Project["meta"] "clearlogs", "runbot.awk checkexists()", "exit")

  if(ARGV[3] ~ /dry/)   # Dry run. "y" = push changes to Wikipedia.
    drymode = "n"
  else
    drymode = "y"

  cwd = ENVIRON["PWD"]
  if(! chDir(Project["meta"])) {
    stdErr("runbot.awk: Unable to change dir to " Project["meta"])
    exit
  }
  sys2var("./clearlogs " fid)
  chDir(cwd)

  if(_engine == 0) {

    # parallel -a meta/$1/$2 -r --delay 0.5 --trim lr -k -j 10 ./driver -d n -p $1 -n {}
    command = Exe["parallel"] " -a " Project["meta"] fid " -r --delay " _delay " --trim lr -k -j " _procs " " Exe["driver"] " -d " drymode " -p " pid " -n {}"

    while ( (command | getline fish) > 0 ) {
      if ( ++scale == 1 )     {
        print fish
      }
      else     {
        print "\n" fish
      }
    }
    close(command)
  }
  else if(_engine == 1) {
    gridfire(Project["meta"] fid, drymode, pid)
    gridwatch()
  }

  # ./project -j -p $1
  command = Exe["project"] " -j -p " pid
  sys2var(command)

  sleep(1)

  # mv meta/$1/index.temp meta/$1/index.temp.$2
  if(checkexists(Project["meta"] "index.temp" ))
    sys2var(Exe["mv"] " " shquote(Project["meta"] "index.temp") " " shquote(Project["meta"] "index.temp." fid) )

  bell()

  sleep(1)

  datee = sys2var(Exe["date"] " +'%s'")
  datef = (datee - dateb)
  acount = splitn(Project["meta"] fid, a)
  avgsec = datef / acount
  print "\nProcessed " acount " articles in " (datef / 60) " minutes. Avg " (datef / acount) " sec each (delay = " _delay "sec ; procs = " _procs  ")"

}

function gridfire(auth, drymode, pid,  i,a) {

  for(i = 1; i <= splitn(auth, a, i); i++) {
    command = "jsub -N tools.botwikiawk-" BotName "-" i " -once " Exe["driver"] " -d " drymode " -p " pid " -n " shquote(a[i])
    sys2var(command)
    sleep(1, "unix")
  }
}

function gridwatch() {

  while(1) {
    op = sys2var("qstat")
    print op
    if(empty(op))
      break
    sleep(10, "unix")
  }

}

