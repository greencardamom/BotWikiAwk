#
# Archive URL tools 
#  ported from medic.nim to awk
#  May 2018
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

@include "library.awk"

BEGIN {

  PROCINFO["sorted_in"] = "@ind_num_asc"

  if (empty(_cliff_seed))  # for randomnumber() seed
    _cliff_seed = "0.00" splitx(sprintf("%f", systime() * 0.000001), ".", 2)

  # Wayback
  iahre = "([Cc][Ll][Aa][Ss][Ss][Ii][Cc][-][Ww][Ee][Bb]|[Ww][Ww][Ww][.][Ww][Ee][Bb]|[Ww][Ww][Ww]|[Ww][Ee][Bb][-][Bb][Ee][Tt][Aa]|[Rr][Ee][Pp][Ll][Aa][Yy][-][Ww][Ee][Bb]|[Rr][Ee][Pp][Ll][Aa][Yy]|[Ww][Ee][Bb][.][Ww][Aa][Yy][Bb][Aa][Cc][Kk]|[Ww][Ee][Bb]|[Ww][Aa][Yy][Bb][Aa][Cc][Kk])"
  iare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]" iahre "[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"

  # WebCite
  wcre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]([Ww][Ww][Ww][.])?[Ww][Ee][Bb][Cc][Ii][Tt][Aa][Tt][Ii][Oo][Nn][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"

  # Archive.is
  isre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.]([Tt][Oo][Dd][Aa][Yy]|[Ii][Ss]|[Ll][Ii]|[Ff][Oo])[:]?[8]?[04]?[48]?[30]?[/]"

  # Library of Congress
  locgovre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Ll][Oo][Cc][.][Gg][Oo][Vv][:]?[8]?[04]?[48]?[30]?"

  # Portugal
  portore = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[WwEe]?[WwBb]?[.]?[Aa][Rr][Qq][Uu][Ii][Vv][Oo][.][Pp][Tt][:]?[8]?[04]?[48]?[30]?"

  # Stanford
  stanfordre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ss][Ww][Aa][Pp][.][Ss][Tt][Aa][Nn][Ff][Oo][Rr][Dd][.][Ee][Dd][Uu][:]?[8]?[04]?[48]?[30]?"

  # Archive-It.org
  archiveitre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]" iahre "[.]?[Aa][Rr][Cc][Hh][Ii][Vv][Ee][-][Ii][Tt][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"

  # BibAlex
  bibalexre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ee]?[Bb]?[.]?([Pp][Ee][Tt][Aa][Bb][Oo][Xx]|[Aa][Rr][Cc][Hh][Ii][Vv][Ee])[.][Bb][Ii][Bb][Aa][Ll][Ee][Xx][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"

  # National Archives (UK)
  natarchivesukre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/]([Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee]|[Yy][Oo][Uu][Rr][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss])[.][Nn][Aa][Tt][Ii][Oo][Nn][Aa][Ll][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][.][Gg][Oo][Vv].[Uu][Kk][:]?[8]?[04]?[48]?[30]?"

  # Icelandic Archives
  vefsafnre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Aa][Yy][Bb][Aa][Cc][Kk][.][Vv][Ee][Ff][Ss][Aa][Ff][Nn][.][Ii][Ss][:]?[8]?[04]?[48]?[30]?"

  # Europa Archives (Ireland)
  europare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Cc][Oo][Ll][Ll][Ee][Cc][Tt][Ii][Oo][Nn][Ss]?[.][Ee][Uu][Rr][Oo][Pp][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"

  # Internet Memory Foundation (Netherlands)
  memoryre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Cc][Oo][Ll][Ll][Ee][Cc][Tt][Ii][Oo][Nn][Ss][.][Ii][Nn][Tt][Ee][Rr][Nn][Ee][Tt][Mm][Ee][Mm][Oo][Rr][Yy][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?"

  # Perma.CC Archives
  permaccre =  "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Pp][Ee][Rr][Mm][Aa][-][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][.][Cc][Cc][:]?[8]?[04]?[48]?[30]?"

  # Proni Web Archives
  pronire = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Pp][Rr][Oo][Nn][Ii][.][Gg][Oo][Vv][.][Uu][Kk][:]?[8]?[04]?[48]?[30]?"

  # UK Parliament
  parliamentre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Pp][Aa][Rr][Ll][Ii][Aa][Mm][Ee][Nn][Tt][.][Uu][Kk][:]?[8]?[04]?[48]?[30]?"

  # UK Web Archive (British Library)
  ukwebre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][.][Uu][Kk][:]?[8]?[04]?[48]?[30]?"

  # Athens University 
  greecere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Aa][Uu][Ee][Bb][.][Gg][Rr][:]?[8]?[04]?[48]?[30]?"

  # Canada
  # http://www.collectionscanada.gc.ca/webarchives/20071125010224/http
  canadare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Cc][Oo][Ll][Ll][Ee][Cc][Tt][Ii][Oo][Nn][Ss][Cc][Aa][Nn][Aa][Dd][Aa][.][Gg][Cc][.][Cc][Aa][:]?[8]?[04]?[48]?[30]?[/]([Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][Ww][Ee][Bb]|[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss])[/]"

  # Catalonian Archive
  # http://www.padi.cat:8080/wayback/20140404212712/http://www.ateneubcn.org/
  catalonre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Pp][Aa][Dd][Ii][.][Cc][Aa][Tt][:]?[8]?[04]?[48]?[30]?"

  # Estonian Web Archive
  # http://veebiarhiiv.digar.ee/a/20130606072101/http://www.tamula.edu.ee/index.php/et/
  estoniare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Vv][Ee][Ee][Bb][Ii][Aa][Rr][Hh][Ii][Ii][Vv][.][Dd][Ii][Gg][Aa][Rr][.][Ee][Ee][:]?[8]?[04]?[48]?[30]?"

  # National Archives USA (NARA)
  # https://www.webharvest.gov/congress112th/20121211213014/http://www.akaka.senate.gov/
  narare = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ww][Ww][.][Ww][Ee][Bb][Hh][Aa][Rr][Vv][Ee][Ss][Tt][.][Gg][Oo][Vv][:]?[8]?[04]?[48]?[30]?"

  # Singapore Archives
  # http://eresources.nlb.gov.sg/webarchives/wayback/20061229020131/http://www.nparks.gov.sg/
  singaporere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ee][Rr][Ee][Ss][Oo][Uu][Rr][Cc][Ee][Ss][.][Nn][Ll][Bb][.][Gg][Oo][Vv][:]?[8]?[04]?[48]?[30]?"

  # Slovenian Archives
  # http://nukrobi2.nuk.uni-lj.si:8080/wayback/20160725091135/https://mobile.twitter.com/cnn
  slovenere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Nn][Uu][Kk][Rr][Oo][Bb][Ii][0-9]?[.][Nn][Uu][Kk][.][Uu][Nn][Ii][-][Ll][Jj][.][Ss][Ii][:]?[8]?[04]?[48]?[30]?"

  # Freezepage
  # http://www.freezepage.com/1249681324ZHFROBOEGE
  freezepagere = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww]?[Ww]?[Ww]?[.]?[Ff][Rr][Ee][Ee][Zz][Ee][Pp][Aa][Gg][Ee][.][Cc][Oo][Mm][:]?[8]?[04]?[48]?[30]?"

  # National Archives US 
  # http://webharvest.gov/peth04/20041022004143/http://www.ftc.gov/os/statutes/textile/alerts/dryclean 
  webharvestre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Hh][Aa][Rr][Vv][Ee][Ss][Tt][.][Gg][Oo][Vv][:]?[4]?[48]?[30]?"

  # National Archives Australia
  #  http://pandora.nla.gov.au/pan/14231/20120727-0512/www.howlspace.com.au/en2/inxs/inxs.htm
  #  http://pandora.nla.gov.au/pan/128344/20110810-1451/www.theaureview.com/guide/festivals/bam-festival-2010-ivorys-rock-qld.html
  #  http://pandora.nla.gov.au/nph-wb/20010328130000/http://www.howlspace.com.au/en2/arenatina/arenatina.htm
  #  http://pandora.nla.gov.au/nph-arch/2000/S2000-Dec-5/http://www.paralympic.org.au/athletes/athleteprofile60da.html
  #  http://webarchive.nla.gov.au/gov/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability/
  #  http://content.webarchive.nla.gov.au/gov/wayback/20120326012340/http://news.defence.gov.au/2011/09/09/army-airborne-insertion-capability
  nlaaure = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/](pandora|webarchive|content[.]webarchive)[.]nla.gov.au[:]?[8]?[04]?[48]?[30]?[/](pan|nph[-]wb|nph[-]arch|gov|gov[/]wayback)[/]([0-9]{4,7}[/][0-9]{8}[-][0-9]{4}|[0-9]{14}|[0-9]{4}[/][A-Z][0-9]{4}[-][A-Z][a-z]{2}[-][0-9]{1,2})[/]"

  # WikiWix
  # http://archive.wikiwix.com/cache/20180329074145/http://www.linterweb.fr
  wikiwixre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Ww][Ii][Kk][Ii][Ww][Ii][Xx][.][Cc][Oo][Mm][:]?[8]?[04]?[48]?[30]?"

  # York University Archives
  # https://digital.library.yorku.ca/wayback/20160129214328/http
  yorkre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Dd][Ii][Gg][Ii][Tt][Aa][Ll][.][Ll][Ii][Bb][Rr][Aa][Rr][Yy][.][Yy][Oo][Rr][Kk][.][Cc][Aa][:]?[8]?[04]?[48]?[30]?"

  # Library and Archives Canada - http://webarchive.bac-lac.gc.ca:8080/wayback/20080116045132/http                                                              
  lacre = "[Hh][Tt][Tt][Pp][Ss]?[:][/][/][Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Bb][Aa][Cc][-][Ll][Aa][Cc][.][Gg][Cc][.][Cc][Aa][:]?[8]?[04]?[48]?[30]?" 



  # Citation templates that use archiveurl/archivedate 
  # see https://phabricator.wikimedia.org/T178106 for a list of templates
  # copy list to file "cites-list" and run this awk command to generate the citesre regex statement then copy-paste it here
  # awk -ilibrary 'BEGIN{printf "[{][{][ ]*(";for(i=1;i<=splitn("cites-list",a,i);i++){gsub(/^\"{{|}}\",?$/,"",a[i]);printf a[i] "|" }; print ")[^}]+}}[ ]*"}'
  citesre = "[{][{][ ]*(A Short Biographical Dictionary of English Literature|AZBilliards|BDMag|Bokref|Catholic[-]hierarchy|Cita audio|Cita conferencia|Cita conferenza|Cita DANFS|Cita enciclopedia|Cita Enciclopedia Católica|Cita entrevista|Cita episodio|Cita grupo de noticias|Cita historieta|Cita immagine|Cita juicio|Cita libro|Cita lista de correo|Cita mapa|Cita news|Cita notas audiovisual|Cita noticia|Cita pubblicazione|Cita publicación|Citar web|Cita tesis|Cita testo|Citation|Citation step free tube map|Citation Style documentation|Cita TV|Cita vídeo|Cita visual|Cita web|Cite act|Cite Australasia|Cite AV media|Cite AV media notes|Cite book|Cite comic|Cite comics image|Cite comics image lrg|Cite conference|Cite constitution|Cite DVD notes|Cite encyclopedia|Cite episode|Citeer boek|Citeer encyclopedie|Citeer journal|Citeer nieuws|Citeer tijdschrift|Citeer web|Cite Hansard|Cite IETF|Cite interview|Cite IrishBio|Cite journal|Cite letter|Cite magazine|Cite mailing list|Cite map|Cite Memoria Chilena|Cite music release notes|Cite news|Cite newsgroup|Cite PH act|Cite podcast|Cite postcode project|Cite press release|Cite QPN|Cite quick|Cite report|Cite SBDEL|Cite serial|Cite sign|Cite speech|Cite sports[-]reference|Cite techreport|Cite thesis|Cite Transperth timetable|Cite Trove newspaper|Cite tweet|Cite video|Cite vob|Cite web|Cite wikisource|College athlete recruit end|Cytuj stronę|DNZB|Documentación cita|Etude|Gazette WA|Goalzz|Harvard reference|Harvrefcol|Internetquelle|IPMag|IPSite|ITIS|IUCN|Kilde artikkel|Kilde avhandling|Kilde avis|Kilde AV[-]medium|Kilde bok|Kilde konferanse|Kilde oppslagsverk|Kilde pressemelding|Kilde www|KLISF|Lien conférence|Lien vidéo|Lien web|Macdonald Dictionary|MTRsource|Obra citada|Online source|PBMag|Press|Pressmeddelanderef|SA Rugby Article|Silvics|Singapore legislation|Source archived|Tidningsref|Tidskriftsref|Vancite book|Vancite journal|Vancite news|Vancite web|Vcite book|Vcite journal|Vcite news|Vcite web|Verkkoviite|Webbref|WebbrefSV|Web kaynağı|Web reference|WsPSM|Статья)[^}]+}}[ ]*"
  # use of citesre requires IGNORECASE=1 to be set

}

#
# noprotocol - given a URL, does it not have a protocol in the scheme?
#
#  Example: "www.dally.com" -> true
#           "www.dally.com/http://" -> true
#           "mailto://dally.com" -> false
#
function noprotocol(url,  p) {

  p = index(url, "://")

  if(p < 1)
    return 1

  if(substr(url, 1, p) ~ /[.]/)  # ignore if outside scheme
    return 1

  return 0
}

#
# urltimestamp_wayback - given a full IA URL (including http://) return wayback timestamp 
#
#   . see main function below, urltimestamp()
#
function urltimestamp_wayback(url,  a,c,i) {

  c = split(url, a, /\//)

  PROCINFO["sorted_in"] = "@ind_num_asc"
  for(i in a) {
    if(!empty(a[i])) {
      if(a[i] ~ /^post$/)    # skip: https://archive.org/post/119669/lawsuit-settled
        return ""
      if(a[i] ~ /^web$/)    
        return a[i + 1]
      if(a[i] ~ /^[0-9*?]+$/ && i == 3)
        return a[i]
    }
  }
  return ""
}

#
# urltimestamp - given an archive URL, return the date stamp portion
#
#   Example:
#     https://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#     20061009134445
#
function urltimestamp(url,  c,a,i) {

  if(isarchiveorg(url) || isbibalex(url))  # http://web.archive.bibalex.org:80/web/20011007083709/http..
    return urltimestamp_wayback(url)       # http://web.archive.org/web/20011007083709/http..

  if(iswebcite(url) || isfreezepage(url) || isnlaau(url))    # no timestamp
    return ""

                                          # https://archive.is/20121209212901/http..
                                          # http://webarchive.nationalarchives.gov.uk/20091204115554/http
                                          # https://swap.stanford.edu/20091122200123/http
                                          # http://webarchive.proni.gov.uk/20111213123846/http
                                          # http://webarchive.parliament.uk/20110714070703/http
  if(isarchiveis(url) || isstanford(url) || isproni(url) ||\
     isnatarchivesuk(url) || isparliament(url)) {
    c = split(url, a, /\//)
    if(length(a) > 3) {
      if(a[4] ~ /^[0-9*?]+$/)
        return a[4]
    }
  }

                                          # http://webharvest.gov/peth04/20041022004143/http://www.ftc.gov/os/statutes/textile/alerts/dryclean
  if(iswebharvest(url)) {
    c = split(url, a, /\//)
    if(length(a) > 6) {
      if(a[5] ~ /^[0-9*?]+$/)
        return a[5]
    }
  }

  if(iswikiwix(url)) {                    # http://archive.wikiwix.com/cache/20180329074145/http://www.linterweb.fr
    c = split(url, a, /\//)
    for(i=0;i<=c;i++) {
      if(!empty(a[i])) {
        if(a[i] ~ /^[Cc][Aa][Cc][Hh][Ee]$/ && i != c) {
          if(a[i + 1] ~ /^[0-9*?]+$/)
            return a[i + 1]
        }
      }
    }
  }

  if(islocgov(url) || isarchiveit(url)) {   # http://webarchive.loc.gov/all/20011209152223/http..
    c = split(url, a, /\//)                 # http://wayback.archive-it.org/all/20130420084626/http..
    for(i=0;i<=c;i++) {
      if(!empty(a[i])) {
        if(a[i] ~ /^[Aa][Ll][Ll]$/ && i != c) {
          if(a[i + 1] ~ /^[0-9*?]+$/)
            return a[i + 1]
        }
        if(a[i] ~ /^[0-9*?]+$/)
          return a[i]
      }
    }
  }

                                          # http://arquivo.pt/wayback/20091007194454/http..
                                          # http://arquivo.pt/wayback/wayback/20091007194454/http..
                                          # http://wayback.vefsafn.is/wayback/20071211000000/www.
                                          # http://www.padi.cat:8080/wayback/20140404212712/http
                                          # http://nukrobi2.nuk.uni-lj.si:8080/wayback/20160203130917/http
                                          # http://digital.library.yorku.ca/wayback/20160129214328/http
                                          # http://webarchive.bac-lac.gc.ca:8080/wayback/20080116045132/http
  if(isporto(url) || isvefsafn(url) || iscatalon(url) || isslovene(url) || isyork(url) || islac(url) ) {
    c = split(url, a, /\//)
    for(i=0;i<=c;i++) {
      if(!empty(a[i])) {
        if(a[i] ~ /^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$/ && i != c) {
          if(a[i + 1] ~ /^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$/ && i + 1 != c) {
            if(a[i + 2] ~ /^[0-9*?]+$/)
              return a[i + 2]
          }
          else {
            if(a[i + 1] ~ /^[0-9*?]+$/)
              return a[i + 1]
          }
        }
        if(a[i] ~ /^[0-9*?]+$/)
          return a[i]
      }
    }
  }

                                              # http://collection.internetmemory.org/nli/20160525150342/http
  if(iseuropa(url) || ismemory(url)) {        # http://collection.europarchive.org/nli/20160525150342/http
    c = split(url, a, /\//)
    for(i=0;i<=c;i++) {
      if(!empty(a[i])) {
        if(a[i] ~ /^[Nn][Ll][Ii]$/ && i != c) {
          if(a[i + 1] ~ /^[0-9*]+$/)
            return a[i + 1]
        }
      }
    }
  }

  if(ispermacc(url)) {                     # http://perma-archives.org/warc/20140729143852/http
    c = split(url, a, /\//)
    for(i=0;i<=c;i++) {
      if(!empty(a[i])) {
        if(a[i] ~ /^[Ww][Aa][Rr][Cc]$/ && i != c) {
          if(a[i + 1] ~ /^[0-9*]+$/)
            return a[i + 1]
        }
      }
    }
  }

                                         # http://www.collectionscanada.gc.ca/webarchives/20060209004933/http
                                         # http://www.collectionscanada.gc.ca/archivesweb/20060209004933/http
  if(iscanada(url)) {
    c = split(url, a, /\//)
    for(i=0;i<=c;i++) {
      if(!empty(a[i])) {
        if(a[i] ~ /^[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss]$|^[Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss][Ww][Ee][Bb]$/ && i != c) {
          if(a[i + 1] ~ /^[0-9*]+$/)
            return a[i + 1]
        }
      }
    }
  }

                                         # http://www.webarchive.org.uk/wayback/archive/20110324230020/http
  if(isukweb(url)) {
    split(url, a, /\//)
    if(length(a) > 5) {
      if(a[4] ~ /^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$/) {
        if(a[5] ~ /^[Aa][Rr][Cc][Hh][Ii][Vv][Ee]$/) {
          if(a[6] ~ /^[0-9*]+$/)
            return a[6]
        }
      }
    }
  }
  

                                         # http://eresources.nlb.gov.sg/webarchives/wayback/20100708034526/http
  if(issingapore(url)) {
    split(url, a, /\//)
    if(length(a) > 5) {
      if(a[4] ~ /^[Ww][Ee][Bb][Aa][Rr][Cc][Hh][Ii][Vv][Ee][Ss]$/) {
        if(a[5] ~ /^[Ww][Aa][Yy][Bb][Aa][Cc][Kk]$/) {
          if(a[6] ~ /^[0-9*]+$/)
            return a[6]
        }
      }
    }
  }

  return ""

}

#
# isarchiveorg - return true if URL is for archive.org
#
function isarchiveorg(url,  safe,datestamp,re) {

  safe = url
  re = "^[Hh][Tt][Tt][Pp][Ss]?[:]//" iahre "[.]?"
  sub(re, "", safe)
  if(safe ~ /^[Aa][Rr][Cc][Hh][Ii][Vv][Ee][.][Oo][Rr][Gg][:]?[8]?[04]?[48]?[30]?\//) {
    datestamp = urltimestamp_wayback(url)
    if(datestamp !~ /[*|?]/ && length(datestamp) > 3 && length(datestamp) < 15) {
      return 1
    }
  }
  return 0
}

#
# isarchive_helper - helper function for isarchive*() functions
#
function isarchive_helper(url, re) {
  re = "^" re
  if(url ~ re)
    return 1
  return 0
}

#
# Return true if URL is for webcitation.org
#
function iswebcite(url) { return isarchive_helper(url, wcre "[/]") }
#             
# Return true if URL is for archive.is, .fo, .il, .ec, .today
#
function isarchiveis(url) { return isarchive_helper(url, isre) }
#
# Return true if URL is for http://webarchive.loc.gov/all/20111109051100/http
#
function islocgov(url) { return isarchive_helper(url, locgovre) }
#
# Return true if URL is for http://arquivo.pt/wayback/20091010102944/http..
#
function isporto(url) { return isarchive_helper(url, portore  "[/]?[Ww]?[Aa]?[Yy]?[Bb]?[Aa]?[Cc]?[Kk]?[/]?[Ww]?[Aa]?[Yy]?[Bb]?[WwAa]?[EeCcLl]?[BbKkLl]?[/][0-9*]{8,14}[/]") }
#
# Return true if URL is for https://swap.stanford.edu/20091122200123/http
#
function isstanford(url) { return isarchive_helper(url, stanfordre "[/]?[Ww]?[Ee]?[Bb]?[/][0-9*]{8,14}[/]") }
#
# Return true if URL is for http://wayback.archive-it.org/all/20130420084626/http
#
function isarchiveit(url) { return isarchive_helper(url, archiveitre "[/]?[WwAa]?[EeLl]?[BbLl]?[/][0-9*]{8,14}[/]") }
#
# Return true if URL is for web.archive.bibalex.org:80/web/20011007083709/http
#
function isbibalex(url) { return isarchive_helper(url, bibalexre) }
#
# Return true if URL is for http://webarchive.nationalarchives.gov.uk/20091204115554/http
#
function isnatarchivesuk(url) { return isarchive_helper(url, natarchivesukre) }
#
# Return true if URL is for http://wayback.vefsafn.is/wayback/20071211000000/www.
#
function isvefsafn(url) { return isarchive_helper(url, vefsafnre) }
#
# Return true if URL is for http://collection.europarchive.org/nli/20160525150342/http
#
function iseuropa(url) { return isarchive_helper(url, europare) }
#
# Return true if URL is for http://collections.internetmemory.org/nli/20160525150342/http
#
function ismemory(url) { return isarchive_helper(url, memoryre) }
#
# Return true if URL is for http://perma-archives.org/warc/20140729143852/http
#
function ispermacc(url) { return isarchive_helper(url, permaccre) }
#
# Return true if URL is for http://webarchive.proni.gov.uk/20111213123846/http
#
function isproni(url) { return isarchive_helper(url, pronire) }
#
# Return true if URL is for http://webarchive.parliament.uk/20110714070703/http
#
function isparliament(url) { return isarchive_helper(url, parliamentre) }
#
# Return true if URL is for http://www.webarchive.org.uk/wayback/archive/20110324230020/http
#
function isukweb(url) { return isarchive_helper(url, ukwebre) }
#
# Return true if URL is for http://www.collectionscanada.gc.ca/webarchives/20060209004933/http
#
function iscanada(url) { return isarchive_helper(url, canadare) }
#
# Return true if URL is for http://www.padi.cat:8080/wayback/20140404212712/http
#
function iscatalon(url) { return isarchive_helper(url, catalonre) }
#
# Return true if URL is for http://eresources.nlb.gov.sg/webarchives/wayback/20100708034526/http
#
function issingapore(url) { return isarchive_helper(url, singaporere) }
#
# Return true if URL is for http://nukrobi2.nuk.uni-lj.si:8080/wayback/20160203130917/http
#
function isslovene(url) { return isarchive_helper(url, slovenere) }
#
# Return true if URL is for http://www.freezepage.com/1467168045ARYJBWUKWM
#
function isfreezepage(url) { return isarchive_helper(url, freezepagere) }
#
# Return true if URL is for http://webharvest.gov/peth04/20041022004143/http://www.ftc.gov/os/statutes/textile/alerts/dryclean
#
function iswebharvest(url) { return isarchive_helper(url, webharvestre) }
#
# NLA Australia
#
function isnlaau(url) { return isarchive_helper(url, nlaaure) }
#
# WikiWix
#
function iswikiwix(url) { return isarchive_helper(url, wikiwixre) }
#
# York University
#
function isyork(url) { return isarchive_helper(url, yorkre) }
#
# Library Archives Canada
#
function islac(url) { return isarchive_helper(url, lacre) }


#
# isarchive - return true if any one of the archive's listed in "group"
#
#  Example:
#     isarchive("http://archive.org/web/..", "sub1") ==> 0
#
function isarchive(url, group) {

  if(group == "all") {
    if(isarchiveorg(url) || isarchive(url, "sub1"))
      return 1
  }

  if(group == "sub1") {  # everything but archive.org
    if(iswebcite(url) || isfreezepage(url) || isnlaau(url) ||\
       isarchive(url, "sub2"))
      return 1
  }

  if(group == "sub2") {  # everything but archive.org, webcite, freezepage and nlaau
    if(isarchiveis(url) || islocgov(url) || isporto(url) ||\
       isstanford(url) || isarchiveit(url) || isbibalex(url) ||\
       isnatarchivesuk(url) || isvefsafn(url) || iseuropa(url) ||\
       ispermacc(url) || isproni(url) || isparliament(url) ||\
       isukweb(url) || iscanada(url) || iscatalon(url) ||\
       issingapore(url) || isslovene(url) || iswebharvest(url) ||\
       iswikiwix(url) || isyork(url) || ismemory(url) ||\
       islac(url) )
      return 1
  }

  if(group == "sub3") {  # everything using a 14-digit timestamp
    if(isarchiveorg(url) ||\
       isarchiveis(url) || islocgov(url) || isporto(url) ||\
       isstanford(url) || isarchiveit(url) || isbibalex(url) ||\
       isnatarchivesuk(url) || isvefsafn(url) || iseuropa(url) ||\
       ispermacc(url) || isproni(url) || isparliament(url) ||\
       isukweb(url) || iscanada(url) || iscatalon(url) ||\
       issingapore(url) || isslovene(url) || iswebharvest(url) ||\
       iswikiwix(url) || isyork(url) || ismemory(url) ||\
       islac(url) )
      return 1
  }
  return 0
}

#
# archivename - return name of archive service based on archive URL
#
function archivename(url) {

  if(empty(url)) 
    return "unknown" randomnumber(1000)

  if(isarchiveorg(url))
    return "archiveorg"
  else if(iswebcite(url))
    return "webcite"
  else if(isarchiveis(url))
    return "archiveis"
  else if(iswikiwix(url))
    return "wikiwix"
  else if(islocgov(url))
    return "locgov"
  else if(isporto(url))
    return "porto"
  else if(isstanford(url))
    return "stanford"
  else if(isarchiveit(url))
    return "archiveit"
  else if(isbibalex(url))
    return "bibalex"
  else if(isnatarchivesuk(url))
    return "natarchivesuk"
  else if(isvefsafn(url))
    return "vefsafn"
  else if(iseuropa(url))
    return "europa"
  else if(ismemory(url))
    return "memory"
  else if(ispermacc(url))
    return "permacc"
  else if(isproni(url))
    return "proni"
  else if(isparliament(url))
    return "parliament"
  else if(isukweb(url))
    return "ukweb"
  else if(iscanada(url))
    return "canada"
  else if(iscatalon(url))
    return "catalon"
  else if(issingapore(url))
    return "singapore"
  else if(isslovene(url))
    return "slovene"
  else if(iswebharvest(url))
    return "webharvest"
  else if(isfreezepage(url))
    return "freezepage"
  else if(isnlaau(url))
    return "nlaau"
  else if(isyork(url))
    return "york"
  else if(islac(url))
    return "lac"
  else {
    # Return "unknown#" where # is a random number so when doing blind comparisons
    # two "unknown" don't cause a match. 
    return "unknown" randomnumber(1000)
  }
}

#
# wayurlurl - given an archive.org URL or similar archive service that uses 8-14 digit timestamps,
#             return the original/source url portion 
#
#   . if the whole URL was urlencoded then decode it
#   . on error return 'url'
#
#   Example:
#      http://archive.org/web/20061009134445/http://timelines.ws/countries/AFGHAN_B_2005.HTML ->
#      http://timelines.ws/countries/AFGHAN_B_2005.HTML
#              
function wayurlurl(url,  date,inx,baseurl) {

  date = urltimestamp(url)
  if(!empty(date)) {
    inx = index(url, date)
    if(inx > 0) {                  
      baseurl = substr(url, inx + length(date) + 1, length(url))
      if(baseurl ~ /[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]/)
        baseurl = urldecodeawk(baseurl)
      if(!empty(baseurl) && noprotocol(baseurl))
        return "http://" baseurl
      else if(!empty(baseurl))     
        return baseurl
    }
  }
  return url

}

#
# urlurl - given a wayback, webcite, loc, porto etc., return the original url portion if available 
#
#   . on error return 'url'
#
function urlurl(url,  newurl,re,dest) {

  newurl = url

  if(isarchive(url, "sub3"))      # services with a timestamp
    return wayurlurl(url)
  else if(iswebcite(url))         # services without a determinable timestamp
    re = "^" wcre
  else if(isfreezepage(url))
    re = "^" freezepagere
  else if(isnlaau(url))
    re = "^" nlaaure      

  gsub(re, "", newurl)    

  if(match(newurl, /[Hh][Tt][Tt][Pp][Ss]?[^$]*[^$]?/, dest)) {
    if(dest[0] ~ /^[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]/) 
      dest[0] = urldecodeawk(dest[0])
    if(iswebcite(url))
      gsub(/[&]date[=][^$]*[^$]?/, "", dest[0])  # Remove trailing date from query?url=http.. forms
    return dest[0]
  }

  else if(iswebcite(url) || isfreezepage(url)) {  # try method 2 for example the URL doesn't start with "http"
    if(match(newurl, /[Uu][Rr][Ll][=][^$]*[^$]?/, dest)) {
      gsub(/[Uu][Rr][Ll][=]/, "", dest[0])
      if(dest[0] ~ /^[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]/)
        dest[0] = urldecodeawk(dest[0])
      gsub(/[&]date[=][^$]*[^$]?/, "", dest[0])  # Remove trailing date from query?url=http.. forms
      return dest[0]
    }
  }

  else if(isnlaau(url) && ! empty(newurl)) {   # filter known non-website URLs
    if(newurl ~ /^[Hh][Tt][Tt][Pp][Ss]?[%]3[Aa]/) 
      newurl = urldecodeawk(newurl)
    if(newurl !~ /[.][Pp][Dd][Ff]|[.][Dd][Oo][Cc]|[.][Tt][Xx][Tt]|[Aa]ria[_]?awards?/) {
      if(noprotocol(newurl))
        return "http://" newurl
      else
        return newurl
    }
  }

  return url

}

#
# formatedorigurl - format a non-archive URL into a regular format
#
function formatedorigurl(url) {

  url = strip(url)
  if(length(url) < 3) 
    return url
  
  if(url ~ /https?%3[Aa]/)
    url = urldecodeawk(url)
  if(url ~ /https?[:]%2[Ff]/)
    url = urldecodeawk(url)

  if(url ~ /^https?[:]\/\//)
    return url
  else if(url ~ /^\/\//)
    return "http:" url
  else {
    scheme = urlElement(url, "scheme")
    if(!empty(strip(scheme)))
      return url
  }

  return url

}

#
# urlequal - given two non-archive URLs, determine if they are the same negating for:
#            encoding, https, capitalization, "www.", port 80 and fragment (#) differences
#
#   . return 1 if equal, 0 if not
#
function urlequal(urlsource,wurlsource,  dest1,dest2,debug) {

        debug = 0

        if(debug) {
          print urlsource
          print wurlsource
          print "----"
        }

        if(empty(urlsource) || empty(wurlsource))
          return 0

        if(!empty(IGNORECASE))
          save_ic = IGNORECASE
        IGNORECASE=1

        urlsource = formatedorigurl(urlsource)
        wurlsource = formatedorigurl(wurlsource)

        gsub(/[%]20|[ ]/,"%2B",urlsource)
        gsub(/[%]20|[ ]/,"%2B",wurlsource)

        sub(/([%][a-z A-Z 0-9][a-z A-Z 0-9])$/, "", urlsource)
        sub(/([%][a-z A-Z 0-9][a-z A-Z 0-9])$/, "", wurlsource)

        urlsource = urldecodeawk(urlsource)
        wurlsource = urldecodeawk(wurlsource)

       # get rid of fragments..
        if(match(urlsource, /[#][^$]*[^$]?/, dest1))
          urlsource = subs(dest1[0], "", urlsource)
        if(match(wurlsource, /[#][^$]*[^$]?/, dest2))
          wurlsource = subs(dest2[0], "", wurlsource)
        
       # remove trailing garbage
        sub(/([.]|[,]|[-]|[:]|[;])$/, "", urlsource)
        sub(/([.]|[,]|[-]|[:]|[;])$/, "", wurlsource)

        sub(/\/$/, "", urlsource)
        sub(/\/$/, "", wurlsource)

        if(debug) {
          print urlsource
          print wurlsource
          print "----"
        }

        sub(/^https?[:]\/\/www[^.]*[.]/, "http://", urlsource)
        sub(/^https?[:]\/\/www[^.]*[.]/, "http://", wurlsource)

        urlsource = tolower(removeport80(urlsource))
        wurlsource = tolower(removeport80(wurlsource))

        sub(/^https?/, "http", urlsource)
        sub(/^https?/, "http", wurlsource)

        if(urlsource ~ /^ftp/ && wurlsource ~ /^http/)
          sub(/^ftp/, "http", urlsource)
        else if(wurlsource ~ /^ftp/ && urlsource ~ /^http/)
          sub(/^ftp/, "http", wurlsource)

       # Check if query ? portion is the same even if arguments are in different order
        if(match(urlsource, /[?][^$]*[^$]?/, dest1) && match(wurlsource, /[?][^$]*[^$]?/, dest2) ) {
          if(dest1[0] != dest2[0]) {
            if( sortstring(dest1[0], "@ind_str_asc") == sortstring(dest2[0], "@ind_str_asc") ) {
              urlsource  = subs(dest1[0], "", urlsource)
              wurlsource = subs(dest2[0], "", wurlsource)
            }
          }
        }

        if(debug) {
          print urlsource
          print wurlsource
          print "----"
        }

        if(empty(urlsource) || empty(wurlsource)) {
          if(!empty(save_ic))
            IGNORECASE = save_ic
          return 0
        }

        if(wurlsource == urlsource ||\
           urldecodeawk(wurlsource) == urlsource ||\
           wurlsource == urldecodeawk(urlsource) ||\
           urldecodeawk(wurlsource) == urldecodeawk(urlsource)) {

          if(!empty(save_ic))
            IGNORECASE = save_ic

          return 1
        }

        if(!empty(save_ic))
          IGNORECASE = save_ic

        return 0
}

#
# removeport80 - remove first occurance of :/80 from a URL
#
function removeport80(s) {
  if(empty(s))
    return ""
  sub(/[:]80\//, "/", s)
  return s
}


#
# webciteid - given a webcite URL, return the ID portion
#
#  . return "nobase62" if no base62 ID available
#  . return "error" on error
#
function webciteid(url,  c,a,code) {         

  c = split(url, a, /\//)

 # https://www.webcitation.org/6q1GRBGUe?url=http
  if(c > 3) {
    if(a[4] ~ /[?]/) {
      split(a[4], b, /[?]/)
      code = b[1]
    }
    else        
      code = a[4]

    # valid URL formats that are not base62  

     #  http://www.webcitation.org/query?id=1138911916587475
     #  http://www.webcitation.org/query?url=http..&date=2012-06-01+21:40:03
     #  http://www.webcitation.org/1138911916587475
     #  http://www.webcitation.org/cache/73e53dd1f16cf8c5da298418d2a6e452870cf50e
     #  http://www.webcitation.org/getfile.php?fileid=1c46e791d68e89e12d0c2532cc3cf629b8bc8c8e

    if(code ~ /^(query|cache|[0-9]{8,20}|getfile)/)
      return "nobase62"
    else if( ! empty(code))
      return code
  }
  return "error"

}
