##
#
# egghttp.tcl v1.0.6 - by strikelight ([sL] @ EFNet) (05/14/04)
#
# Contact:
# - E-Mail: strikelight@tclscript.com
# - WWW   : http://www.TCLScript.com
# - IRC   : #Scripting @ EFNet
#
##
#
# Description:
#
# This is a TCL for other scripters to use for true asynchronous
# webpage connections.
#
# I noticed the need when using the http package for tcl,
# and it would not, for some reason or other, properly
# use asynchronous connections or not do anything at all when
# trying to use async connections.
# ^- As it turns out, eggdrop1.1.5 (and I believe 1.3.x) does
#    not have Tcl_DoOneEvent in the source, so the http package fails
#    for async connections, thus the need for this script.
#
# Realizing eggdrop already had the ability to make async connections,
# I created this considerably smaller tcl (in comparison to the http
# package).
#
# So, no more fighting with the http package for async connections,
# and no more freezes when trying to connect to a page. Enjoy!
#
##
#
# History:
#
# (05/14/04) - v1.1.0 - Added "-crlf 0/1" option to address a problem with
#                       performing requests on certain http servers
#                       (Call egghttp:geturl with -crlf 1 if the server you are
#                       connecting to expects CRLF's)
#                     - Due to some users' confusion, Added a putlog to show the
#                       script being loaded
# (11/17/02) - v1.0.5 - Added -useragent (ie. Mozilla/5.0) and
#                       -protocol (ie. HTTP/1.1) options to egghttp:geturl
# (10/06/02) - v1.0.4 - Fixed bug with egghttp:errormsg
#                     - Added egghttp:code -> returns numerical code reply received from server
# (07/24/02) - v1.0.3 - Fixed a regexp issue with TCL higher than 8.0 (reported by Sebastian)
# (06/18/02) - v1.0.2 - Fixed bug with specifying port to connect to
# (05/30/02) - v1.0.1 - Fixed bugs with script not working on higher eggdrop versions
# (05/13/02) - v1.0.0 - Initial Release
#
##
#
# Usage:
#
# See description before each procedure, and also
# see bottom of script for example usage.
#
# Note: Load this script BEFORE any other script that requires this tcl.
#
##

# Check for this variable to see if this TCL is loaded
set egghttp(version) "1.1.0"

####
#
# Procedure: egghttp:geturl
#
# Description: Used to download the contents of a webpage
#
# Arguments: url        = webpage to download
#            command    = command to execute when transaction is
#                         complete.  This command is called with
#                         one parameter, the sockID
#            options    = -timeout   -> Seconds before conection times out.
#                                       (Default = 60 seconds)
#                         -query     -> Query a webpage script (ie. cgi's)
#                         -headers   -> Send header information to server
#                                       (ie. Cookies)
#                         -protocol  -> Protocol to use (Default = HTTP/1.0)
#                         -useragent -> Useragent to reply with to server
#                                       (Default = Mozilla/5.0)
#                         -crlf      -> 0 or 1, Use CRLF's with query
#                                       (Default = 0, no)
#
# Returns: sockID
#
####
proc egghttp:geturl {url command args} {
  global egghttp
  if {![regexp -nocase {^(http://)?([^:/]+)(:([0-9]+))?(/.*)?$} $url x protocol server y port path]} {
    return -code error "bogus URL: $url"
  }
  if {[string length $port] == 0} {
    set port 80
  }
  proc isint {num} {
    if {($num == "") || ([string trim $num "0123456789"] != "")} {return 0}
    return 1
  }

  set state(-timeout) 60
  set state(-query) ""
  set state(-headers) ""
  set state(-protocol) "HTTP/1.0"
  set state(-useragent) "Mozilla/5.0"
  set state(-crlf) 0

  set options {-timeout -query -headers -protocol -useragent -crlf}
  set usage [join $options ", "]
  regsub -all -- - $options {} options
  set pat ^-([join $options |])$
  foreach {item value} $args {
    if {[regexp $pat $item]} {
      if {[info exists state($item)] && [isint $state($item)] && ![isint $value]} {
        return -code error "Bad value for $item ($value), must be integer"
      }
      set state($item) $value
    } else {
      return -code error "Unknown option $item, can be: $usage"
    }
  }
  if {$state(-crlf)} {
    set cr "\r"
  } else {
    set cr ""
  }
  if {![catch {set sock [connect $server $port]}]} {
    if {$state(-query) == ""} {
      putdcc $sock "GET $path $state(-protocol)$cr"
      putdcc $sock "Accept: */*$cr"
      putdcc $sock "Host: $server$cr"
      putdcc $sock "User-Agent: $state(-useragent)$cr"
      if {$state(-headers) != ""} {
        putdcc $sock "$state(-headers)$cr"
      }
      putdcc $sock "$cr"
    } else {
      set length [string length $state(-query)]
      putdcc $sock "POST $path $state(-protocol)$cr"
      putdcc $sock "Accept: */*$cr"
      putdcc $sock "Host: $server$cr"
      putdcc $sock "User-Agent: $state(-useragent)$cr"
      if {$state(-headers) != ""} {
        putdcc $sock "$state(-headers)$cr"
      }
      putdcc $sock "Content-Type: application/x-www-form-urlencoded$cr"
      putdcc $sock "Content-Length: $length$cr"
      putdcc $sock "$cr"
      putdcc $sock "$state(-query)$cr"
    }
    set egghttp($sock,url) "$url"
    set egghttp($sock,headers) ""
    set egghttp($sock,body) ""
    set egghttp($sock,error) "Ok"
    set egghttp($sock,command) $command
    set egghttp($sock,code) ""
    set egghttp($sock,timer) [utimer $state(-timeout) "egghttp:timeout $sock"]
    control $sock egghttp:control
    return $sock
  }
  return -1
}

####
#
# Procedure: egghttp:cleanup
#
# Description: Used to clean up variables that are no longer needed
#
# Arguments: sockID     = the sockID of the connection to clean up
#
# Returns: nothing
#
####
proc egghttp:cleanup {sock} {
  global egghttp
# blah.. would normally just do "array unset egghttp $sock,*"
# but earlier tcl versions don't support it...
  foreach blah [array names egghttp $sock,*] {
    catch {unset egghttp($blah)}
  }
}

####
#
# Procedure: egghttp:timeout
#
# Description: Used to timeout a connection. Do NOT call this manually
#
# Arguments: sockID     = sockID to timeout
#
# Returns: nothing
#
####
proc egghttp:timeout {sock} {
  global egghttp
  catch {killdcc $sock}
  set egghttp($sock,error) "Timeout or Connection Refused"
  catch {eval $egghttp($sock,command) $sock}
}

####
#
# Procedure: egghttp:data
#
# Description: Used to return the contents of the downloaded page
#
# Arguments: sockID     = sockID of the data to return
#
# Returns: contents of webpage
#
####
proc egghttp:data {sock} {
  global egghttp
  if {[info exists egghttp($sock,body)]} {
    return "$egghttp($sock,body)"
  }
  return ""
}

####
#
# Procedure: egghttp:headers
#
# Description: Used to return the header content of the downloaded page
#
# Arguments: sockID     = sockID of the data to return
#
# Returns: header contents of webpage
#
####
proc egghttp:headers {sock} {
  global egghttp
  if {[info exists egghttp($sock,headers)]} {
    return "$egghttp($sock,headers)"
  }
  return ""
}

####
#
# Procedure: egghttp:errormsg
#
# Description: Used to return any errors while getting page
#
# Arguments: sockID     = sockID of the data to return
#
# Returns: error message, or "Ok" if no error.
#
####
proc egghttp:errormsg {sock} {
  global egghttp
  if {[info exists egghttp($sock,error)]} {
    return "$egghttp($sock,error)"
  }
  return "Ok"
}

####
#
# Procedure: egghttp:code
#
# Description: Used to return the code received from the server while getting page
#
# Arguments: sockID     = sockID of the data to return
#
# Returns: code received by server, or "" if no code was received/found.
#
####
proc egghttp:code {sock} {
  global egghttp
  if {[info exists egghttp($sock,code)]} {
    return "$egghttp($sock,code)"
  }
  return ""
}

####
#
# Procedure: egghttp:control
#
# Description: Used to control incoming traffic from page. Do NOT call
#              this manually.
#
# Arguments: sockID     = sockID of connection
#            input      = incoming data
#
# Returns: 1 to relinquish control, 0 to retain control
#
####
proc egghttp:control {sock input} {
  global egghttp
  if {$input == ""} {
    catch {killutimer $egghttp($sock,timer)}
    if {[info exists egghttp($sock,headers)]} {
      set egghttp($sock,headers) "[string range $egghttp($sock,headers) 0 [expr [string length $egghttp($sock,headers)] - 2]]"
    } else {
      set egghttp($sock,headers) ""
    }
    if {[info exists egghttp($sock,body)]} {
      set egghttp($sock,body) "[string range $egghttp($sock,body) 0 [expr [string length $egghttp($sock,body)] - 2]]"
    } else {
      set egghttp($sock,body) ""
    }
    catch {eval $egghttp($sock,command) $sock}
    return 1
  }
  if {![string match "*<*" $input] && ($egghttp($sock,body) == "")} {
    append egghttp($sock,headers) "$input\n"
    if {[string match "*HTTP/*" $input] && ($egghttp($sock,code) == "")} {
      set egghttp($sock,code) [lindex [split $input] 1]
    }
    if {[string match "*content-type*" [string tolower $input]] && ![string match "*text*" [string tolower $input]]} {
      set egghttp($sock,error) "Non-Text file content type."
      catch {killdcc $sock}
      catch {eval $egghttp($sock,command) $sock}
      return 1
    }
  } else {
    append egghttp($sock,body) "$input\n"
  }
  return 0
}

putlog "egghttp.tcl API v$egghttp(version) by strikelight now loaded."

###
#
# Example 1:
#
# proc connect_callback {sock} {
#   set buffer [egghttp:data $sock]
#   egghttp:cleanup $sock
#   .. whatever else you want to do with the data ..
# }
#
# set sock [egghttp:geturl www.test.com/ connect_callback]
#
# Example 2: (Query a cgi script)
#
# same proc connect_callback
#
# set sock [egghttp:geturl www.test.com/test.cgi connect_callback -query input=blah]
#
# Example 3: (Send header information, such as cookies)
#
# same proc connect_callback
#
# set sock [egghttp:geturl www.test.com/ connect_callback -headers "Cookie: uNF=unf"]
#
###