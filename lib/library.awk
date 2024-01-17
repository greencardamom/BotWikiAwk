#
# General Library routines
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

@load "filefuncs"
@include "syscfg" # Paths to external programs and define static strings

# [[ __________________________________________________________________________________ ]]
# [[ __________________ TOC ___________________________________________________________ ]]
# [[ __________________________________________________________________________________ ]]
#
#  . Files and dirs
#  . System and I/O
#  . Strings
#  . Wikipedia markup
#  . Numbers
#  . URL Encode/Decode
#

# [[ __________________________________________________________________________________ ]]
# [[ __________________ Files and dirs ________________________________________________ ]]
# [[ __________________________________________________________________________________ ]]

#
# dirname() - return the directory portion of a /dir/filename string. 
#
#   . returned string will have a trailing "/"
#
#   Example:
#      /home/adminuser/wi-awb/tcount.awk -> /home/adminuser/wi-awb/
#
function dirname (pathname){
    if (sub(/\/[^\/]*$/, "", pathname))
        return pathname "/"
    else
        return "." "/"
}

# 
# basename() - return the file portion of a /dir/filename string
#
#   Example:
#      /home/adminuser/wi-awb/tcount.awk -> tcount.awk
#
function basename(pathname, a, n) {
    n = split(pathname, a, /[/]/)
    return a[n]
}

#
# removefile() - delete a file
#
#   . rm options can be passed in 'opts'
#   . no wildcards
#   . return 0 on error .. or abort
#
#   Requirement: Exe["rm"] 
#                @load "filefuncs"
#
function removefile(str,opts) {
    if (!checkexe(Exe["rm"], "rm"))
        return 0
    if (str ~ /[*|?]/ || empty(str)) return 0
    close(str)
    if (checkexists(str))
        sys2var( Exe["rm"] " " opts " -- " shquote(str) )
    system("") # Flush buffer
    if (checkexists(str)) {
        stdErr("Error: unable to delete " str ", aborting.")
        exit          
    }              
    return 1
}      

#   
# removefile2() - delete a file/directory
#
#   . no wildcards
#   . return 1 success
#
#   Requirement: rm
#
function removefile2(str) {

    if (str ~ /[*|?]/ || empty(str))
        return 0
    system("") # Flush buffer
    if (exists2(str)) {
      sys2var("rm -r -- " shquote(str) )
      system("")
      if (! exists2(str))
        return 1
    }
    return 0
}

#
# checkexists() - check file or directory exists. 
#
#   . action = "exit" or "check" (default: check)
#   . return 1 if exists, or exit if action = exit
#   . requirement: @load "filefuncs"
#
function checkexists(file, program, action) {                       
    if ( ! exists(file) ) {              
        if ( action == "exit" ) {
            stdErr(program ": Unable to find/open " file)
            print program ": Unable to find/open " file  
            system("")
            exit
        }
        else
            return 0
    }
    else
        return 1
}

#
# checkexe() - check an Exe[] - external program - is defined 
#
#   . return 0 if not
#
function checkexe(exe, name) {
    if (empty(exe)) {
        stdErr("checkexe(): External program '" name "' undefined.")
        return 0
    }
    return 1
}

#
# exists() - check for file existence
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
# exists2() - check for file existence
#
#   . return 1 if exists, 0 otherwise.
#   . no dependencies
#
function exists2(file    ,line, msg) {
    if ((getline line < file) == -1 ) {
        msg = (ERRNO ~ /Permission denied/ || ERRNO ~ /a directory/) ? 1 : 0
        close(file)
        return msg
    }
    else {
        close(file)
        return 1
    }
}

#
# filesize() - file size
#
#   . requirement: @load "filefuncs"
#
function filesize(name         ,fd) {
    if ( stat(name, fd) == -1) 
        return -1  # doesn't exist
    else
        return fd["size"]
}

#
# stripfile() - strip blank lines from start/end of a file
#
#   . if type = "inplace" it will overwrite file, otherwise return as variable
#        These do the same:
#           out = stripfile("test.txt"); print out > "test.txt"; close("test.txt")
#           stripfile("test.txt", "inplace")
#   . alt one-liner shell method:
#           https://stackoverflow.com/questions/7359527/removing-trailing-starting-newlines-with-sed-awk-tr-and-friends   
#           awk '{ LINES=LINES $0 "\n"; } /./ { printf "%s", LINES; LINES=""; }' input.txt | sed '/./,$\!d' > output.txt   
#
#   Requirement: Exe["tac"]
#                Exe["sed"]
#
function stripfile(filen, type,    fp) {
  
    if ( ! exists(filen) ) {
        stdErr("stripfile(): Unable to find " filen)
        return 
    }
    if ( ! checkexe(Exe["tac"], "tac") || ! checkexe(Exe["sed"], "sed"))
        return filen

    # tac 'file' | sed -e '/./,$!d' | tac | sed -e '/./,$!d'
    fp = sys2var(Exe["tac"] " " shquote(filen) " | " Exe["sed"] " -e '/./,$!d' | " Exe["tac"] " | " Exe["sed"]  " -e '/./,$!d'")

    if (type == "inplace") {
        close(filen)
        sleep(1)
        print fp > filen
        close(filen)
        return
    }
    else {
        return fp
    }
}

#
# mktemp() - make a temporary unique file or directory and/or returns its name
#
#  . the last six characters of 'template' must be "XXXXXX" which will be replaced by a uniq string
#  . if template is not a pathname, the file will be created in ENVIRON["TMPDIR"] if set otherwise /tmp
#  . if template not provided defaults to "tmp.XXXXXX"
#  . recommend don't use spaces or " or ' in pathname
#  . if type == f create a file
#  . if type == d create a directory
#  . if type == u return the name but create nothing
#
#  Example:
#     outfile = mktemp(meta "index.XXXXXX", "u")
#
#  Credit: https://github.com/e36freak/awk-libs
#  mods by GreenC
#
function mktemp(template, type,                 
                c, chars, len, dir, dir_esc, rstring, i, out, out_esc, umask,
                cmd) {           

  # portable filename characters
    c = "012345689ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    len = split(c, chars, "")

  # make sure template is valid
    if (length(template)) {
        if (template !~ /XXXXXX$/) {
            return -1
        } 

  # template was not supplied, use the default
    } else {
        template = "tmp.XXXXXX"
    }         
  # make sure type is valid
    if (length(type)) {
        if (type !~ /^[fdu]$/) {
            return -1
        }
  # type was not supplied, use the default
    } else {
        type = "f"
    }

  # if template is a path...
    if (template ~ /\//) {
        dir = template
        sub(/\/[^/]*$/, "", dir)
        sub(/.*\//, "", template)
  # template is not a path, determine base dir
    } else {
        if (length(ENVIRON["TMPDIR"])) {
            dir = ENVIRON["TMPDIR"]
        } else {
            dir = "/tmp"
        }
    }

  # if this is not a dry run, make sure the dir exists
    if (type != "u" && ! exists(dir)) {
        return -1
    }

  # get the base of the template, sans Xs
    template = substr(template, 0, length(template) - 6)

  # generate the filename
    do {
        rstring = ""
        for (i=0; i<6; i++) {
            c = chars[int(rand() * len) + 1]
            rstring = rstring c
        }
        out = dir "/" template rstring
    } while( exists(out) )

    if (type == "f") {
        printf "" > out
        close(out)
    } else if (type == "d") {
        mkdir(out)
    }
    return out
}

#
# mkdir() - make a directory ("mkdir -p dir")
#
#   . return 0 on error or if dir already exists
#
#   Requirement: Exe["mkdir"]
#
function mkdir(dir,    var, cwd) {

    if ( ! checkexe(Exe["mkdir"], "mkdir") )
        return 0    

    if (empty(dir)) return 0
    if (checkexists(dir)) return 0
    sys2var(Exe["mkdir"] " -p " shquote(dir) " 2>/dev/null")
    cwd = ENVIRON["PWD"]
    if (! chDir(dir)) {
        StdErr("Could not create " shquote(dir) " (" ERRNO ")\n")
        return 0
    }
    if (! chDir(cwd)) {
        StdErr("Could not chdir to " shquote(cwd) " (" ERRNO ")\n")
        return 0                              
    }           
    return 1    
}           

#
# chDir() --- change directory
#
#   . return 0 on failure
#
#   Requirement: @load "filefuncs"
#
function chDir(dir, ret) {

    ret = chdir(dir)
    if (ret < 0) {
        return 0
    }
    else
        return 1
}

# [[ __________________________________________________________________________________ ]]
# [[ __________________ System and I/O ________________________________________________ ]]
# [[ __________________________________________________________________________________ ]]

# 
# shquote() - make string safe for shell
#
#  . an alternate is shell_quote.awk in /usr/local/share/awk which uses '"' instead of \'
#
#  Example:
#     print shquote("Hello' There")    produces 'Hello'\'' There'              
#     echo 'Hello'\'' There'           produces Hello' There                 
# 
function shquote(str,  safe) {
    safe = str
    gsub(/'/, "'\\''", safe)
    gsub(/’/, "'\\’'", safe)
    return "'" safe "'"
}

#
# sys2var() - run a system command and store result in a variable
#
#  . supports pipes inside command string
#  . stderr is sent to null
#  . if command fails (errno) return null
#
#  Example:
#     googlepage = sys2var("wget -q -O- http://google.com")
#
function sys2var(command        ,fish, scale, ship) {

    # command = command " 2>/dev/null"
    while ( (command | getline fish) > 0 ) {
        if ( ++scale == 1 )
            ship = fish
        else
            ship = ship "\n" fish
    }
    close(command)
    system("")
    return ship
}

#
# sys2varPipe() - supports piping string data into a program eg. echo <data> | <command>
#
#  . <data> is a string not a command
#
#   Example: 
#      replicate 'cat /etc/passwd | wc'
#        print sys2varPipe(readfile("/etc/passwd"), Exe["wc"])
#      send output of one command to another
#        print sys2varPipe(sys2var("date +\"%s\""), Exe["wc"])
#
function sys2varPipe(data, command,   fish, scale, ship) {

    printf("%s",data) |& command
    close(command, "to")

    while ( (command |& getline fish) > 0 ) {
        if ( ++scale == 1 )
            ship = fish
        else
            ship = ship "\n" fish
    }
    close(command)
    return ship
}

#                       
# sys2varStderr() - run a system command and return stderr value
#
#   . the numeric stderr is returned on the last line of the output
#   . if command fails (errno) return null
#
#   Example:
#     print sys2varStderr("ls -l") 
#       > total 165028 0
#     note it only prints the last line of the ls -l command, and the stderr code is the last digit ("0")
#
function sys2varStderr(command        ,fish,scale,ship,c,a) {

    command = command " ; echo $?"              
    while ( (command | getline fish) > 0 ) {
        if ( ++scale == 1 )
            ship = fish
        else
            ship = ship "\n" fish
    }
    close(command)
    c = split(ship, a, "\n")
    return a[1] " " a[c]
}

#
# http2var() - replicate "wget -q -O- http://..." 
#
#   . return the HTML page as a string
#   . optionally use wget options 'Wget_opts' gobally defined in syscfg.awk - or define it locally
#   . converts ' to %27 and ’ to %E2%80%99
#
#   Requirement: Exe["wget"]
#   Requirement: Exe["timeout"]
#
function http2var(url,tries,  debug,i,op) {

     debug = 0

     if ( ! checkexe(Exe["wget"], "wget") || !  checkexe(Exe["timeout"], "timeout"))
       return

     if(empty(tries))
       tries = 20

     if (url ~ /'/)
         gsub(/'/, "%27", url)
     if (url ~ /’/)
         gsub(/’/, "%E2%80%99", url)

     command = Exe["timeout"] " 20m " Exe["wget"] Wget_opts " -q -O- " shquote(url)

     if(debug) stdErr(command)

     for(i = 1; i <= int(tries); i++) {
       op = sys2var( command )
       if(!empty(op))
         return op
       if(debug) stdErr("http2var retry " i)
       if(! empty(Exe["sleep"]))
         sleep(2, "unix")
       else
         sleep(2)
     }

     # Depending on your application, you can add an email() notification when tries reaches the maximum 
     #  It signifies the remote site is not responding. 

}

# 
# dateeight() - return current date: 20170610
# 
#   Requirement: Exe["date"]
#
function dateeight() {

    if ( ! checkexe(Exe["date"], "date") )
        return 
    return sys2var( Exe["date"] " +\"%Y%m%d\"")
}

#
# sleep() - sleep seconds
#
#   . Caution: systime() method eats CPU and has up-to 1 second error of margin (averge half-second)
#   . optional "unix" will spawn unix sleep
#   . Use unix sleep for applications with long or many sleeps, needing precision, or sub-second sleep
#
function sleep(seconds,opt,   t) {

    if (opt == "unix")
        sys2var("sleep " seconds)
    else {
      t = systime()
      while (systime() < t + seconds) {}
    }

}

# 
# stdErr() - print s to /dev/stderr
#
#  . if flag = "n" no newline
#
function stdErr(s, flag) {
    if (flag == "n")
        printf("%s",s) > "/dev/stderr"
    else
        printf("%s\n",s) > "/dev/stderr"
    close("/dev/stderr")
}

#
# readfile() - same as @include "readfile"        
#
#   . leaves an extra trailing \n just like with the @include readfile
#
#   Credit: https://www.gnu.org/software/gawk/manual/html_node/Readfile-Function.html by Denis Shirokov
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
# readfile2() - similar to readfile but no trailing \n
#
#   Credit: https://github.com/dubiousjim/awkenough getfile()
#
function readfile2(path,   v, p, res) {
    res = p = ""
    while (0 < (getline v < path)) {
        res = res p v
        p = "\n"
    }  
    close(path)
    return res       
}               


#
# getopt() - command-line parser
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

#
# Send email via external SMTP server
#
#   Requirements: Exe["curl"] = /path/curl
#                 Exe["email_auth"] = /path/filename
#                  
#   Exe["email_auth"]:
#      This filename contains a single line with SMTP server authentication credentials. For example:
#        smtp://myprovider.net:26/novalidate-cert/user=joe@mydomain.com
#
#   If your application has "@include botwiki" or "@include library" or "@include syscfg" nothing more needs to be done. 
#      See syscfg.awk for default email settings.
#
#   You can adjust the values of Exe["from_email"] and Exe["to_email"] on the fly in your application.
#
#   Invoke like this:
#
#      email(Exe["from_email"], Exe["to_email"], "NOTIFY: Program Aborted", "This is the body")
#
#   Or simply like this with static From: and To: strings:
#
#      email("payables@mydomain.com", "office@example.com", "Payment due", "This is the body")
#
function email(from, to, subject, body,   outfile,s) {

  if(empty(from) || empty(to) ) {
    stdErr("email() in library.awk has empty From:, or To:, or Subject:")
    return 0
  }
  if(empty(Exe["curl"])) {
    stdErr("Curl not defined for email() in library.awk - Add Exe[\"curl\"] = /path/curl to your program")
    return 0
  }
  if(empty(Exe["email_auth"]) || !exists2(Exe["email_auth"]) ) {
    stdErr("Email authentication not defined. See email() in library.awk for instructions")
    return 0
  }

  outfile = mktemp("/tmp/email.XXXXXX", "u")

  print "To: " to > outfile
  print "From: " from >> outfile
  print "Date: " sys2var(Exe["date"] " -R") >> outfile   # Formated in RFC 2922 with -R switch
  print "Subject: " subject >> outfile
  if(!empty(body)) {
    print "" >> outfile
    print body >> outfile
  }
  close(outfile)

  emailauth = strip(readfile(Exe["email_auth"]))

  # https://superuser.com/questions/1539589/curl-how-do-i-set-the-email-subject-when-using-f-multipart-attachment
  s = Exe["curl"] " -s " shquote(emailauth) " --mail-from " shquote(from) " --mail-rcpt " shquote(to) " --upload-file " shquote(outfile)
  sys2var(s)
  removefile2(outfile)

}


# [[ __________________________________________________________________________________ ]]
# [[ ______________________ Strings ___________________________________________________ ]]
# [[ __________________________________________________________________________________ ]]

#
# join() - merge an array of strings into a single string. Array indice are numbers.
#
#   Credit: /usr/local/share/awk/join.awk by Arnold Robbins 1999
#
function join(arr, start, end, sep,    result, i) {
    if (length(arr) == 0)
        return ""

    result = arr[start]

    for (i = start + 1; i <= end; i++)
        result = result sep arr[i]

    return result
}

#
# join2() - merge an array of strings into a single string. Array indice are strings.
#
#   . optional third argument 'sortkey' informs how to sort:
#       https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html
#   . spliti() does reverse 
#
function join2(arr, sep, sortkey,         i,lobster,result,save_sorted) {

    if (!empty(sortkey)) {
        if ("sorted_in" in PROCINFO) 
            save_sorted = PROCINFO["sorted_in"]
        PROCINFO["sorted_in"] = sortkey
    }

    for ( lobster in arr ) {
        if (++i == 1) {
            result = lobster
            continue
         }
         result = result sep lobster
    }

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

    return result
}

#
# unpatsplit() - join arrays created by patsplit()
#
function unpatsplit(field,sep,   c,output,debug) {

    debug = 0
    if (length(field) > length(sep)) return

    output = sep[0]
    for (c = 1; c < length(field) + 1; c++) {
        if (debug) {
            print "field[" c "] = " field[c]
            print "sep[" c "] = " sep[c]
        }
        output = output field[c] sep[c]
    } 
    return output
}

#
# tup() - tool to allow functions to return multiple values like a proto-tuple
#
#   . 'f' should be values seperated by SUBSEP                      
#
#   Example: tup(splitup(), a) => a[2] == "world"     
#            function splitup() { return "hello" SUBSEP "world" }     
#
function tup(f, a) {
  delete a
  return split(f, a, SUBSEP)
}

#
# strip() - strip leading/trailing whitespace
#
#   . faster than the gsub() or gensub() methods eg.
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
# empty() - return 0 if string is 0-length
#
function empty(s) {
    if (length(s) == 0)
        return 1
    return 0
}


#
# startswith() - return 1 if str starts with pre (non-regex)
#
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
#
function startswith(str, pre,   len2) {
    len2 = length(pre)
    return substr(str, 1, len2) == pre
}

#
# endswith() - return 1 if str ends with suf (non-regex)
#
#   Credit: https://github.com/dubiousjim/awkenough by Jim Pryor 2012
#
function endswith(str, suf,   len1, len2) {
    len1 = length(str)
    len2 = length(suf)
    return len2 <= len1 && substr(str, len1 - len2 + 1) == suf
}

#
# clean() - remove HTML codes
#            
function clean(str,  safe) {           
    safe = str
    gsub(/\342\200\231/, "'", safe)
    gsub(/\342\200\230/, "`", safe)                  
    gsub(/\342\200\246/, "…", safe)
    gsub(/\342\200\223/, "-", safe)
    gsub(/\342\200\224/, "—", safe)
    gsub(/\342\200\234/, "“", safe)
    gsub(/\342\200\235/, "\"", safe)
    return safe
}

#
# convertxml() - convert XML to plain
#  . option - convertxml(s,"all") will also do additional characters 
#
function convertxml(str,flag,   safe) {

    safe = str
    gsub(/&lt;/,"<",safe)
    gsub(/&gt;/,">",safe)
    gsub(/&quot;/,"\"",safe)
    gsub(/&amp;/,"\\&",safe)
    gsub(/&#039;/,"'",safe)
    gsub(/&#10;/,"'",safe)
    gsub(/&middot;/,"·",safe)
    gsub(/&raquo;/,"»",safe)
    gsub(/&laquo;/,"«",safe)
    gsub(/&rsquo;/,"’",safe)
    gsub(/&lsquo;/,"‘",safe)
    gsub(/&prime;/,"′",safe)
    gsub(/&hellip;/,"…",safe)
    gsub(/&frasl;/,"⁄",safe)
    gsub(/&mdash;/,"—",safe)

    # https://www.starr.net/is/type/htmlcodes.html
    #  create two files one with each column o1 = left and o2 = right
    #  paste o1 o2 | awk '{split($0,a,/[\t ]*/);print "      gsub(/" a[2] "/,\"" a[1] "\",safe)"}'
  
    if(flag == "all") {

      ic = IGNORECASE
      IGNORECASE = 0

      gsub(/&Aacute;/,"Á",safe)
      gsub(/&aacute;/,"á",safe)
      gsub(/&Agrave;/,"À",safe)
      gsub(/&Acirc;/,"Â",safe)
      gsub(/&agrave;/,"à",safe)
      gsub(/&Acirc;/,"Â",safe)
      gsub(/&acirc;/,"â",safe)
      gsub(/&Auml;/,"Ä",safe)
      gsub(/&auml;/,"ä",safe)
      gsub(/&Atilde;/,"Ã",safe)
      gsub(/&atilde;/,"ã",safe)
      gsub(/&Aring;/,"Å",safe)
      gsub(/&aring;/,"å",safe)
      gsub(/&Aelig;/,"Æ",safe)
      gsub(/&aelig;/,"æ",safe)
      gsub(/&Ccedil;/,"Ç",safe)
      gsub(/&ccedil;/,"ç",safe)
      gsub(/&Eth;/,"Ð",safe)
      gsub(/&eth;/,"ð",safe)
      gsub(/&Eacute;/,"É",safe)
      gsub(/&eacute;/,"é",safe)
      gsub(/&Egrave;/,"È",safe)
      gsub(/&egrave;/,"è",safe)
      gsub(/&Ecirc;/,"Ê",safe)
      gsub(/&ecirc;/,"ê",safe)
      gsub(/&Euml;/,"Ë",safe)
      gsub(/&euml;/,"ë",safe)
      gsub(/&Iacute;/,"Í",safe)
      gsub(/&iacute;/,"í",safe)
      gsub(/&Igrave;/,"Ì",safe)
      gsub(/&igrave;/,"ì",safe)
      gsub(/&Icirc;/,"Î",safe)
      gsub(/&icirc;/,"î",safe)
      gsub(/&Iuml;/,"Ï",safe)
      gsub(/&iuml;/,"ï",safe)
      gsub(/&Ntilde;/,"Ñ",safe)
      gsub(/&ntilde;/,"ñ",safe)
      gsub(/&Oacute;/,"Ó",safe)
      gsub(/&oacute;/,"ó",safe)
      gsub(/&Ograve;/,"Ò",safe)
      gsub(/&ograve;/,"ò",safe)
      gsub(/&Ocirc;/,"Ô",safe)
      gsub(/&ocirc;/,"ô",safe)
      gsub(/&Ouml;/,"Ö",safe)
      gsub(/&ouml;/,"ö",safe)
      gsub(/&Otilde;/,"Õ",safe)
      gsub(/&otilde;/,"õ",safe)
      gsub(/&Oslash;/,"Ø",safe)
      gsub(/&oslash;/,"ø",safe)
      gsub(/&szlig;/,"ß",safe)
      gsub(/&Thorn;/,"Þ",safe)
      gsub(/&thorn;/,"þ",safe)
      gsub(/&Uacute;/,"Ú",safe)
      gsub(/&uacute;/,"ú",safe)
      gsub(/&Ugrave;/,"Ù",safe)
      gsub(/&ugrave;/,"ù",safe)
      gsub(/&Ucirc;/,"Û",safe)
      gsub(/&ucirc;/,"û",safe)
      gsub(/&Uuml;/,"Ü",safe)
      gsub(/&uuml;/,"ü",safe)
      gsub(/&Yacute;/,"Ý",safe)
      gsub(/&yacute;/,"ý",safe)
      gsub(/&yuml;/,"ÿ",safe)

      IGNORECASE = ic
    }

    return safe
}

#
# regesc3() - escape regex symbols using square brackets []
#
#   Example:
#      print regesc3("&^$(){}[].*+?|\\=:") produces &[\\^][$][(][)][{][}]\[\][.][*][+][?][|]\\[=][:]
#
#   . consider instead using the non-regex subs() and gsubs()
#
#   Credit: https://github.com/cheusov/runawk/blob/master/modules/str2regexp.awk
#
function regesc3 (str,   safe) {
    safe = str
    gsub(/\[/, "---open-sq-bracket---", safe)
    gsub(/\]/, "---close-sq-bracket---", safe)

    gsub(/[?{}|()*+.$=:]/, "[&]", safe)
    gsub(/\^/, "[\\^]", safe)

    if (safe ~ /\\/)
      gsub(/\\/, "\\\\", safe)

    gsub(/---open-sq-bracket---/, "\\[", safe)
    gsub(/---close-sq-bracket---/, "\\]", safe)

    return safe
}

#
# regesc2() - escape regex symbols using backslash \x
#
#   Example:
#      print regesc2("^$(){}[].*+?|\\") produces \^\$\(\)\{\}\[\]\.\*\+\?\|\\
#
#  . consider instead using the non-regex subs() and gsubs()
#
function regesc2(str,   safe) {
    safe = str
    gsub(/[\\.^$(){}\[\]|*+?]/, "\\\\&", safe)
    return safe
}

#
# reverse() - reverse a string
#                  
function reverse(s,  a,i,n) {             

    c = split(s, a, "")
    for(i = c; i >= 1; i--)
        n = n a[i]
    return n

}         

#
# splitx() - split str along re and return num'th element
#
#   Example: 
#      print splitx("a:b:c:d", "[:]", 3) ==> "c"
#
function splitx(str, re, num,    a){
    if(split(str, a, re))
        return a[num]
    else
        return ""
}

#
# splitc() - split str along re and return number of elements
#
#   Example:
#      print splitc("1-2-3", "[-]") ==> 3
#
function splitc(str, re,    a){
    return split(str, a, re)
}

#
# spliti() - split str along re and store result in arr like a normal split
#            but with result stored in the index (key) instead of the value. 
#
#   . value is set to "1" by default, or "val" if optionally given
#
#   Example: 
#      spliti("a:b:c", a, "[:]") 
#      for(i in a) print i         ==> "a b c"
#
function spliti(str,arr,re,val,   a,i) {
    delete arr
    if (empty(val))
        val = 1
    if (split(str,a,re)) {
        for (i in a) 
            arr[a[i]] = val
    }
    return length(arr)
}

#
# splits() - literal version of split()
#
#   . the "sep" is a literal string not re
#   . see also subs() and gsubs()
#
#   Credit: https://github.com/e36freak/awk-libs (Daniel Mills)
#
function splits(str, arr, sep,    len, slen, i) {

    delete arr

  # if "sep" is empty, just do a normal split
    if (!(slen = length(sep))) {
        return split(str, arr, "")
    }

  # loop while "sep" is matched
    while (i = index(str, sep)) {
        # append field to array
        arr[++len] = substr(str, 1, i - 1)

        # remove that portion (with the sep) from the string
        str = substr(str, i + slen)
    }
    arr[++len] = str
    return len
}

#
# asplit() - given a string of "key=value SEP key=value" pairs, break it into array[key]=value
#
#   . can optionally supply "re" for equals, space; if they're the same or equals is "", array will be setlike
#
#   Example
#     asplit(arr, "action=query&format=json&meta=tokens", "=", "&")
#       arr["action"] = "query"
#       arr["format"] = "json"
#       arr["meta"]   = "tokens"
#
#   . join() does the inverse eg. join(arr, 0, length(arr) - 1, "&") == "action=query&format=json&meta=tokens"
#
# Credit: https://github.com/dubiousjim/awkenough
#         GreenC mods   
#
function asplit(array, str, equals, space, aux, i, n) {

    n = split(str, aux, (space == "") ? "[ \n]+" : space)
    if (space && equals == space)
        equals = ""
    else if (!length(equals))        
        equals = "="
    delete array
    for (i = 1; i <= n; i++) {
        if (equals && match(aux[i], equals))
            array[substr(aux[i], 1, RSTART-1)] = substr(aux[i], RSTART+RLENGTH)
        else
            array[aux[i]]
    }
    delete aux
    return n
}

#
# concatarray() - merge array a & b into c       
#
#  . if array a & b have a same key eg. a["1"] = 2 and b["1"] = 3
#      then b takes precendent eg. c["1"] = 3
#           
function concatarray(a,b,c,  i) {

    delete c
    for (i in a)
        c[i]=a[i]
    for (i in b)
       c[i]=b[i]
}

#
# countsubstring() - returns number of occurances of pattern in str
#
#   . pattern treated as a literal string, regex char safe
#   . to count substring using regex use gsub ie. total += gsub("[.]","",str)
#
#   Example: 
#      print countsubstring("[do&d?run*d!run>run*", "run*") ==> 2
#
function countsubstring(str, pat,    len, i, c) {
    c = 0
    if ( ! (len = length(pat) ) ) {
        return 0
    }
    while (i = index(str, pat)) {
        str = substr(str, i + len)
        c++
    }
    return c
}

#
# subs() - like sub() but literal non-regex
#
#   Example:
#      s = "*field"
#      print subs("*", "-", s)  #=> -field
#
#   Credit: adapted from lsub() by Daniel Mills https://github.com/e36freak/awk-libs
#
function subs(pat, rep, str,    len, i) {

    if (!length(str)) 
        return 

    # get the length of pat, in order to know how much of the string to remove
    if (!(len = length(pat))) 
        return str

    # substitute str for rep
    if (i = index(str, pat)) 
        str = substr(str, 1, i - 1) rep substr(str, i + len)

    return str
}

#
# gsubi() - same as gsub() but leave source string unmodified and return new string
#
#   Example:
#      s = "Plain"
#      print gsubi("^P", "p", s) " = " s   #=> plain = Plain
#
function gsubi(pat, rep, str,   safe) {

    if (!length(pat) || !length(str))
        return
    safe = str
    gsub(pat, rep, safe)
    return safe

}

#
# gsubs() - like gsub() but literal non-regex
#
#   Example:
#      s = "****field****"
#      print gsubs("*", "-", s)  #=> ----field----
#
#   Credit: Adapted from glsub() by Daniel Mills https://github.com/e36freak/awk-libs
#
function gsubs(pat, rep, str,    out, len, i, a, l) {

    if (!length(str)) 
        return 

    # get the length of pat to know how much of the string to remove
    # if empty return original str
    if (!(len = length(pat))) 
        return str

    # loop while 'pat' is in 'str'
    while (i = index(str, pat)) {
        # append everything up to the search pattern, and the replacement, to out
        out = out substr(str, 1, i - 1) rep
        # remove everything up to and including the first instance of pat from str
        str = substr(str, i + len)
    }

    # append whatever is left in str to out and return
    return out str
}

#
# splitn() - split input 'fp' along \n
#
#  Designed to replace typical code sequence
#      fp = readfile("test.txt")
#      c = split(fp, a, "\n")
#      for(i = 1; i <= c; i++) {
#        if(length(a[i]) > 0) 
#          print "a[" i "] = " a[i]
#      }
#  With
#      for(i = 1; i <= splitn("test.txt", a, i); i++) 
#        print "a[" i "] = " a[i]
#
#   . If input is the name of a file, it will readfile() it; otherwise use literal text as given 
#   . Automatically removes blank lines from input
#   . Allows for embedding in for-loops 
#
#   Notes
#
#   . The 'counter' ('i' in the example) is assumed initialized to 1 in the for-loop. If
#     different, pass a start value in the fourth argument eg.
#             for(i = 5; i <= splitn("test.txt", a, i, 5); i++)
#   . If not in a for-loop the counter is not needed eg.
#             c = splitn("test.txt", a)
#   . 'fp' can be a filename, or a string of literal text. If 'fp' does not contain a '\n'
#     it will search for a filename of that name; if none found it will treat as a
#     literal string. If it means to be a string, for safety add a '\n' to end. eg.
#             for(i = 5; i <= splitn(ReadDB(key) "\n", a, i); i++)
#       
#
function splitn(fp, arrSP, counter, start,    c,j,dSP,i,save_sorted) {

    if ( empty(start) ) 
        start = 1 
    if (counter > start) 
        return length(arrSP) 

    if ("sorted_in" in PROCINFO) 
        save_sorted = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = "@ind_num_asc"

    if (fp !~ /\n/) {
        if (checkexists(fp))      # If the string doesn't contain a \n check if a filename exists
            fp = readfile(fp)     # with that name. If not assume it's a literal string. This is a bug
    }                             # in case a filename exists with the same name as the literal string.

    delete arrSP
    c = split(fp, dSP, "\n")
    for (j in dSP) {
        if (empty(dSP[j])) 
            delete dSP[j]
    }
    i = 1
    for (j in dSP)  {
        arrSP[i] = dSP[j]
        i++
    }

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

    return length(dSP)

}

#
# wc() - wc a file (number of lines)
#
#    . to wc a string splitc(s, "\n")
#    . to wc an array length(a)
#
function wc(fp,  a) {
  if(checkexists(fp))
    return splitn(fp,a)
  return 0
}

#
# sortstring() - given a string, return the characters in a sorted_in 'order'
#
#   Example
#      sortstring("GteWdAa", "@ind_str_asc") => AGWadet
#
#   . for other 'order' sort options 
#       https://www.gnu.org/software/gawk/manual/html_node/Controlling-Scanning.html
#
function sortstring(s,order,  a,j,b,save_sorted) {

    if("sorted_in" in PROCINFO) 
        save_sorted = PROCINFO["sorted_in"]
    PROCINFO["sorted_in"] = order

    split(s, a, "")
    asort(a)
    for (j in a)
        b = b a[j]

    if (save_sorted)
        PROCINFO["sorted_in"] = save_sorted
    else
        PROCINFO["sorted_in"] = ""

    return strip(b)
}

# 
# comparestr() - compare two strings letter by letter. return 1 if strings are the same
# 
#   . normally done with "==" or "~" but this is useful in some cases such as
#       when strings contain ' and/or " and processing via command-line
# 
function comparestr(s1,s2,   a1,a2,c1,c2,i) {

    c1 = split(s1, a1, "")
    c2 = split(s2, a2, "")
    if(c1 != c2) return 0

    for(i = 1; i <= c1; i++)
      if(a1[i] != a2[i]) return 0

    return 1         

}


#
# Convert \n to "_newline_" - useful for logging purposes
#
function hidenewline(s) {                  
    gsub(/\n/, "_newline_", s)
    return s             
}


# [[ __________________________________________________________________________________ ]]
# [[ ____________________ Wikipedia markup ____________________________________________ ]]
# [[ __________________________________________________________________________________ ]]

#
# stripwikimarkup() - strip wiki markup 
#
#   Example:
#      "George Henry is a [[lawyer<!--no-->]]<ref name=wp>{{fact|Is {{lang|en|[[true]]}}}}<!--yes-->. See [http://wikipedia.org]</ref> from [[Charlesville (Virginia)|Charlesville Virginia]]<ref>See note.</ref> and holds two [[degree]]s in philosophy."
#      "George Henry is a lawyer from Charlesville Virginia and holds two degrees in philosophy."
#
#   . a possibly better soltion:
#       http://stackoverflow.com/questions/1625162/get-text-content-from-mediawiki-page-via-api/21844127#21844127
#
function stripwikimarkup(str,  safe) {
    safe = stripwikicomments(str)
    safe = stripwikitemplates(safe)
    safe = stripwikirefs(safe)
    safe = stripwikilinks(safe)
    return strip(safe)
}


#
# stripwikicomments() - remove wikicomments <!-- comment -->
#
#   Example:
#      "George Henry is a [[lawyer]]<!-- source? --> from [[Charlesville (Virginia)|Charlesville <!-- west? --> Virginia]]"
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#
#   . adapted from WaybackMedic Nim version April 2018
#
function stripwikicomments(str,   space,s,c,i,sand,field,sep,build,re) {

    s = str

    space = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"

    re = "[<]" space "[!]" space "[-][-]"
    gsub(re, "stripwiki-AA-WaybackMedic", s)
    re = "[-][-]" space "[>]"
    gsub(re, "stripwiki-ZZ-WaybackMedic", s)

    s = gsubs("<", "stripwiki-FF-WaybacKmedic", s)
    s = gsubs(">", "stripwiki-GG-WaybacKmedic", s)
    s = gsubs("stripwiki-AA-WaybackMedic", "<!--", s)
    s = gsubs("stripwiki-ZZ-WaybackMedic", "-->", s)

    re = "[<]" space "[!]" space "[-][-][^>]*[>]"
    c = patsplit(s, field, re, sep)

    if (c == 0) {                                         # no comments
        s = gsubs("stripwiki-FF-WaybacKmedic", "<", s)
        s = gsubs("stripwiki-GG-WaybacKmedic", ">", s)
        return s
    }

    if ( length(sep) == 1 && empty(sep[0]))             # whole string is a comment
        return ""

    for (i in sep)
        build = build sep[i]

    if (!empty(build))
        sand = build
    else
        sand = s

    sand = gsubs("stripwiki-FF-WaybacKmedic", "<", sand)
    sand = gsubs("stripwiki-GG-WaybacKmedic", ">", sand)

    return sand
}

#
# stripnowiki() - remove <nowiki>...</nowiki>
#
#   Example:
#      "George ''Henrys''<nowiki>'</nowiki> is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#      "George Henrys is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]]"
#
#   . adapted from stripwikicomments() Jan 2019
#
function stripnowiki(str,   space,s,c,i,sand,field,sep,build,re,ic) {

    s = str

    ic = IGNORECASE
    IGNORECASE = 1

    space = "[\n\r\t]*[ ]*[\n\r\t]*[ ]*[\n\r\t]*"

    re = "[<]" space "nowiki" space "[>]"
    gsub(re, "stripnowiki-AA-WaybackMedic", s)
    re = "[<]" space "/" space "nowiki" space "[>]"
    gsub(re, "stripnowiki-ZZ-WaybackMedic", s)

    s = gsubs("<", "stripnowiki-FF-WaybacKmedic", s)
    s = gsubs(">", "stripnowiki-GG-WaybacKmedic", s)
    s = gsubs("stripnowiki-AA-WaybackMedic", "<nowiki>", s)
    s = gsubs("stripnowiki-ZZ-WaybackMedic", "</nowiki>", s)

    re = "[<]nowiki[>][^<]*[<][/]nowiki[>]"
    c = patsplit(s, field, re, sep)

    if (c == 0) {                                         # no comments
        s = gsubs("stripnowiki-FF-WaybacKmedic", "<", s)
        s = gsubs("stripnowiki-GG-WaybacKmedic", ">", s)
        IGNORECASE = ic
        return s
    }

    if ( length(sep) == 1 && empty(sep[0])) {             # whole string is a comment
        IGNORECASE = ic
        return ""
    }

    for (i in sep)
        build = build sep[i]

    if (!empty(build))
        sand = build
    else
        sand = s

    sand = gsubs("stripnowiki-FF-WaybacKmedic", "<", sand)
    sand = gsubs("stripnowiki-GG-WaybacKmedic", ">", sand)

    IGNORECASE = ic
    return sand

}

#
# stripnowikicom () - strip <nowiki> and <!-- comments -->
#
function stripnowikicom(str) {
  return stripnowiki(stripwikicomments(str))
}


#
# stripwikirefs() - strip wiki markup <ref></ref>
#
#   Example:
#      "George Henry is a [[lawyer]]<ref name=wp>Is [[true]]. See [http://wikipedia.org]</ref> from [[Charlesville (Virginia)|Charlesville Virginia]]<ref>See note.</ref> and holds two [[degree]]s in philosophy."
#      "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]] and holds two [[degree]]s in philosophy."
#
function stripwikirefs(str, a,c,i,out,sep) {
    c =  patsplit(str, a, /<ref[^>]*>[^>]*>/, sep)
    out = sep[0]
    while (i++ < c) {
        out = out sep[i] 
    }
    return out
}

#
# stripwikitemplates() - strip wiki markup {{templates}}
#
#   Example:
#      "George Henry is a [[lawyer]]{{fact|{{name}}}} {from} [[Charlesville (Virginia)|Charlesville Virginia]]"
#      "George Henry is a lawyer {from} Charlesville Virginia"
#
function stripwikitemplates(str,  a,c,i,out,sep) {

    c =  patsplit(str, a, /[{][{][^}]*[}][}]/, sep)
    out = sep[0]
    while (i++ < c) 
        out = out sep[i] 
    gsub(/{{|}}/,"",out)
    return out
}

#
# stripwikilinks() - strip wiki markup [[wikilinks]]
#
#    Example:
#       "George Henry is a [[lawyer]] from [[Charlesville (Virginia)|Charlesville Virginia]] and holds two [[degree]]s in philosophy."
#       "George Henry is a lawyer from Charlesville Virginia and holds two degrees in philosophy."
#
function stripwikilinks(str,  a,b,c,i,ai,out,sep) {

    c = patsplit(str, a, /[[][[][^\]]*[]][]]/, sep)
    out = sep[0]
    while (i++ < c) {
        ai = gensub(/[[]|[]]/, "", "g", a[i])
        if (split(ai, b, "|") > 1)
            ai = b[2]
        out = out ai sep[i] 
    }
    return out
}


# [[ __________________________________________________________________________________ ]]
# [[ ____________________ Numbers _____________________________________________________ ]]
# [[ __________________________________________________________________________________ ]]

#
# randomnumber() - return a random number between 1 to max
#
#  . robust awk random number generator works at nano-second speed and parallel simultaneous invocation
#  . requires global variable _cliff_seed ie:
#        _cliff_seed = "0.00" splitx(sprintf("%f", systime() * 0.000001), ".", 2)
#    should be defined one-time only eg. in the BEGIN{} section
#
function randomnumber(max, i,randomArr) {

  # missing _cliff_seed fallback to less-robust rand() method
    if (empty(_cliff_seed)) 
        return randomnumber1(max)

  # create array of 1000 random numbers made by cliff_rand() method seeded by systime()
    for (i = 0; i <= 1002; i++) 
        randomArr[i] = randomnumber2(max)

  # choose one at random using rand() method seeded by PROCINFO["pid"]
    return randomArr[randomnumber1(1000)] 

}
function randomnumber1(max) {
    srand(PROCINFO["pid"])
    return int( rand() * max)
}
function randomnumber2(max) {
    int( cliff_rand() * max)  # bypass first call
    return int( cliff_rand() * max)
}
#
#  cliff_rand()
#
#  Credit: https://www.gnu.org/software/gawk/manual/html_node/Cliff-Random-Function.html
#
function cliff_rand() {
    _cliff_seed = (100 * log(_cliff_seed)) % 1
    if (_cliff_seed < 0)
        _cliff_seed = - _cliff_seed
    return _cliff_seed
}

#
# isanumber() - return 1 if str is a positive whole number or 0
#
#   Example:
#      "1234" == 1 / "0fr123" == 0 / 1.1 == 0 / -1 == 0 / 0 == 1
#
function isanumber(str,    safe,i) {

    if (length(str) == 0) return 0
    safe = str
    while ( i++ < length(safe) ) {
        if ( substr(safe,i,1) !~ /[0-9]/ )          
            return 0
    }
    return 1   
}          

#
# isafraction() - return 1 if str is a positive whole or fractional number
#
#   Examples:
#      "1234" == 1 | "0fr123" == 0 | 1.1 == 1 | -1 == 0 | 0 == 1
#
function isafraction(str,    safe) {
    if(length(str) == 0) return 0
    safe = str
    sub(/[.]/,"",safe)
    return isanumber(safe)
}


# [[ __________________________________________________________________________________ ]]
# [[ ______________________ URL Encode/Decode _________________________________________ ]]
# [[ __________________________________________________________________________________ ]]


#
# urlElement - given a URL, return a sub-portion (scheme, netloc, path, query, fragment)
#
#  In the URL "https://www.cwi.nl:80/nl?dooda/guido&path.htm#section"
#   scheme = https
#   netloc = www.cwi.nl:80
#   path = /nl
#   query = dooda/guido&path.htm
#   fragment = section        
#  
#  Example: 
#     uriElement("https://www.cwi.nl:80/nl?", "path") returns "/nl"
#
#   . URLs have many edge cases. This function works for well-formed URLs.
#   . If a robust solution is needed:
#       "python3 -c \"from urllib.parse import urlsplit; import sys; o = urlsplit(sys.argv[1]); print(o." element ")\" " shquote(url)
#   . returns full url on error
#
function urlElement(url,element,   a,scheme,netloc,tail,b,fragment,query,path,c) {

  if(url ~ /^\/\//)        # Protocol-relative - assume http
    url = "http:" url

  split(url, a, /\//)

  scheme = substr(a[1], 0, index(a[1], ":") -1)
  netloc = a[3]

  tail = subs(scheme "://" netloc, "", url)

  c = splits(tail, b, "#")
  if(!empty(b[c]))
    fragment = b[c]

  c = splits(tail, b, "?")
  if(c == 2) {
    if(!empty(b[2])) {
      query = b[2]
      if(!empty(fragment))
        query = subs("#" fragment, "", query)
    }
  }
  else if(c == 3) {
    if(!empty(b[2]) && !empty(b[3])) {
      query = b[2] "?" b[3]
      if(!empty(fragment))
        query = subs("#" fragment, "", query)
    }
  }

  path = tail
  if(!empty(fragment))
    path = subs("#" fragment, "", path)
  if(!empty(query))
    path = subs("?" query, "", path)
    
  if(element == "scheme")
    return scheme
  else if(element == "netloc")
    return netloc
  else if(element == "path")
    return path
  else if(element == "query")
    return query
  else if(element == "fragment")
    return fragment

}



#
# urldecodeawk - decode a urlencoded string
# 
#  Requirement: gawk -b
#  Credit: Rosetta Stone January 2017.
#          "literal" added by GreenC 2020
#              
function urldecodeawk(str,  safe,len,L,M,R,i,literal,debug) {

    debug = 0

    safe = str
    len = length(safe)
    for (i = 1; i <= len; i++) {
        literal = 0
        if ( substr(safe,i,1) == "%") {

                                           # Bug in data, need at least two valid chars after a %, otherwise return as literal % 
                                           # awk -ilibrary 'BEGIN{print urldecodeawk("test%2")}' => "test%2"
                                           # awk -ilibrary 'BEGIN{print urldecodeawk("test%#i")}' => "test%#i"
            if(empty(substr(safe,i+1,1)) || empty(substr(safe,i+2,1)))   
              literal = 1
            if(substr(safe,i+1,1) !~ /[0-9a-zA-Z]/ || substr(safe,i+2,1) !~ /[0-9a-zA-Z]/)
              literal = 1

            L = substr(safe,1,i-1)         # chars to left of "%"

            if(debug) print "L = " L

            if(!literal)
              M = substr(safe,i+1,2)       # 2 chars to right of "%"
            else
              M = ""

            if(debug) print "M = " M

            if(!literal)
              R = substr(safe,i+3)         # chars to right of "%xx"
            else {
              if(len - 1 == i)
                R = substr(safe, i + 1, 1)
              else
                R = ""
            }

            if(debug) print "R = " R

            if(!literal)
              safe = sprintf("%s%c%s",L,hex2dec(M),R)
            else
              safe = sprintf("%s", L) "%" sprintf("%s", R)
        }
    }
    return safe
}
function hex2dec(s,  num) {
    num = index("0123456789ABCDEF",toupper(substr(s,length(s)))) - 1
    sub(/.$/,"",s)
    return num + (length(s) ? 16*hex2dec(s) : 0)
}

#
# urlencodeawk - urlencode a string
#
#  . if optional 'class' is "url" treat 'str' with best-practice URL encoding
#     see https://perishablepress.com/stop-using-unsafe-characters-in-urls/
#     Only do this when encoding a full URL not portion of a URL
#  . if 'class' is "rawphp" attempt to match behavior of PhP rawurlencode()
#  . otherwise encode everything except 0-9A-Za-z
#
#  Requirement: gawk -b
#  Credit: Rosetta Code May 2015
#          GreenC
#
function urlencodeawk(str,class,  c, len, res, i, ord, re) {

    if (class == "url")
        re = "[$\\-_.~+!*'(),,;/?:@=&0-9A-Za-z]"
    else if (class == "rawphp")
        re = "[\\-_.~0-9A-Za-z]"
    else
        re = "[0-9A-Za-z]"

    for (i = 0; i <= 255; i++)
        ord[sprintf("%c", i)] = i
    len = length(str)
    res = ""
    for (i = 1; i <= len; i++) {
        c = substr(str, i, 1)
        if (c ~ re)                # don't encode 
            res = res c
        else
            res = res "%" sprintf("%02X", ord[c])
    }
    return res
}

#
# urlencodelimited() - URL-encode limited set of characters needed for Wikipedia templates
#
#   . https://en.wikipedia.org/wiki/Template:Cite_web#URL
#
function urlencodelimited(url,  safe) {

    safe = url
    gsub(/[ ]/, "%20", safe)            
    gsub(/["]/, "%22", safe)            
    gsub(/[']/, "%27", safe)                
    gsub(/[<]/, "%3C", safe)
    gsub(/[>]/, "%3E", safe)
    gsub(/[[]/, "%5B", safe)
    gsub(/[]]/, "%5D", safe)
    gsub(/[{]/, "%7B", safe)
    gsub(/[}]/, "%7D", safe)
    gsub(/[|]/, "%7C", safe)
    return safe
}  


