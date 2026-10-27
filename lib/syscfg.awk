#
# System configuration
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

@include "local.awk"   # your own functions - see lib/local.awk

BEGIN {

  # Local settings. This file holds the BotWikiAwk defaults and is the same for every install; the settings
  # for this machine and user live outside the repo in ~/.config/botwikiawk/settings (or the file named by
  # the environment variable BOTWIKIAWK_SETTINGS). setup.sh creates it and adds the Exe[] paths it finds.
  # One "key value" per line, # for comments:
  #
  #   Exe.wget       /usr/bin/wget            - Exe["wget"]
  #   Agent          MyBot/1.0 (User:MyName; me@example.com)
  #   StopButton     https://en.wikipedia.org/wiki/User:MyName/button
  #   bot.mybot.home /home/me/bots/mybot/     - Home for BotName "mybot" (see botwiki.awk)
  #   Exe.to_email   file:/home/me/.secrets/to.email   - the value is the first line of that file
  #   Exe.wikiget    ~/scripts/wikiget.awk    - a leading ~/ (also after file:) is your home directory
  #
  # Use file: for anything private, eg. email addresses, so the settings file itself holds none.
  # A key naming a global of the framework (Agent, Wget_opts, StopButton, UserPage, UserEmail, BotUser ..)
  # sets that global. Any other key is kept in BotWikiCfg[key]. A value the program has already set is not
  # changed, and the defaults below only fill what is still empty.

  _syscfg_load(_e_(ENVIRON["BOTWIKIAWK_SETTINGS"]) ? ENVIRON["HOME"] "/.config/botwikiawk/settings" : ENVIRON["BOTWIKIAWK_SETTINGS"])

  # Create a default user agent string. It is important the Agent not be blank or WMF API may block the bot. I
   # WMF bot policy requires two or three elements:
   #  1. Name version date of the bot
   #  2. Contact information
   #     Including a mailto:<email_address> can improve results
   #  An example would be "reftalk-2.5-2026 (User:GreenC mailto:myemail@example.com)"
   #  The below "Agent" is a site-wide default in case you forget to add a more specific Agent 
   #  at the top of your program. Create an "Agent = <agent>" variable at the top of your program file identifying the name
   #  of your program, username, site, library

  if(length(Agent) == 0)
    Agent = "MyProgram-version-date (User:MyName mailto:myemail@example.com)"

  # Default wget options (include lead/trail spaces)
  # including a --referer can improve results

  if(_e_(Wget_opts))
    Wget_opts=" --user-agent=\"" Agent "\" --referer=\"https://en.wikipedia.org/wiki/Main_Page\" --no-cookies --ignore-length --no-check-certificate --tries=3 --timeout=120 --waitretry=60 --retry-connrefused --retry-on-http-error=429 "

  # --------------------------------------

  # Default email settings - for more info, see function email() in library.awk

    #   Exe["email_auth"]:
    #      This filename contains a single-line with SMTP server authentication credentials. 
    #      For normal SMTP:
    #        smtp://user%40example.com:YOUR_PASSWORD@smtp.example.com:587
    #      For SMTPS:
    #        smtps://user%40example.com:YOUR_PASSWORD@smtp.example.com:465
    #      (Both methods are modern standards that use encryption. Check with your provider which method they prefer.)
    #      NOTE: Any special character in the email address or password (eg. "@") needs to be URL-encoded
    #            If it's not a normal letter or number and not (- _ . ~) it should be encoded.
    #            Encode with this tool: https://urlencoder.org 
    #      In this example the login is user@example.com, pass is "YOUR_PASSWORD"
    #        the SMTP server is "smtp.example.com" and port 465 (SMTPS) or 587 (SMTP Submission)

  if(_e_(Exe["email_auth"]))
    Exe["email_auth"] = "/path/to/email_auth.txt"

    # Default From: and To:

  if(_e_(Exe["from_email"]))
    Exe["from_email"] = "from@mydomain.com"
  if(_e_(Exe["to_email"]))
    Exe["to_email"] = "to@anotherdomain.net"

  # --------------------------------------

  # Unix tools. Optional ones (mailx, parallel, lynx, wdiff) default to "" = not installed; setup.sh adds
  # the path of each one it finds to the settings file

  if(_e_(Exe["awk"]))
    Exe["awk"] = "awk"
  if(_e_(Exe["cat"]))
    Exe["cat"] = "cat"
  if(_e_(Exe["chmod"]))
    Exe["chmod"] = "chmod"
  if(_e_(Exe["comm"]))
    Exe["comm"] = "comm"
  if(_e_(Exe["cp"]))
    Exe["cp"] = "cp"
  if(_e_(Exe["curl"]))
    Exe["curl"] = "curl"
  if(_e_(Exe["date"]))
    Exe["date"] = "date"
  if(_e_(Exe["diff"]))
    Exe["diff"] = "diff"
  if(_e_(Exe["grep"]))
    Exe["grep"] = "grep"
  if(_e_(Exe["gunzip"]))
    Exe["gunzip"] = "gunzip"
  if(_e_(Exe["gzip"]))
    Exe["gzip"] = "gzip"
  if(_e_(Exe["head"]))
    Exe["head"] = "head"
  if(_e_(Exe["ln"]))
    Exe["ln"] = "ln"
  if(_e_(Exe["ls"]))
    Exe["ls"] = "ls"
  if(_e_(Exe["mailx"]))
    Exe["mailx"] = ""
  if(_e_(Exe["mkdir"]))
    Exe["mkdir"] = "mkdir"
  if(_e_(Exe["mv"]))
    Exe["mv"] = "mv"
  if(_e_(Exe["nice"]))
    Exe["nice"] = "nice"
  if(_e_(Exe["printf"]))
    Exe["printf"] = "printf"
  if(_e_(Exe["ps"]))
    Exe["ps"] = "ps"
  if(_e_(Exe["rm"]))
    Exe["rm"] = "rm"
  if(_e_(Exe["sed"]))
    Exe["sed"] = "sed"
  if(_e_(Exe["shuf"]))
    Exe["shuf"] = "shuf"
  if(_e_(Exe["sort"]))
    Exe["sort"] = "sort"
  if(_e_(Exe["split"]))
    Exe["split"] = "split"
  if(_e_(Exe["tac"]))
    Exe["tac"] = "tac"
  if(_e_(Exe["tail"]))
    Exe["tail"] = "tail"
  if(_e_(Exe["timeout"]))
    Exe["timeout"] = "timeout"
  if(_e_(Exe["uniq"]))
    Exe["uniq"] = "uniq"
  if(_e_(Exe["wc"]))
    Exe["wc"] = "wc"
  if(_e_(Exe["wget"]))
    Exe["wget"] = "wget"
  if(_e_(Exe["zcat"]))
    Exe["zcat"] = "zcat"

  # --------------------------------------

  # Third-party programs

  # GNU Parallel
  if(_e_(Exe["parallel"]))
    Exe["parallel"] = ""

  # File locking utility for Toolforge
  #  not needed if not using GridEngine
  if(_e_(Exe["zotkill"]))
    Exe["zotkill"] = "zotkill.pl"    

  # Lynx Version 2.8.9dev.16 (11 Jul 2017)
  #  or any version that supports SSL 
  if(_e_(Exe["lynx"]))
    Exe["lynx"] = ""

  # Color inline diffs. Requires wdiff
  #  sudo apt-get install wdiff
  if(_e_(Exe["coldiff"]))
    Exe["coldiff"] = "coldiff"
  if(_e_(Exe["wdiff"]))
    Exe["wdiff"] = ""

  # --------------------------------------

  # Bot executables global
  #
  # GUARDED like the Unix tools above: set the default ONLY if the calling program has not
  # already assigned one before `@include "library.awk"`. Without the guard these five
  # assignments silently overwrite a caller's override, because syscfg's BEGIN runs AFTER the
  # caller's first BEGIN. That bit us 2026-09-18: noisbn's driver.awk set an absolute
  # Exe["wikiget"], this block reset it to the PATH-relative "wikiget.awk", PATH resolved to
  # BotWikiAwk's own unconfigured bin/wikiget.awk, and the run silently produced 0 articles.
  # Programs that do NOT pre-assign are unaffected - they still get these defaults.

  if(_e_(Exe["bug"]))
    Exe["bug"] = "bug.awk"
  if(_e_(Exe["project"]))
    Exe["project"] = "project.awk"
  if(_e_(Exe["driver"]))
    Exe["driver"] = "driver.awk"
  if(_e_(Exe["wikiget"]))
    Exe["wikiget"] = "wikiget.awk"
  if(_e_(Exe["auniq"]))
    Exe["auniq"] = "auniq"

}

#
# _syscfg_load() - read the local settings file (see the top of BEGIN). Self-contained, so it does not
#   depend on library.awk. A missing file is not an error; a missing file: file gives an empty value
#
function _syscfg_load(file,   line, k, v, vf, r) {
    while ((r = (getline line < file)) > 0) {
        sub(/^[ \t]+/, "", line)
        if (line == "" || line ~ /^#/ || !match(line, /[ \t]+/))
            continue
        k = substr(line, 1, RSTART - 1)
        v = substr(line, RSTART + RLENGTH)
        sub(/[ \t]+$/, "", v)
        if (v ~ /^~\//)
            v = ENVIRON["HOME"] substr(v, 2)
        if (v ~ /^file:/) {
            vf = substr(v, 6)
            if (vf ~ /^~\//)
                vf = ENVIRON["HOME"] substr(vf, 2)
            v = ""
            if ((getline v < vf) > 0)
                sub(/[ \t\r]+$/, "", v)
            else
                v = ""
            close(vf)
        }
        if (k ~ /^Exe[.]/) {
            if (_e_(Exe[substr(k, 5)]))
                Exe[substr(k, 5)] = v
        }
        else if (k ~ /^[A-Z][a-z]/ && k in SYMTAB && !isarray(SYMTAB[k])) {
            if (_e_(SYMTAB[k]))
                SYMTAB[k] = v
        }
        else
            BotWikiCfg[k] = v
    }
    if (r == 0)
        close(file)
}

#
# _e_() - return 1 if string is 0-length
#
function _e_(s) {
    if (length(s) == 0)
        return 1
    return 0
}

