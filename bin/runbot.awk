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
}

@include "botwiki.awk"
@include "library.awk"

BEGIN {

  delay = "0.5"  # delay between each proc startup
  procs = "10"   # number of procs to run in parallel

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

  # parallel -a meta/$1/$2 -r --delay 0.5 --trim lr -k -j 10 ./driver -d n -p $1 -n {}
  command = Exe["parallel"] " -a " Project["meta"] fid " -r --delay " delay " --trim lr -k -j " procs " " Exe["driver"] " -d " drymode " -p " pid " -n {}"

  while ( (command | getline fish) > 0 ) {
    if ( ++scale == 1 )     {
      print fish
    }
    else     {   
      print "\n" fish      
    }
  }
  close(command)
  
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
  acount = sys2var(Exe["wc"] " -l " shquote(Project["meta"] fid) " | awk '{print $1}'")
  avgsec = datef / acount
  print "\nProcessed " acount " articles in " (datef / 60) " minutes. Avg " (datef / acount) " sec each (delay = " delay "sec ; procs = " procs  ")"

}
