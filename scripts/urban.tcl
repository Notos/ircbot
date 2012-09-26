##############################################################################################
##  ##  urbandictionary.tcl for eggdrop by Ford_Lawnmower irc.geekshed.net #Script-Help ##  ##
##############################################################################################
## To use this script you must set channel flag +ud (ie .chanset #chan +ud)                 ##
##############################################################################################
##############################################################################################
##  ##                             Start Setup.                                         ##  ##
##############################################################################################
namespace eval urbandictionary {
## Edit logo to change the logo displayed at the start of the line                      ##  ##
  variable logo "\017\00308,07\002UD\017"
## Edit textf to change the color/state of the text shown                               ##  ##
  variable textf "\017\00304"
## Edit linkf to change the color/state of the links                                    ##  ##
  variable linkf "\017\037\00304"
## Edit tagf to change the color/state of the Tags:                                     ##  ##
  variable tagf "\017\002"
## Edit line1, line2, line3, line4 to change what is displayed on each line             ##  ##
## Valid items are: word, definition, example, author, link                             ##  ##
## Do not remove any variables here! Just change them to "" to suppress display         ##  ##
  variable line1 "word"
  variable line2 "definition"
  variable line3 "example"
  variable line4 "author link"
## Edit cmdchar to change the !trigger used to for this script                          ##  ##
  variable cmdchar "!"
##############################################################################################
##  ##                           End Setup.                                              ## ##
##############################################################################################
  setudef flag ud
  bind pub -|- [string trimleft $urbandictionary::cmdchar]ud urbandictionary::main
  bind pub -|- [string trimleft $urbandictionary::cmdchar]slang urbandictionary::main
}
proc urbandictionary::main {nick host hand chan text} {
  if {[lsearch -exact [channel info $chan] +ud] != -1} {
    set text [strip $text]
    set number ""
    set definition ""
    set example ""
    set word ""
    set term ""
    set class ""
    set udurl ""
    set page ""
    set count 1
    set item 1
    if {[regexp {^(?:[\d]{1,}\s)(.*)} $text match term]} {
      set term [urlencode $term]
      set item [expr {[lindex $text 0] % 7}]
      set page [expr {int(ceil(double([lindex $text 0]) / double(7)))}]
      set page "&page=${page}"
      set udurl "/define.php?term=${term}${page}"
    } elseif {[lindex $text 0] != "${urbandictionary::cmdchar}ud"} {
      set term [urlencode $text]
      set udurl [iif $term "/define.php?term=${term}" "/random.php"]
      set class ""
    }
    set udsite "www.urbandictionary.com"
    if {[catch {set udsock [socket -async $udsite 80]} sockerr] && $udurl != ""} {
      return 0
    } else {
      puts $udsock "GET $udurl HTTP/1.0"
      puts $udsock "Host: $udsite"
      puts $udsock "User-Agent: Opera 9.6"
      puts $udsock ""
      flush $udsock
      while {![eof $udsock]} {
        set udvar " [gets $udsock] "
        regexp -nocase {<div\sclass="([^"]*)">} $udvar match class
        if {$class == "definition" && $count == $item} {
          if {[regexp -nocase {<div\sclass="definition">(.*?)<\/div>} $udvar match definition]} {
            set definition [striphtml $definition]
            if {[regexp -nocase {<div class="example">(.*)} $udvar match example]} {
              set class "example"
              set example [striphtml $example]
            }
          } else {
            set definition "$definition [striphtml $udvar]"
          }
        } elseif {[string match -nocase "*<td class='word'>*" $udvar]} {
          set class "word"
        } elseif {$class == "word" && $count == $item} {
          set word [striphtml $udvar]
          set class ""
        } elseif {$class == "example" && $count == $item} {
          if {[regexp -nocase {<div class="example">(.*)(?:<\/div>)?} $udvar match example]} {
            regexp -nocase {(.*)<div class="example">} $udvar match definitionend
            set definition "$definition [striphtml $definitionend]"
            set example [striphtml $example]
          } else {
            set example "$example [striphtml $udvar]"
          }
        } elseif {[regexp -nocase {class="author">(.*)<\/a>} $udvar match author]} {
          if {$count == $item} {
            set wordfix [string map {" " +} [string trimleft [string trimright $word " "] " "]]
            set word "${urbandictionary::tagf}Word: ${urbandictionary::textf}[striphtml $word]"
            set link "${urbandictionary::tagf}Link: ${urbandictionary::linkf}http://www.urbandictionary.com/define.php?term=${wordfix}${page}\017"
            set author "${urbandictionary::tagf}Author: ${urbandictionary::textf}[striphtml $author]"
            set definition "${urbandictionary::tagf}Definition: ${urbandictionary::textf}[striphtml $definition]"
            set example "${urbandictionary::tagf}Example: ${urbandictionary::textf}[striphtml $example]"
            if {$urbandictionary::line1 != ""} {
              msg $chan $urbandictionary::logo $urbandictionary::textf [subst [regsub -all -nocase {(\S+)} $urbandictionary::line1 {$\1}]]
            }
            if {$urbandictionary::line2 != ""} {
              msg $chan $urbandictionary::logo $urbandictionary::textf [subst [regsub -all -nocase {(\S+)} $urbandictionary::line2 {$\1}]]
            }
            if {$urbandictionary::line3 != ""} {
              msg $chan $urbandictionary::logo $urbandictionary::textf [subst [regsub -all -nocase {(\S+)} $urbandictionary::line3 {$\1}]]
            }
            if {$urbandictionary::line4 != ""} {
              msg $chan $urbandictionary::logo $urbandictionary::textf [subst [regsub -all -nocase {(\S+)} $urbandictionary::line4 {$\1}]]
            }
            close $udsock
            return 0
          } else {
            incr count
          }
        } elseif {[regexp -nocase {Location:\s(.*)} $udvar match redirect]} {
          regexp {term\=(.*)} $redirect match udredir
          urbandictionary::main $nick $host $hand $chan $udredir
          break
          return 0
        } elseif {[string match -nocase "*<div id='not_defined_yet'>*" $udvar] || [string match -nocase "*</body>*" $udvar]} {
          putserv "PRIVMSG $chan :Nothing found!"
          close $udsock
          return
        }
      }
    }
  }
}
proc urbandictionary::striphtml {string} {
  return [string map {&quot; \" &lt; < &rt; >} [regsub -all {(<[^<^>]*>)} $string ""]]
}
proc urbandictionary::replacestring {string found replace} {
  set found [escape $found]
  putlog "found: $found"
  return [regsub -all $found $string $replace]
  
}
proc urbandictionary::escape {string} {
  return [subst [regsub -all {([\[\]\(\)\{\}\.\?\:\^])} $string "\\1"]]
}
proc urbandictionary::iif {test do elsedo} {
   if {$test != 0 && $test != ""} {
     return $do
   } else {
     return "$elsedo"
   }
}
proc urbandictionary::urlencode {string} {
  regsub -all {^\{|\}$} $string "" string
  return [subst [regsub -nocase -all {([^a-z0-9\+])} $string {%[format %x [scan "\\&" %c]]}]]
}
proc urbandictionary::strip {text} {
  regsub -all {\002|\031|\015|\037|\017|\003(\d{1,2})?(,\d{1,2})?} $text "" text
    return $text
}
proc urbandictionary::msg {chan logo textf text} {
  set text [textsplit $text 50]
  set counter 0
  while {$counter <= [llength $text]} {
    if {[lindex $text $counter] != ""} {
      putserv "PRIVMSG $chan :${logo} ${textf}[string map {\\\" \"} [lindex $text $counter]]"
    }
    incr counter
  }
}
proc urbandictionary::textsplit {text limit} {
  set text [split $text " "]
  set tokens [llength $text]
  set start 0
  set return ""
  while {[llength [lrange $text $start $tokens]] > $limit} {
    incr tokens -1
    if {[llength [lrange $text $start $tokens]] <= $limit} {
      lappend return [join [lrange $text $start $tokens]]
      set start [expr $tokens + 1]
      set tokens [llength $text]
    }
  }
  lappend return [join [lrange $text $start $tokens]]
  return $return
}
putlog "\002*Loaded* \00308,07\002UrbanDictionary\002\003 \002by Ford_Lawnmower irc.GeekShed.net #Script-Help"
