#!/usr/local/bin/awk -bE

#
# allpages - list every page title in one or more namespaces of a MediaWiki wiki
#
#   allpages -l en -z wikipedia.org -n "0 6" -o titles.txt
#
# Reads go through wikiget -U, which carries OAuth credentials and the Toolforge proxy.
# That matters for more than politeness: the OAuth account holds apihighlimits, so a
# request scans 5000 rows instead of 500, and wikiget absorbs maxlag internally. Going
# direct with http2var() hits the public Varnish tier and gets throttled on a crawl of
# millions of titles.
#
# Buckets:  P[]   - command-line parameters (every switch below)
#           G[]   - general config, not settable from the command line
#           Exe[] - executable registry, inherited from syscfg.awk via @include library
#
# Framework globals (bare by requirement): BotName, Agent, Engine, and getopt's
# Optind / Opterr / Optarg / C / opts
#

BEGIN { # Defaults

  _defaults = "contact   = User:MY_NAME \
               emailfp   = /path/to/secrets/myname.email \
               version   = 2.0 \
               copyright = 2026"

  asplit(G, _defaults, "[ ]*[=][ ]*", "[ ]{9,}")
  BotName = "allpages"
  Engine = 3

  # Agent string format non-compliance could result in 429 (too many requests) rejections by WMF API
  # readfile() returns "" if 'emailfp' is not set up; checkargs() refuses to run in that
  # state, so no request is ever made with an incomplete Agent
  Agent = BotName "-" G["version"] "-" G["copyright"] " (" G["contact"] "; mailto:" strip(readfile(G["emailfp"])) ")"

  # Command-line switches - defaults. See usage()
  P["lang"]       = "en"
  P["project"]    = "wikipedia.org"
  P["namespaces"] = "0"
  P["parsemode"]  = "string"
  P["outfile"]    = ""                  # empty = stdout
  P["logfile"]    = "all-pages.log"     # relative, so $CWD
  P["caller"]     = ""                  # empty = invoked directly, not by another tool

  # Not switches - intrinsic to what the tool does, not to a deployment
  G["aplimit"]      = "max"             # rows scanned per request. 5000 with apihighlimits (500 anon)
  G["filterredir"]  = "nonredirects"    # applied AFTER the scan, so a request returns far fewer
  G["maxlag"]       = 5                 # seconds of replication lag the API may tolerate
  G["retries"]      = 3                 # getjsonin() attempts. Keep low - wikiget retries internally
  G["blockretries"] = 4                 # getallpages() attempts per continuation block

}

@include "library"
@include "json"

BEGIN { # Parse arguments and run

  Optind = Opterr = 1
  while ((C = getopt(ARGC, ARGV, "l:z:n:m:o:g:c:h")) != -1) {
    opts++
    if (C == "l")                 #  -l <lang>       Language code eg. "en"
      P["lang"] = optval(Optarg, "-l")
    else if (C == "z")            #  -z <project>    Project domain eg. "wikipedia.org"
      P["project"] = optval(Optarg, "-z")
    else if (C == "n")            #  -n <ns ...>     Namespace numbers, space separated eg. "0 6"
      P["namespaces"] = optval(Optarg, "-n")
    else if (C == "m")            #  -m <mode>       Parse mode: "string" or "json"
      P["parsemode"] = optval(Optarg, "-m")
    else if (C == "o")            #  -o <file>       Output file. Default stdout
      P["outfile"] = optval(Optarg, "-o")
    else if (C == "g")            #  -g <file>       Log file. Default $CWD/all-pages.log
      P["logfile"] = optval(Optarg, "-g")
    else if (C == "c")            #  -c <caller>     Name of the invoking tool, for logs and NOTIFY mail
      P["caller"] = optval(Optarg, "-c")
    else if (C == "h") {          #  -h              Usage
      usage()
      exit 0
    }
    else {
      usage()
      exit 2
    }
  }

  if (opts == 0) {
    usage()
    exit 2
  }

  if (! checkargs())
    exit 2

  exit (allPages() ? 0 : 1)

}

# -----------------------------------------------------------

#
# usage() - to stdout, so "allpages.awk -h | less" behaves
#
function usage() {

  print BotName ".awk - list every page title in one or more namespaces of a MediaWiki wiki"
  print ""
  print "Usage: " BotName ".awk [-l lang] [-z project] [-n \"ns ...\"] [-m mode] [-o file] [-g file] [-c caller]"
  print ""
  print "  -l <lang>     Language code. Default: " P["lang"]
  print "  -z <project>  Project domain. Default: " P["project"]
  print "                The wiki is <lang>.<project> eg. en.wikipedia.org"
  print "  -n <ns ...>   Namespace numbers, space separated. Default: \"" P["namespaces"] "\""
  print "                One full crawl per namespace - the API takes only one at a time."
  print "  -m <mode>     Parse mode, \"string\" or \"json\". Default: " P["parsemode"]
  print "                \"string\" reads the fields out of the raw response and is ~300x"
  print "                faster; \"json\" builds a parse tree. Identical output."
  print "  -o <file>     Output file, one title per line. Default: stdout"
  print "                Refuses to run if the file exists, rather than appending to it."
  print "  -g <file>     Log file for API errors. Default: $CWD/" P["logfile"]
  print "  -c <caller>   Name of the invoking tool. Tags log lines and NOTIFY mail so a"
  print "                failure can be traced to whoever's run it broke. Default: none"
  print "  -h            This help"
  print ""
  print "Redirects are excluded (apfilterredir=" G["filterredir"] ")."
  print ""
  print "Exit: 0 ok, 1 crawl failed, 2 bad arguments"
  print ""
  print "Examples:"
  print "  " BotName ".awk                                  # en.wikipedia.org articles to stdout"
  print "  " BotName ".awk -n \"0 6\" -o titles.txt           # articles and files"
  print "  " BotName ".awk -l de -o de-titles.txt           # de.wikipedia.org"
  print "  " BotName ".awk -l commons -z wikimedia.org -n 6 # Commons files"
  print "  " BotName ".awk -c mybot -o all-pages             # invoked by another tool"

}

#
# optval() - a switch's value, or bail
#
#  Local stand-in for botwiki.awk's verifyval(), which this program does not include,
#  and which exits 0 on a bad argument - wrong for something other scripts call.
#
function optval(val, sw) {

  if (empty(val) || substr(val, 1, 1) == "-") {
    stdErr(BotName ".awk: " sw " requires a value")
    exit 2
  }

  return val
}

#
# checkargs() - validate what came in off the command line
#
function checkargs(   i, n, ns) {

  # Install check rather than an argument check, but it lives here so -h works on an
  # unconfigured install. Must stay ahead of checkns(), which makes a real API request.
  # Create a file containing your email address (a single line) and link it in 'emailfp' at the top
  if (! exists2(G["emailfp"])) {
    stdErr(BotName ".awk: unable to find email file (" G["emailfp"] "). Create a file anywhere on your system containing your email address (a single line). Link that /path/to/filename into 'emailfp' at the top of " BotName ".awk - required for WMF API authentication. Set 'contact' to your wiki username.")
    return 0
  }

  if (empty(P["lang"]) || empty(P["project"])) {
    stdErr(BotName ".awk: -l and -z cannot be empty")
    return 0
  }

  if (P["parsemode"] != "string" && P["parsemode"] != "json") {
    stdErr(BotName ".awk: -m must be \"string\" or \"json\", not \"" P["parsemode"] "\"")
    return 0
  }

  # A newline here would break the one-line log format and the mail subject
  if (! empty(P["caller"]) && P["caller"] !~ /^[A-Za-z0-9 _.:\/-]+$/) {
    stdErr(BotName ".awk: -c takes a tool name, letters digits and _ . : / - only")
    return 0
  }

  n = split(P["namespaces"], ns, /[ ,]+/)
  if (n == 0) {
    stdErr(BotName ".awk: -n needs at least one namespace number")
    return 0
  }
  for (i = 1; i <= n; i++) {
    if (ns[i] !~ /^[0-9]+$/) {
      stdErr(BotName ".awk: -n takes namespace numbers, not \"" ns[i] "\"")
      return 0
    }
  }

  G["fqdn"] = P["lang"] "." P["project"]
  G["apiurl"] = "https://" G["fqdn"] "/w/api.php?"

  # wikiget appends ".org" itself, so hand it the project without one
  G["wgproject"] = P["project"]
  sub(/\.org$/, "", G["wgproject"])

  # Namespaces differ per wiki - 2300 is a namespace on some, not on en.wikipedia.org.
  # Without this the API rejects it mid-crawl, which is a fatal abort and a NOTIFY
  # email for what is really a typo. Costs one siteinfo request at startup.
  if (! checkns(ns, n))
    return 0

  # Appending to an existing list silently corrupts it, and a crawl is too long to redo
  if (! empty(P["outfile"]) && checkexists(P["outfile"])) {
    stdErr(BotName ".awk: output file exists: " P["outfile"])
    stdErr("Delete or rename and try again")
    return 0
  }

  # An unwritable path is a gawk fatal at the first write, which would surface hours in
  # and with an exit status indistinguishable from a bad argument. Find out now. Left
  # last so a failure earlier in checkargs() does not leave an empty file behind.
  if (! empty(P["outfile"])) {
    PROCINFO["NONFATAL"] = 1
    ERRNO = ""
    printf "" > P["outfile"]
    if (ERRNO != "") {
      stdErr(BotName ".awk: cannot write output file " P["outfile"] " - " ERRNO)
      delete PROCINFO["NONFATAL"]
      return 0
    }
    close(P["outfile"])
    delete PROCINFO["NONFATAL"]
  }

  return 1
}

#
# checkns() - every requested namespace exists on this wiki
#
#  Doubles as the first reachability check: a bad -l/-z shows up here as an
#  unreadable namespace list rather than as a failed crawl.
#
function checkns(ns, n,   jsonin, valid, i, arr, c, url) {

  url = G["apiurl"] "action=query&meta=siteinfo&siprop=namespaces&format=json&formatversion=2"

  # Deliberately not getjsonin(): its failure path is a fatal abort plus a NOTIFY
  # email, which is the wrong response to a bad argument. wikiget retries internally.
  jsonin = sys2var(Exe["wikiget"] " -l " shquote(P["lang"]) " -z " shquote(G["wgproject"]) " -U " shquote(url))

  if (empty(jsonin) || apierror(jsonin, "json") != "OK") {
    stdErr(BotName ".awk: cannot reach the API at " G["fqdn"] " - check -l and -z")
    return 0
  }

  # "id" appears once per namespace; ids are numbers, so no JSON string decoding needed
  c = patsplit(jsonin, arr, /"id"[ ]*[:][ ]*-?[0-9]+/)
  for (i = 1; i <= c; i++) {
    sub(/^"id"[ ]*[:][ ]*/, "", arr[i])
    valid[arr[i] + 0] = 1
  }

  if (c == 0) {
    stdErr(BotName ".awk: no namespace list returned by " G["fqdn"])
    return 0
  }

  for (i = 1; i <= n; i++) {
    if (! (ns[i] + 0 in valid)) {
      stdErr(BotName ".awk: namespace " ns[i] " does not exist on " G["fqdn"])
      return 0
    }
  }

  return 1
}

# -----------------------------------------------------------

# ___ All pages

# adapted from wikiget.awk writes real-time instead of uniq - this saves memory
#
# MediaWiki API: Allpages
#  https://www.mediawiki.org/wiki/API:Allpages
#
function allPages(   i, n, ns, ok) {

  n = split(P["namespaces"], ns, /[ ,]+/)

  ok = 1
  for (i = 1; i <= n; i++) {
    if (! getallpages(ns[i]))
      ok = 0
  }

  return ok

}

#
# getallpages() - crawl one namespace, following apcontinue to the end
#
function getallpages(namespace,    url, base, jsonin, res, jsonout, continuecode, i, flag, snippet) {

        base = G["apiurl"] "action=query&list=allpages&aplimit=" G["aplimit"] "&apfilterredir=" G["filterredir"] "&apnamespace=" namespace "&format=json&formatversion=2&maxlag=" G["maxlag"]

        url = base

        jsonin = getjsonin(url)
        parseresponse(jsonin, res)
        continuecode = res["continue"]
        jsonout = res["titles"]

        if (! empty(jsonin)) {
          # Only write when the response actually carried page data
          if (! empty(jsonout))
            outwrite(jsonout)
        }
        else {
          # Only reached when the request itself failed (truly empty body)
          logwrite("API error in getallpages (1): Response=[EMPTY STRING] for " url)
          return 0
        }

        while (continuecode != "-1-1!!-1-1") {

            url = base "&apcontinue=" urlencodeawk(continuecode, "rawphp") "&continue=" urlencodeawk("-||")

            flag = 0
            for (i = 1; i <= G["blockretries"]; i++) {
              if (flag)
                break
              jsonin = getjsonin(url)
              parseresponse(jsonin, res)
              continuecode = res["continue"]
              jsonout = res["titles"]
              if (! empty(jsonin)) {
                # A block can legitimately hold no titles - still a success, move to the next continuecode
                if (! empty(jsonout))
                  outwrite(jsonout)
                flag = 1
              }
            }

            if (flag == 0) {
              snippet = empty(jsonin) ? "[EMPTY STRING]" : substr(jsonin, 1, 100)
              logwrite("API error in getallpages (Loop): Response=" snippet " for " url)
              return 0
            }
        }

        return 1
}

#
# Get jsonin with max lag/error retries
#
#  Routes the read through wikiget -U: OAuth authentication plus the Toolforge proxy,
#  and wikiget handles maxlag/retry/pause loops of its own. The retries below are a
#  second line of defense for what wikiget gives up on.
#
function getjsonin(url,   i, jsonin, pre, res, retries) {

            retries = G["retries"]

            pre = "API error: "

            for (i = 1; i <= retries; i++) {

              jsonin = sys2var(Exe["wikiget"] " -l " shquote(P["lang"]) " -z " shquote(G["wgproject"]) " -U " shquote(url))
              res = apierror(jsonin, "json")

              if (res ~ "maxlag") {
                if (i == retries) {
                  logwrite(pre jsonin)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName ".awk " context() " Maxlag timeout in getjsonin() after " retries " tries aborting script", "")
                  exit 1
                }
                sleep(3, "unix")
              }
              else if (res ~ "error") {
                if (i == retries) {
                  logwrite(pre jsonin)
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName ".awk " context() " Error in getjsonin() after " retries " tries aborting script", "")
                  exit 1
                }
                sleep(10, "unix")
              }
              else if (res ~ "empty") {
                if (i == retries) {
                  logwrite(pre " Received empty response")
                  email(Exe["from_email"], Exe["to_email"], "NOTIFY: " BotName ".awk " context() " Empty response in getjsonin() after " retries " tries aborting script", "")
                  exit 1
                }
                sleep(10, "unix")
              }
              else if (res ~ "OK")
                break
            }

            return jsonin

}

#
# Basic check of API results for error
#
function apierror(input, type,   code) {

        if (length(input) < 5)
            return "empty"

        if (type == "json") {
            if (match(input, /"error"[:]{"code"[:]"[^"]*","info"[:]"[^"]*"/, code) > 0) {
                if (input ~ "maxlag")
                  return "maxlag"
                else
                  return "error"
            }
            else
              return "OK"
        }
}

#
# parseresponse() - pull the continue code and the titles out of one API response
#
#  The single logic break between P["parsemode"] "json" and "string". Fills:
#     res["continue"] - apcontinue value, or the "-1-1!!-1-1" sentinel when absent
#     res["titles"]   - the response's titles, "\n" separated, API order preserved
#
#  Both modes must return identical values for the same input. When re-checking that,
#  the corpus must include titles starting with " and ' - an alphabetic-only sample
#  passes even against a parser that truncates at an escaped quote.
#
function parseresponse(jsonin, res,    jsona) {

        delete res

        if (P["parsemode"] == "string") {
          res["continue"] = getcontinue_str(jsonin, "apcontinue")
          res["titles"] = json2var_str(jsonin)
        }
        else {
          parsejson(jsonin, jsona)
          res["continue"] = getcontinue(jsona, "apcontinue")
          res["titles"] = json2var(jsona)
        }
}

# -----------------------------------------------------------
# parsemode "string" - read the fields straight out of the raw response
# -----------------------------------------------------------

#
# jsonunesc() - decode a JSON string body
#
#  Escaped quotes are real in this data: one 5000-row response starting at "\"" held
#  475 of them, in titles like "\"&\"". \uXXXX and \\ were not observed with
#  formatversion=2 (non-ASCII comes back as literal UTF-8) but are decoded anyway
#  rather than trusted not to appear.
#
#  Single left-to-right pass: a naive sequence of gsub() calls mis-handles runs like
#  \\" where the backslash is itself escaped. Guarded by a fast path, since the large
#  majority of titles contain no backslash at all.
#
function jsonunesc(s,   out, i, c, n) {

        if (index(s, "\\") == 0)
          return s

        n = length(s)
        for (i = 1; i <= n; i++) {
          c = substr(s, i, 1)
          if (c == "\\" && i < n) {
            i++
            c = substr(s, i, 1)
            if (c == "n") c = "\n"
            else if (c == "t") c = "\t"
            else if (c == "r") c = "\r"
            else if (c == "b") c = "\b"
            else if (c == "f") c = "\f"
            else if (c == "u") {
              c = jsonu8(substr(s, i + 1, 4))
              i += 4
            }
            # \" \\ \/ and anything else stand for themselves
          }
          out = out c
        }

        return out
}

#
# jsonu8() - one \uXXXX escape (4 hex digits) to UTF-8
#
#  Surrogate pairs are not joined: a non-BMP character arrives as two escapes and each
#  half converts on its own. Not reachable with formatversion=2, which sends literal
#  UTF-8 - this exists so an unexpected escape degrades instead of corrupting silently.
#
function jsonu8(hex,   cp) {

        cp = strtonum("0x" hex)
        if (cp < 0x80)
          return sprintf("%c", cp)
        if (cp < 0x800)
          return sprintf("%c%c", 0xC0 + int(cp / 64), 0x80 + (cp % 64))

        return sprintf("%c%c%c", 0xE0 + int(cp / 4096), 0x80 + int((cp % 4096) / 64), 0x80 + (cp % 64))
}

#
# getcontinue_str() - apcontinue value, read from the raw response
#
function getcontinue_str(jsonin, method,   id) {

        if (match(jsonin, "\"" method "\"[ ]*[:][ ]*\"(\\\\.|[^\"\\\\])*\"")) {
          id = substr(jsonin, RSTART, RLENGTH)
          sub("^\"" method "\"[ ]*[:][ ]*\"", "", id)
          sub(/"$/, "", id)
          id = jsonunesc(id)
          if (!empty(id))
            return id
        }

        return "-1-1!!-1-1"     # return a string that isn't an actual page name (hopefully)
}

#
# json2var_str() - extract every "title" field, "\n" separated, in API order
#
#  patsplit() rather than a match()/substr() loop: awk's match() always starts at the
#  head of the string, so advancing by re-slicing the remainder re-copies the tail on
#  every hit - quadratic across the ~2000 titles in a full response. patsplit collects
#  all matches in one pass.
#
#  The value pattern is a proper JSON string body, (\\.|[^"\\])*, so a title containing
#  an escaped quote is not truncated at the escape.
#
function json2var_str(jsonin,   arr, n, i, t) {

        n = patsplit(jsonin, arr, /"title"[ ]*[:][ ]*"(\\.|[^"\\])*"/)

        for (i = 1; i <= n; i++) {
          t = arr[i]
          sub(/^"title"[ ]*[:][ ]*"/, "", t)
          sub(/"$/, "", t)
          arr[i] = jsonunesc(t)
        }

        return join(arr, 1, n, "\n")
}

# -----------------------------------------------------------
# parsemode "json" - query_json() parse tree
# -----------------------------------------------------------

#
# Parse a raw JSON response into jsona[] - once per response
#
#  query_json() costs ~6.8s on a full aplimit=max response. getcontinue() and json2var()
#  each used to parse the string themselves, doubling that on every request. Parse here
#  and hand both functions the array.
#
function parsejson(jsonin, jsona) {

        delete jsona
        if (query_json(jsonin, jsona) < 0)
          return 0
        return 1
}

#
# Parse continue code from a parsed JSON array
#
function getcontinue(jsona, method,    id) {

        id = jsona["continue", method]
        if (!empty(id))
          return id

        return "-1-1!!-1-1"     # return a string that isn't an actual page name (hopefully)
}

#
# json2var - given a parsed json array extract field "title" and convert to \n seperated string
#
function json2var(jsona,  arr) {

    splitja(jsona, arr, 3, "title")
    return join(arr, 1, length(arr), "\n")
}

# -----------------------------------------------------------

#
# Current time
#
function curtime() {
  return strftime("%Y%m%d-%H:%M:%S", systime(), 1)
}

#
# context() - who invoked this and against which wiki
#
#  With -c mybot   :  (via mybot en.wikipedia.org)
#  Without         :  (en.wikipedia.org)
#
#  Shared from ~/scripts, a failure otherwise says only that allpages broke, not which
#  tool's run it broke. Used in both the log line and the NOTIFY subject so a report
#  can be traced back to its owner.
#
#  Note this is local tracing only: wikiget performs the request and sends its own
#  User-Agent, so -c does not reach the WMF server logs.
#
function context() {

  if (empty(P["caller"]))
    return "(" G["fqdn"] ")"

  return "(via " P["caller"] " " G["fqdn"] ")"
}

#
# outwrite() - a block of titles to the output destination
#
function outwrite(msg) {

    if (empty(P["outfile"]))
      print msg
    else
      print msg >> P["outfile"]

}

#
# logwrite() - an error to the log, and to stderr so a caller sees it
#
function logwrite(msg) {

    # Non-fatal: an unwritable -g must not turn an error being reported into a crash.
    # stderr always gets it, so the message is never lost.
    PROCINFO["NONFATAL"] = 1
    ERRNO = ""
    print msg " " context() " ---- " curtime() >> P["logfile"]
    if (ERRNO != "")
      stdErr(BotName ".awk: cannot write log " P["logfile"] " - " ERRNO)
    else
      close(P["logfile"])
    delete PROCINFO["NONFATAL"]

    stdErr(BotName ".awk " context() ": " msg)

}
