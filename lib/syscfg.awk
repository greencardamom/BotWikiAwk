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

  # Default wget options (include lead/trail spaces)

  if(_e_(Wget_opts))
    Wget_opts = " --no-cookies --ignore-length --user-agent=\"" Agent "\" --no-check-certificate --tries=5 --timeout=120 --waitretry=60 --retry-connrefused "

  # --------------------------------------

  # Default email settings - for more info, see function email() in library.awk

    #   Exe["email_auth"]:
    #      This filename contains a single line with the SMTP server authentication credentials. For example:
    #        smtp://myprovider.net:26/novalidate-cert/user=joe@mydomain.com

  if(_e_(Exe["email_auth"]))
    Exe["email_auth"] = "/path/email_auth.txt"

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

