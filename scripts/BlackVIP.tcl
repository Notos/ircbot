########################################################################
#
# BlackVIP TCL 1.0
#
# .vip on/off 
# .addvip nick
# .listvip
# .remvip number ( take it from the list )
#
#A TCL used to add VIP`s foreach chan.And if the nicks joins on the specific
#chan they receive VOICE + a message.It has also a timer for scan if all the VIP`S
#have VOICE.
#                                      BLaCkShaDoW ProductionS
#######################################################################

#Set here the time for scan if all the VIP`S has VOICE (minutes)

set viptime "30"

#If you want the VIP to receive a message set here "1"
#or else set here "0"

set viphowmsg "1"

#If you set "1" set here the message

set vipmsg "YOu received VOICE because you are a VIP member of this chan :)"

#Set here the flags that can add VIP`S

set vipwho "Nmn|MN"

########################################################################
#
#                             The ENd
#
########################################################################

bind pub $vipwho !vip vipstatus
bind pub $vipwho !addvip addvip
bind pub $vipwho !remvip remvip
bind pub $vipwho !listvip listvip
bind join - * vipscan
setudef flag vip


if {![info exists vips_running]} {
timer $viptime vips
set vips_running 1
}

proc vipstatus {nick host hand chan arg} {
set flag "vip"
set why [lindex [split $arg] 0]
if {$why == "" } { puthelp "NOTICE $nick :use .vip <on> / <off>"
return 0
}
if {$why == "on"} {
channel set $chan +$flag
puthelp "NOTICE $nick :Activated VIP system on $chan"
return 0
}
if {$why == "off"} {
channel set $chan -$flag
puthelp "NOTICE $nick :Deactivated the VIP system on $chan"
return 0
}
}

proc addvip {nick host hand chan arg} {
set dir "logs/vip($chan).txt"
set vip [join [lindex [split $arg] 0]]
if {$vip == ""} { puthelp "NOTICE $nick :Use .addvip <nick>"
return 0
}

if {[file exists $dir] == 0} {
set file [open $dir a]
close $file
}

set file [open $dir a]
puts $file $vip
close $file
puthelp "NOTICE $nick :Added as a VIP - $vip - in my database"
}

proc listvip {nick host hand chan arg} {
set dir "logs/vip($chan).txt"
if {[file exists $dir] == 0} {
set file [open $dir a]
close $file
}
set file [open $dir "r"]
set w [read -nonewline $file]
close $file
set data [split $w "\n"]
set i 0
if {$data == ""} { puthelp "NOTICE $nick :There are no VIP`S !"
return 0
}

foreach vip $data {
set i [expr $i +1]
lappend vipnumber "$i. $vip"
}
foreach txt [wordwrap [join $vipnumber " "] 200] {
puthelp "NOTICE $nick :The VIP`S are :"
puthelp "NOTICE $nick :$txt"
}
}

proc remvip {nick host hand chan arg} {
set dir "logs/vip($chan).txt"
set number [join [lindex [split $arg] 0]]
if {$number == ""} { puthelp "NOTICE $nick :Use .remvip <number> (take`it from the list)"
return 0
}
if {[file exists $dir] == 0} {
set file [open $dir a]
close $file
}
set file [open $dir "r"]
set data [read -nonewline $file]
close $file
set lines [split $data "\n"]
set i [expr $number - 1]
set delete [lreplace $lines $i $i]
set files [open $dir "w"]
puts $files [join $delete "\n"]
close $files
puthelp "NOTICE $nick :Erased from list the nick with the number $number.Please verify with the command .listvip"
}

proc vipscan {nick host hand chan} {
global vipmsg viphowmsg
set dir "logs/vip($chan).txt"
if {[file exists $dir] == 0} {
set file [open $dir a]
close $file
}
set file [open $dir "r"]
set w [read -nonewline $file]
close $file
set data [split $w "\n"]
if {$data == ""} { 
return 0
}
foreach vip $data {
if {[string match -nocase $nick $vip]} {
if {$viphowmsg == "1"} {
puthelp "NOTICE $nick :$vipmsg"
}
pushmode $chan +v $vip
}
}
}



proc vips { } {
global viptime
foreach chan [channels] {
set dir "logs/vip($chan).txt"
if {[channel get $chan vip]} {
putlog "checking VIP`S on $chan.."
set file [open $dir "r"]
set w [read -nonewline $file]
close $file
set data [split $w "\n"]
foreach vip $data {
if {[onchan $vip $chan]} {
if {![isvoice $vip $chan]} {
pushmode $chan +v $vip
}
}
}
}
}
timer $viptime vips
return 1
}


proc wordwrap {str {len 100} {splitChr { }}} { 
   set out [set cur {}]; set i 0 
   foreach word [split [set str][unset str] $splitChr] { 
     if {[incr i [string len $word]]>$len} { 
         lappend out [join $cur $splitChr] 
         set cur [list $word] 
         set i [string len $word] 
      } { 
         lappend cur $word 
      } 
      incr i 
   } 
   lappend out [join $cur $splitChr] 
}



putlog "BlackVIP TCL by BLaCkShaDoW Loaded"
