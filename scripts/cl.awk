#!/usr/local/bin/gawk -E

#
# Delete entries from a logfile based on a list of names in namefile
# If -mk do the opposite .. keep only the entries in logfile contained in namefile
#
# Memory required: size of logfile x2 + size of namefile
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

@load "filefuncs"

BEGIN {

  # Number of re statements to stack with pipes .. too big it crushes memory too small it runs slow
  Blocksize = 500

  debug = 0

  delete opmode

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "m:n:l:")) != -1) {
    if(C == "n")
      namefile = Optarg
    if(C == "l")
      logfile = Optarg
    if(C == "m")              # -m <mode>  d=delete, k=keep. Default is delete. 
      opmode["arg"] = Optarg
  }

  if(!length(namefile)) {
    print "Unable to open namefile: " namefile
    exit
  }
  if(!length(logfile)) {
    print "Unable to open logfile: " logfile
    exit
  }

  if(opmode["arg"] != "k") {
    opmode["default"] = "keep"
    opmode["action"] = "delete"
  }
  else {
    opmode["default"] = "delete"
    opmode["action"] = "keep"
  }

  if(logfile ~ /^index/) 
    rebreak = "[|]"
  else
    rebreak = "([-]{4}|$)"

  tlog = logfile ".deletename"

  c = split(readfile(namefile), a, "\n")
  d = split(readfile(logfile), b, "\n")

  blocks = getblocks(c)

  # pre-populate z[] array marking all as "keep"
  # any marked "delete" later on will be
  for(k = 1; k < d; k++) 
    z[b[k]]["tag"] = opmode["default"]

  if(debug) {
    print "c = " c 
    print "d = " d 
    print "blocks = " blocks 
  }

  for(bl = 1; bl <= blocks; bl++) {

    if(bl == 1) {
      start = bl
      end = Blocksize
    }
    else {
      start = (bl * Blocksize) - (Blocksize - 1)
      end = (bl * Blocksize)
    }

    if(debug) 
      print "start = " start " ; end = " end 

    out = ""
    for(i = start; i <= end; i++) {
      if(! empty(a[i]) ) {
        if (i == end || i == c-1)
          out = out regesc2(a[i])
        else
          out = out regesc2(a[i]) "|"
      }
    }

    re = "^(" out ")[ ]*" rebreak

    if(debug) 
      print "re = " re 

    for(k = 1; k < d; k++) {
      if(b[k] ~ re) 
        z[b[k]]["tag"] = opmode["action"]
    }

    close(tlog)

  }

  for(o in z) {
    if(opmode["arg"] != "k") {
      if(z[o]["tag"] == opmode["default"]) 
        print o >> tlog
    }
    else {
      if(z[o]["tag"] == opmode["action"]) 
        print o >> tlog
    }
  }
  
  close(tlog)
  if(exists(tlog)) {
    if(! debug)  {
      print readfile(tlog)
      command = "rm " tlog
      system(command)
      close(command)
    }
  }

}

#
# Divide number of lines in file by Blocksize and return number of blocks
#  If 0.xx return 1
#  If 1.0 return 1
#  If 1.xx return 2
#
function getblocks(i,  c, e, a) {

  c = int(i) / Blocksize
  e = split(c, a, "[.]")
  if(e == 1)
    return c
  if(int(a[1]) == 0)
    return 1
  if(int(a[2]) > 0)
   return int(a[1]) + 1

}

#______________________ UTILITIES ________________________

#
# strip - strip leading/trailing whitespace
#
#   . faster than gsub() or gensub() methods eg.   
#        gsub(/^[[:space:]]+|[[:space:]]+$/,"",s)
#        gensub(/^[[:space:]]+|[[:space:]]+$/,"","g",s)
#         
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
#       
function strip(str) {        
    if (match(str, /[^ \t\n].*[^ \t\n]/))
        return substr(str, RSTART, RLENGTH)
    else if (match(str, /[^ \t\n]/))
        return substr(str, RSTART, 1)
    else
        return ""
}

#      
# regesc2 - escape regex symbols
#
function regesc2(str,   safe) {
  safe = str          
  gsub(/[][^$".*?+{}\\()|]/, "\\\\&", safe)
  gsub(/&/,"\\\\\\&",safe)
  return safe            
}

#   
# empty - return 0 if string is 0-length
#
function empty(s) {           
  if(length(s) == 0)          
    return 1  
  return 0
}             

#               
# exists - check for file existence
#         
#   . return 1 if exists, 0 otherwise.
#   . requirement: @load "filefuncs"
#
function exists(name    ,fd) {
    if ( stat(name, fd) == -1)
      return 0
    else
      return 1
}

# 
# readfile - same as @include "readfile"                  
#
#   . leaves an extra trailing \n just like with the @include readfile      
# 
#   Credit: https://www.gnu.org/software/gawk/manual/html_node/Readfile-Function.html by by Denis Shirokov
# 
function readfile(file,     tmp, save_rs) {
    save_rs = RS
    RS = "^$"
    getline tmp < file
    close(file)
    RS = save_rs
    return tmp
}                

#
# getopt - command-line parser
# 
#   . define these globals before getopt() is called:
#        Optind = Opterr = 1
# 
#   Credit: GNU awk (/usr/local/share/awk/getopt.awk)
# 
function getopt(argc, argv, options,    thisopt, i) {

    if (length(options) == 0)    # no options given
        return -1     

    if (argv[Optind] == "--") {  # all done
        Optind++
        _opti = 0
        return -1
    } else if (argv[Optind] !~ /^-[^:[:space:]]/) {
        _opti = 0
        return -1
    }
    if (_opti == 0)
        _opti = 2
    thisopt = substr(argv[Optind], _opti, 1)
    Optopt = thisopt                
    i = index(options, thisopt)
    if (i == 0) {     
        if (Opterr)
            printf("%c -- invalid option\n", thisopt) > "/dev/stderr"
        if (_opti >= length(argv[Optind])) {
            Optind++
            _opti = 0
        } else
            _opti++
        return "?"
    }
    if (substr(options, i + 1, 1) == ":") {
        # get option argument
        if (length(substr(argv[Optind], _opti + 1)) > 0)
            Optarg = substr(argv[Optind], _opti + 1)
        else
            Optarg = argv[++Optind]
        _opti = 0
    } else
        Optarg = ""
    if (_opti == 0 || _opti >= length(argv[Optind])) {
        Optind++
        _opti = 0
    } else
        _opti++
    return thisopt
}


