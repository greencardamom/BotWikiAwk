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

  # Multitasking engine method
  _engine = 2  # 0 = GNU parallel (for single computer with multi-core CPU)
               # 1 = Toolforge grid job-array (fast/huge! use with caution if doing outside network requests)
               # 2 = Toolforge grid jsub (adjustable speed 1 worker every x seconds)

  # Engine settings
  _delay = "0.5"      # GNU parallel: delay between each worker startup
  _procs = "20"       # GNU parallel: max number of parallel workers at a time
  _griddelay = "0.5"  # Toolforge grid: jsub delay between each worker startup

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

function main(pid,fid,dry,   dateb,cwd,command,drymode,fish,scale,datee,datef,acount,avgsec,jsjid) {

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
    if (!checkexists(Project["meta"] "gridlog"))
        mkdir(Project["meta"] "gridlog")
    tup(gridfireArray(Project["meta"] fid, drymode, pid), jsjid)
    gridwatchArray(jsjid[2])
    gridlogArray(fid, jsjid[2], pid, jsjid[1])
    print "Job completed."
  }
  else if(_engine == 2) {
    _delay = _griddelay
    if(!checkexists(Project["meta"] "gridlog"))
      mkdir(Project["meta"] "gridlog")
    jsjid = gridfireJsub(Project["meta"] fid, drymode, pid)
    gridwatchJsub(jsjid)
    gridlogJsub(fid)
  }

  system("")
  sleep(1)

  # ./project -j -p $1
  command = Exe["project"] " -j -p " pid
  sys2var(command)

  system("")
  sleep(1)

  # mv meta/$1/index.temp meta/$1/index.temp.$2
  if(checkexists(Project["meta"] "index.temp" ))
    sys2var(Exe["mv"] " " shquote(Project["meta"] "index.temp") " " shquote(Project["meta"] "index.temp." fid) )

  bell()

  datef = sys2var(Exe["date"] " +'%s'") - dateb
  acount = wc(Project["meta"] fid)
  printf "\nProcessed " acount " articles in " (datef / 60) " minutes. Avg " (datef / acount) " sec each"
  if(_engine == 0)
    print " (delay = " _delay "sec ; procs = " _procs  ")"
  else if(_engine == 1 || _engine == 2)
    print
}

#
# gridfire - start driver.awk workers on the grid using jsub with _delay between each startup
#
function gridfireJsub(auth, drymode, pid,    i,a,command) {

  for(i = 1; i <= splitn(auth, a, i); i++) {
    command = "jsub -N tools.botwikiawk-" BotName "-" i " -o " Project["meta"] "gridlog" " -quiet -j y -cwd -once -- " Exe["driver"] " -d " drymode " -p " pid " -n \"" shquote(a[i]) "\""
    print command
    sys2var(command)
    sleep(_delay, "unix")
  }
  return i - 1
}
#
# gridwatch - monitor qstat until workers are finished
#
function gridwatchJsub(jobsize,  op) {
  printf "Waiting on " jobsize " workers "

  while(1) {
    op = sys2var("qstat -j tools.botwikiawk-" BotName "-? 2>/dev/null" )
    if(empty(strip(op)))
      break
#    print "\nList of processes still running on grid ..."
#    print op
    printf "."
    sleep(5, "unix")
  }
  print
}
#
# gridlog - concat grid log-files into single file
#
function gridlogJsub(fid,  cwd,a,b,i,j,logname) {

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

  print "\nCreating log " Project["meta"] "gridlog/" logname

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


#
# gridfire - start driver.awk workers on the grid using a qsub -t job-array
#
function gridfireArray(auth, drymode, pid,   driver,procname,logdir,jobsize,command,op,a) {

  driver = sys2var("readlink -f `which " Exe["driver"] "`")
  procname = "tools.botwikiawk-" pid
  logdir = Project["meta"] "gridlog"
  jobsize = wc(auth)
  if(empty(jobsize) || jobsize < 1 ) {
    stdErr("runbot.awk: unable to determine size of auth file " auth)
    exit
  }
  if(!empty(driver)) {

    # standard settings found in /usr/bin/jsub plus the -t job-array, -j y, and -cwd .. need -once?
    # /usr/bin/qsub -t 1-5:1 -j y -o /data/project/botwikiawk/BotWikiAwk/bots/accdate/meta/accdate20180614.0001-0010/gridlog -M tools.botwikiawk@tools.wmflabs.org -N test3 -hard -l h_vmem=524288k -l release=trusty -q task -b yes /mnt/nfs/labstore-secondary-tools-project/botwikiawk/BotWikiAwk/bots/accdate/test.awk

    command = "/usr/bin/qsub -t 1-" jobsize ":1 -j y -o " logdir " -M tools.botwikiawk@tools.wmflabs.org -N " procname " -hard -l h_vmem=524288k -l release=trusty -cwd -q task -b yes " driver " -d " shquote(drymode) " -p " shquote(pid) " -n _gridarray -a " shquote(auth)

    # Your job-array 432577.1-5:1 ("test3") has been submitted
    op = sys2var(command)
    if(op ~ /has been submitted/)
      return jobsize SUBSEP strip(splitx(splitx(op, "[.]", 1), "[ ]", 3))
    else {
      stdErr("runbot.awk: Unable to submit job. Returned message: " op)
      exit
    }
  }
  else {
    stdErr("runbot.awk: unable to find driver.awk")
    exit
  }
  return "0" SUBSEP "0"
}

#
# gridwatch - monitor qstat until workers are finished
#
function gridwatchArray(jid,  op,re) {

  print "Job-array " jid " submitted."

  re = "^[ ]" jid
  while(1) {
    op = sys2var("qstat")
    if(empty(op))
      break
    if(op ~ re)
      sleep(5, "unix")
    else
      break
  }
}

#
# gridlog - concat grid log-files into single file
#
function gridlogArray(fid,jid,pid,jobsize,   cwd,a,b,c,fn,i,j,z,logname) {


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


  printf "Waiting on " jobsize " workers "

 # monitor logs - this can deadlock so it's important driver.awk output something to stderr
 #                for each worker even when it does nothing else - such as the wikiname processed

 #      tools.botwikiawk-accdate20180614.0001-0010.o436955.1
  fn = "tools.botwikiawk-" pid ".o" jid "." jobsize  # wait for last worker
  delete a
  while(1) {
    if(checkexists(fn)) {
      c = splitn(sys2var(Exe["ls"] " tool*") "\n", a)
      if(c == jobsize)
        break
    }
    sleep(5, "unix")
    printf "."
  }

  print "\nCreating log " Project["meta"] "gridlog/" logname

 # aggregate log files into one, remove individuals

  delete a
  delete b

  for(i = 1; i <= splitn(sys2var(Exe["ls"] " tools.*") "\n", a, i); i++)
    b[splitx(subs("-" pid, "", a[i]), "[.]", 4)] = a[i]

  PROCINFO["sorted_in"] = "@ind_num_asc"
  for(j in b) {
    print readfile2(b[j]) >> logname
    removefile2(b[j])
  }
  chDir(cwd)

}

