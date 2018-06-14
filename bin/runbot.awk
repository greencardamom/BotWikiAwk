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

BEGIN {

  # Get bot name from cwd
  delete _pwdA
  _pwdC = split(ENVIRON["PWD"],_pwdA,"/")
  BotName = _pwdA[_pwdC]

  # Settings
  _engine = 0  # 0 = GNU parallel
               # 1 = Toolforge grid

  _delay = "0.5"      # GNU parallel: delay between each worker startup
  _procs = "20"       # GNU parallel: max number of parallel workers at a time
  _griddelay = "1"    # Toolforge grid: delay between each worker startup

}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  if(ARGC < 3) {
    print "Runbot - run the bot"
    print "\n\tUsage: runbot <pid> <filename> <dryrun>"
    print "\n\tExample: runbot accdate20180101.001-900 auth\n"
    print "\n\t         runbot accdate20180101.001-900 auth dry\n"
    exit
  }

  setProject(ARGV[1])     # library.awk .. load Project[] paths via project.cfg
                          # if -p not given, use default noted in project.cfg

  main(strip(ARGV[1]),strip(ARGV[2]),strip(ARGV[3]))

}

function main(pid,fid,dry,   dateb,cwd,command,drymode,fish,scale,datee,datef,acount,avgsec) {

  if(_engine == 0 && ! checkexe(Exe["parallel"], "parallel"))
    exit
  if(! checkexe(Exe["driver"], "driver") || ! checkexe(Exe["mv"], "mv") || ! checkexe(Exe["project"], "project") || ! checkexe(Exe["date"], "date") )
    exit
  checkexists(Project["meta"] fid, "runbot.awk checkexists()", "exit")
  checkexists(Project["meta"] "cl.awk", "runbot.awk checkexists()", "exit")
  checkexists(Project["meta"] "clearlogs", "runbot.awk checkexists()", "exit")

  dateb = sys2var(Exe["date"] " +'%s'")

  if(dry ~ /dry/)       # Dry run. "y" = push changes to Wikipedia.
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
    _delay = _griddelay
    if(!checkexists(Project["meta"] "gridlog"))
      mkdir(Project["meta"] "gridlog")
    gridfire(Project["meta"] fid, drymode, pid)
    gridwatch()
    gridlog(fid)
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

#
# gridfire - start driver.awk workers on the grid with _delay between each startup
#
function gridfire(auth, drymode, pid,    i,a,command) {

  for(i = 1; i <= splitn(auth, a, i); i++) {
    command = "jsub -N tools.botwikiawk-" BotName "-" i " -o " Project["meta"] "gridlog" " -quiet -j y -cwd -once -- " Exe["driver"] " -d " drymode " -p " pid " -n \"" shquote(a[i]) "\""
    print command
    sys2var(command)
    sleep(_delay, "unix")
  }
}

#
# gridwatch - monitor qstat until workers are finished
#
function gridwatch(  op) {
  while(1) {
    op = sys2var("qstat")
    if(empty(op))
      break
    print "\nList of processes still running on grid ..."
    print op
    sleep(5, "unix")
  }
}

#
# gridlog - concat grid log files into single file
#
function gridlog(fid,  cwd,a,b,i,j,logname) {

  cwd = ENVIRON["PWD"]
  if(! chDir(Project["meta"] "gridlog")) {
    stdErr("runbot.awk: Unable to change dir to " Project["meta"] "gridlog")
    exit
  }

  # generate log name incrimenting number ie. auth-runbot-1.log .. auth-runbot-2.log etc..
  if(checkexists(fid "-runbot-1.log")) {
    delete b
    for(i = 1; i <= splitn(sys2var(Exe["ls"] " " fid "*") "\n", a, i); i++)
      b[splitx(splitx(a[i], "[.]", 1), "[-]", 3)] = a[i]
    PROCINFO["sorted_in"] = "@ind_num_desc"
    for(j in b) {
      logname = fid "-runbot-" int(j + 1) ".log"
      break
    }
  }
  else
    logname = fid "-runbot-1.log"

  # create log file
  delete a
  delete b
  for(i = 1; i <= splitn(sys2var(Exe["ls"] " tool*") "\n", a, i); i++)
    b[splitx(a[i], "[.]", 3)] = a[i]
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for(j in b) {
    print readfile2(b[j]) >> logname
    removefile(b[j])
  }
  chDir(cwd)

}

