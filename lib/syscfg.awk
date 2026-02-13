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

BEGIN {

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

  # Unix tools

  if(_e_(Exe["awk"]))
    Exe["awk"] = ...
  if(_e_(Exe["cat"]))
    Exe["cat"] = ...
  if(_e_(Exe["chmod"]))
    Exe["chmod"] = ...
  if(_e_(Exe["comm"]))
    Exe["comm"] = ...
  if(_e_(Exe["cp"]))
    Exe["cp"] = ...
  if(_e_(Exe["curl"]))
    Exe["curl"] = ...
  if(_e_(Exe["date"]))
    Exe["date"] = ...
  if(_e_(Exe["diff"]))
    Exe["diff"] = ...
  if(_e_(Exe["grep"]))
    Exe["grep"] = ...
  if(_e_(Exe["gunzip"]))
    Exe["gunzip"] = ...
  if(_e_(Exe["gzip"]))
    Exe["gzip"] = ...
  if(_e_(Exe["head"]))
    Exe["head"] = ...
  if(_e_(Exe["ln"]))
    Exe["ln"] = ...
  if(_e_(Exe["ls"]))
    Exe["ls"] = ...
  if(_e_(Exe["mailx"]))
    Exe["mailx"] = ...
  if(_e_(Exe["mkdir"]))
    Exe["mkdir"] = ...
  if(_e_(Exe["mv"]))
    Exe["mv"] = ...
  if(_e_(Exe["nice"]))
    Exe["nice"] = ...
  if(_e_(Exe["printf"]))
    Exe["printf"] = ...
  if(_e_(Exe["ps"]))
    Exe["ps"] = ...
  if(_e_(Exe["rm"]))
    Exe["rm"] = ...
  if(_e_(Exe["sed"]))
    Exe["sed"] = ...
  if(_e_(Exe["shuf"]))
    Exe["shuf"] = ...
  if(_e_(Exe["sort"]))
    Exe["sort"] = ...
  if(_e_(Exe["split"]))
    Exe["split"] = ...
  if(_e_(Exe["tac"]))
    Exe["tac"] = ...
  if(_e_(Exe["tail"]))
    Exe["tail"] = ...
  if(_e_(Exe["timeout"]))
    Exe["timeout"] = ...
  if(_e_(Exe["uniq"]))
    Exe["uniq"] = ...
  if(_e_(Exe["wc"]))
    Exe["wc"] = ...
  if(_e_(Exe["wget"]))
    Exe["wget"] = ...
  if(_e_(Exe["zcat"]))
    Exe["zcat"] = ...

  # --------------------------------------

  # Third-party programs

  # GNU Parallel
  if(_e_(Exe["parallel"]))
    Exe["parallel"] = ...

  # File locking utility for Toolforge
  #  not needed if not using GridEngine
  if(_e_(Exe["zotkill"]))
    Exe["zotkill"] = "zotkill.pl"    

  # Lynx Version 2.8.9dev.16 (11 Jul 2017)
  #  or any version that supports SSL 
  if(_e_(Exe["lynx"]))
    Exe["lynx"] = ...

  # Color inline diffs. Requires wdiff
  #  sudo apt-get install wdiff
  if(_e_(Exe["coldiff"]))
    Exe["coldiff"] = "coldiff"
  if(_e_(Exe["wdiff"]))
    Exe["wdiff"] = ...

  # --------------------------------------

  # Bot executables global

  Exe["bug"] = "bug.awk"
  Exe["project"] = "project.awk"
  Exe["driver"] = "driver.awk"
  Exe["wikiget"] = "wikiget.awk"
  Exe["auniq"] = "auniq"

}

#
# _e_() - return 1 if string is 0-length
#
function _e_(s) {
    if (length(s) == 0)
        return 1
    return 0
}

