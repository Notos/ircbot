# Urban Dictionary
# Copyright (C) 2006 perpleXa
# http://perplexa.ugug.co.uk / #perpleXa on QuakeNet
#
# Redistribution, with or without modification, are permitted provided
# that redistributions retain the above copyright notice, this condition
# and the following disclaimer.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY, to the extent permitted by law; without
# even the implied warranty of MERCHANTABILITY or FITNESS FOR A
# PARTICULAR PURPOSE.
#
# Usage:
#  -ud [id] <term>

# fsck is available at http://perplexa.ugug.co.uk
package require fsck 1.10;
package require http;

namespace eval urbandict {
  variable version 1.7;
  variable encoding "utf-8";
  variable client "Mozilla/5.0 (compatible; Y!J; for robot study; keyoshid)";
  bind pub -|- "!slang" [namespace current]::pub;
  namespace export pub;
}

proc urbandict::getdefinition {definition} {
  variable client;
  http::config -useragent $client;
  set url "http://www.urbandictionary.com/define.php?term=[urlencode $definition]";
  if {[catch {http::geturl $url -timeout 20000} token]} {
    return [list 0 "Warning: Couldn't connect to \[$url\]"];
  }
  upvar 0 $token state;
  if {![string equal -nocase $state(status) "ok"]} {
    return [list 0 "Warning: Couldn't connect to \[$url\] (connection $state(status))."];
  }
  set data [http::data $token];
  http::cleanup $token;
  set matches [regexp -all -inline {<div class=\"def_p\">.*?<p>(.*?)<\/p>} $data];
  set list [list];
  foreach {null definition} $matches {
    regsub -all {<[^>]*?>} [decode $definition] "" definition;
    regsub -all {[\r\n\s\t]+} $definition " " definition;
    lappend list $definition;
  }
  return [concat [llength $list] $list];
}

proc urbandict::urlencode {i} {
  variable encoding
  set index 0;
  set i [encoding convertto $encoding $i]
  set length [string length $i]
  set n ""
  while {$index < $length} {
    set activechar [string index $i $index]
    incr index 1
    if {![regexp {^[a-zA-Z0-9]$} $activechar]} {
      append n %[format "%02X" [scan $activechar %c]]
    } else {
      append n $activechar
    }
  }
  return $n
}

proc urbandict::pub {nick host hand chan argv} {
  if {![string compare $argv ""]} {
    puthelp "NOTICE $nick :Usage: !ud \[id\] <definition>";
    return 1;
  }
  if {[string is digit -strict [getword $argv 0]]} {
    if {[splitline $argv cargv 2]!=2} {
      puthelp "NOTICE $nick :Usage: !ud \[id\] <definition>";
      return 1;
    }
    set id [lindex $cargv 0];
    set argv [lindex $cargv 1];
    if {!$id} {
      set id 1;
    }
  } else {
    set id 1;
  }
  set definitions [getdefinition $argv];
  set count [lindex $definitions 0];
  if {!$count} {
    puthelp "PRIVMSG $chan :Nothing found for \"$argv\".";
    return 1;
  } elseif {$id > $count} {
    puthelp "PRIVMSG $chan :Only $count results found for \"$argv\".";
    return 1;
  }
  set definition [lindex $definitions $id];
  if {[string length $definition] <= 400} {
    puthelp "PRIVMSG $chan :\[$id/$count\] $definition";
    return 0;
  }
  foreach line [splitmsg $definition] {
    puthelp "PRIVMSG $chan :\[$id/$count\] $line";
  }
  return 0;
}

proc urbandict::decode {content} {
  if {![string match *&* $content]} {
    return $content;
  }
  set escapes {
    &nbsp; \x20 &quot; \x22 &amp; \x26 &apos; \x27 &ndash; \x2D
    &lt; \x3C &gt; \x3E &tilde; \x7E &euro; \x80 &iexcl; \xA1
    &cent; \xA2 &pound; \xA3 &curren; \xA4 &yen; \xA5 &brvbar; \xA6
    &sect; \xA7 &uml; \xA8 &copy; \xA9 &ordf; \xAA &laquo; \xAB
    &not; \xAC &shy; \xAD &reg; \xAE &hibar; \xAF &deg; \xB0
    &plusmn; \xB1 &sup2; \xB2 &sup3; \xB3 &acute; \xB4 &micro; \xB5
    &para; \xB6 &middot; \xB7 &cedil; \xB8 &sup1; \xB9 &ordm; \xBA
    &raquo; \xBB &frac14; \xBC &frac12; \xBD &frac34; \xBE &iquest; \xBF
    &Agrave; \xC0 &Aacute; \xC1 &Acirc; \xC2 &Atilde; \xC3 &Auml; \xC4
    &Aring; \xC5 &AElig; \xC6 &Ccedil; \xC7 &Egrave; \xC8 &Eacute; \xC9
    &Ecirc; \xCA &Euml; \xCB &Igrave; \xCC &Iacute; \xCD &Icirc; \xCE
    &Iuml; \xCF &ETH; \xD0 &Ntilde; \xD1 &Ograve; \xD2 &Oacute; \xD3
    &Ocirc; \xD4 &Otilde; \xD5 &Ouml; \xD6 &times; \xD7 &Oslash; \xD8
    &Ugrave; \xD9 &Uacute; \xDA &Ucirc; \xDB &Uuml; \xDC &Yacute; \xDD
    &THORN; \xDE &szlig; \xDF &agrave; \xE0 &aacute; \xE1 &acirc; \xE2
    &atilde; \xE3 &auml; \xE4 &aring; \xE5 &aelig; \xE6 &ccedil; \xE7
    &egrave; \xE8 &eacute; \xE9 &ecirc; \xEA &euml; \xEB &igrave; \xEC
    &iacute; \xED &icirc; \xEE &iuml; \xEF &eth; \xF0 &ntilde; \xF1
    &ograve; \xF2 &oacute; \xF3 &ocirc; \xF4 &otilde; \xF5 &ouml; \xF6
    &divide; \xF7 &oslash; \xF8 &ugrave; \xF9 &uacute; \xFA &ucirc; \xFB
    &uuml; \xFC &yacute; \xFD &thorn; \xFE &yuml; \xFF
  };
  set content [string map $escapes $content];
  set content [string map [list "\]" "\\\]" "\[" "\\\[" "\$" "\\\$" "\\" "\\\\"] $content];
  regsub -all -- {&#([[:digit:]]{1,5});} $content {[format %c [string trimleft "\1" "0"]]} content;
  regsub -all -- {&#x([[:xdigit:]]{1,4});} $content {[format %c [scan "\1" %x]]} content;
  regsub -all -- {&#?[[:alnum:]]{2,7};} $content "?" content;
  return [subst $content];
}

putlog "Script loaded: Urban Dictionary v$urbandict::version by perpleXa";
