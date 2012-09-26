###########################################################################################
#                                                                                         #
# xchannel.tcl -- universal channel protection script for eggdrop by demond@demond.net    #
#                                                                                         #
#                 highly-optimized, versatile and modular script for all of your channel  #
#                 protection needs; using an uniform routine for counting and punishing   #
#                 offenses, it's been designed for easier further enhancement and adding  #
#                 new offense type handlers; all configuration is done via .chanset       #
#                                                                                         #
#                 as of the current version, supported offense types are:                 #
#                                                                                         #
#                   % plain public flood (via chan message, notice, ctcp action)          #
#                   % mass flood (by a botnet via mass join, part, nick, public flood)    #
#                   % repeating                                                           #
#                   % using CAPS                                                          #
#                   % using colors                                                        #
#                   % spamming with URLs                                                  #
#                   % profanity (using bad words)                                         #
#                   % clone scanner (time-adaptive method)                                #
#                   % bad /whois info (realname, channels, server)                        #
#                   % revolving door (join for a few secs, then part)                     #
#                   % random nick/ident drones (heuristics detection algorithm)           #
#                   % in addition, the script features automatic +l limiter               #
#                   % and lag meter, disabling mass flood prot when lagged                #
#                   % as well as private spam scan using forked clone of the bot          #
#                                                                                         #
#                 DO NOT EDIT this script (even if you know what you are doing ;)         #
#                 instead, configure it to suit you from bot's party-line by using        #
#                 .chanset command and the following settings (you have to specify any    #
#                 of these only if you need default value changed; to see defaults, use   #
#                 .chaninfo #chan):                                                       #
#                                                                                         #
#       common -- (these are mandatory for each offense type handler)                     #
#                                                                                         #
#                 below, 'type' is one of: repeat, flood, color, spam, caps,              #
#                                          bad, clone, whois, door, drone, pspam          #
#                                                                                         #
#                 udef name        description                                            #
#                 ----------------------------------------------------------------------- #
#                 x:type         - the on/off switch (+/-)                                #
#                 x:type:punish  - sequence of letters w, k, or b, separated by a colon   #
#                                  for example, w:k:b means: on 1st offense, warn only;   #
#                                  on 2nd offense, kick; on 3rd and more offenses, ban    #
#                                  (you can also use letter d for devoicing; use bXX to   #
#                                  specify that ban's duration, overriding bantime below) #
#                 x:type:bantype - ban type number (see [maskhost] proc below for types)  #
#                 x:type:bantime - ban time in minutes                                    #
#                 x:type:reason  - the kick/ban reason                                    #
#                 ----------------------------------------------------------------------- #
#                                                                                         #
#                 for example, to enable repeat protection:                               #
#                   .chanset #yourchan +x:repeat                                          #
#                 to change the kick/ban reason for bad words:                            #
#                   .chanset #yourchan x:bad:reason wash your dirty mouth                 #
#                                                                                         #
#                 you can also use .xchanset [#channel|*] <commonset> [value]             #
#                 from bot's party-line to set any common setting (except on/off switch)  #
#                 for all offense handlers on a particular channel or all channels        #
#                                                                                         #
#                 an additional dcc command that allows you to manipulate word files is:  #
#                 .xfile [#channel|*] <add|del|list> <bad|whois> [word|pattern]           #
#                 which operates on bad word and /whois info lists (these are periodicaly #
#                 saved into disk files; of course, you can edit those files directly)    # 
#                                                                                         #
#                 some offense statistics are available via the partyline command .xstats #
#                 .xstats [#channel|*] <top|clear> [offense]                              #
#                                                                                         #
#       custom -- (these are specific for a particular offense type)                      #
#                                                                                         #
#                 module               udef name      format   description                #  
#                 ----------------------------------------------------------------------- #
#                 repeat handler     - x:repeat:rate   (n:m) n repeats in m seconds       #
#                 mass flood handler - x:mass:rate     (n:m) n events in m seconds        #
#                                    - x:mass:duration (n)   +mi locking duration, in min #
#                 caps handler       - x:caps:percent  (n)   percentage of cap letters    #
#                 bad words handler  - x:bad:file   (name)   file name of bad words file  #
#                 clone scanner      - x:clone:type    (n)   mask type (same as bantype)  #
#                                    - x:clone:count   (n)   clone trigger count          # 
#                 revolving door     - x:door:stay     (n)   min chan appearence in secs  #
#                 bad /whois         - x:whois:file (name)   file with bad /whois info    #
#                                    - x:whois:count   (n)   too many channels count      #
#                 priv spam scanner  - x:pspam:cycle   (n)   chan cycle frequency in mins #
#                 drone detector     - x:drone:score   (n)   heuristics score points      #
#                 lag meter          - x:lag:threshold (n)   no mass flood prot beyond it #
#                 +l limiter         - x:limit:slack   (n)   minimal difference between   #
#                                                            current user count and +l    #
#                 matching style     - x:other:match (key)   either 'string' or 'regexp'  #
#                 statistics         - x:stats:top     (n)   max top stats lines          #
#                 ----------------------------------------------------------------------- #
#                                                                                         #
#                 IMPORTANT: all offense handlers (except mass) are disabled by default   #
#                            to enable particular protection, use .chanset #chan +x:type  #
#                                                                                         #
#                      NOTE: defined bad words are treated as regular expressions (RE)    #
#                            (this applies also to defined bad /whois information)        #
#                                                                                         #
#                   WARNING: since v4.1 bad words and /whois info are matched using Tcl   #
#                            [string match] by default; to revert or switch to regexps,   #
#                            set your channel(s) x:other:match setting to 'regexp'        # 
#                                                                                         #
#  ver.history -- 1.0 - initial version                                                   #
#                                                                                         #
#                 2.0 - fixed minor bugs, enhanced [punish], added clone scanner          #
#                                                                                         #
#                 3.0 - added revolving door and bad /whois offense handlers              #
#                                                                                         #
#                 3.1 - added .xchanset dcc command                                       #
#                                                                                         #
#                 3.2 - added random nick drones detection                                #
#                                                                                         #
#                 3.4 - fixed outstanding bugs, added lag meter                           #
#                                                                                         #
#                 3.5 - compensated for long-standing 1.6.17 bug, damn lazy eggheads...   # 
#                                                                                         #
#                 3.6 - added devoice punish type, fixed .+chan initialization            #
#                                                                                         #
#                 4.0 - implemented private spam scanner a la spambuster                  #
#                                                                                         #
#                 4.1 - added .xfile dcc command                                          #
#                                                                                         #
#                 4.2 - added .xstats command, bantime spec in 'punish' chanset           # 
#                                                                                         #
###########################################################################################

package require Tcl 8.3
package require eggdrop 1.6

namespace eval xchannel {

variable version "xchannel-4.2"

variable script [info script]

variable names {punish bantype bantime reason}
variable udefs {str    int     int     str}

set conf1g(repeat) {pubm w:k:b 1 10 "repeating is lame"}
set conf1g(flood)  {flud w:k:b 1 10 "stop flooding"}
set conf1g(color)  {pubm w:k:b 1 10 "no colors"}
set conf1g(spam)   {pubm w:k:b 1 10 "spam"}
set conf1g(caps)   {pubm w:k:b 1 10 "caps off"}
set conf1g(bad)    {pubm w:k:b 1 10 "do not curse"}
set conf1g(clone)  {join w:k:b 2 10 "no cloning please"}
set conf1g(whois)  {join w:k:b 1 10 "bad /whois information"}
set conf1g(door)   {part w:k:b 1 30 "next time visit us longer"}
set conf1g(drone)  {join w:k:b 1 60 "possible drone detected"}
set conf1g(pspam)  {time w:k:b 1 90 "unsolicited spam"}

set custom(mass)   {rate:str:20:3 duration:int:5}
set custom(limit)  {slack:int:5}
set custom(repeat) {rate:str:3:10}
set custom(caps)   {percent:int:70}
set custom(bad)    {file:str:badwords.txt}
set custom(clone)  {type:int:2 count:int:4}
set custom(whois)  {file:str:badwhois.txt count:int:6}
set custom(lag)    {threshold:int:8}
set custom(door)   {stay:int:40}
set custom(drone)  {score:int:30}
set custom(pspam)  {cycle:int:15}
set custom(other)  {match:str:string}
set custom(stats)  {top:int:5}

set anames(bad)    words
set anames(whois)  bads

set adescr(bad)    "bad words"
set adescr(whois)  "bad whois"

variable mbinds {join part nick pubm}
variable lbinds {join part kick sign}

variable handlers {repeat color spam caps bad}

variable arrays {offenses:10:720 repeats:2:5 clones:5:60 whoises:20:240}

variable colore {([\002\017\026\037]|[\003]{1}[0-9]{0,2}[\,]{0,1}[0-9]{0,2})}

variable lag 0; variable next 0; variable pong 1

proc maskhost {nuhost {type 0}} {
	scan $nuhost {%[^!]!%[^@]@%s} nick user host
	scan [set mask [::maskhost $nuhost]] {%*[^@]@%s} mhost
	switch $type {
	0 - 1 {return $mask}       ;# *!*foo@*.bar.com
	2 {return *!*@$host}       ;# *!*@moo.bar.com
	3 {return *!*@$mhost}      ;# *!*@*.bar.com
	4 {return *!*$user@$host}  ;# *!*foo@moo.bar.com
	5 {return *!*$user@*}      ;# *!*foo@*
	6 {return $nuhost}
	}
}

proc fixargs {chan text args} {
	upvar $chan xchan; upvar $text xtext
	if {$::lastbind == "**"} {
		set xtext $xchan
		set xchan [lindex $args 0]
	} {
		set n [llength $args]
		set xtext [lindex $args [incr n -1]]
	}
}

proc timer {min hour day month year} {
	variable arrays
	variable idx; variable next
	variable anames
	if ${::server-online} {
		putserv "ping x:[unixtime]"
	}
	if {![info exists idx]} {
	foreach chan [channels] {
		if {![channel get $chan x:pspam]} {continue}
		set i [expr [incr next]%[llength $::servers]]
		scan [lindex [lindex $::servers $i] 0] {%[^:]:%d} server port
		control [connect $server $port] [namespace current]::handler
		putloglev 3 * "pspam scan: connecting to $server:$port..."
		break
	}}
	foreach elem $arrays {
		scan $elem {%[^:]:%[^:]:%s} name freq val
		upvar #1 [namespace current]::$name arr
		if {([unixtime]/60) % $freq == 0} {
			if {[info exists arr]} {
			foreach {hash data} [array get arr] {
				set ts [lindex $data 0]
				if {[unixtime] - $ts >= $val*60} {
					unset arr($hash)
				}
			}}
		} 
	}
	if {[scan $min %d] % 10 == 0} {
	foreach chan [channels] {
		foreach type [array names anames] {
			store $chan $type $anames($type)
		}
	}}
}

proc pspam {min hour day month year} {
	variable xnick
	variable idx; variable pong
	if {![info exists idx]} {return} 
	if {![valididx $idx] || !$pong} {
		unset idx
		putloglev 3 * "pspam scan: my socket died"
		if {[info exists xnick]} {unset xnick}
		catch {killdcc $idx}
		return
	} {
		putdcc $idx "ping x:[unixtime]"
		set pong 0
	}
	foreach chan [channels] {
		if {![channel get $chan x:pspam]} {continue}
		set mins [expr [scan $min %d]+[scan $hour %d]*60]
		set freq [channel get $chan x:pspam:cycle]
		if {$mins % $freq == 0} {
			putloglev 3 * "pspam scan: cycling $chan"
			putdcc $idx "part $chan"
			putdcc $idx "join $chan"
		}
	}
}

proc handler {ndx text} {
	variable xnick
	variable idx; variable pong
	variable colore
	if {$text == ""} {
		catch {unset idx}
		if {[info exists xnick]} {unset xnick}
		putloglev 3 * "pspam scan: disconnected"
		return 		
	}
	if {![info exists idx]} {
	if {![info exists xnick]} {
		set xnick [string map {? x} $::altnick]
		putloglev 3 * "pspam scan: connected, registering as $xnick"
		putdcc $ndx "user $::username x x :$::realname"
		putdcc $ndx "nick $xnick"
		return
	}}
	set text [split [string tolower $text]]
	switch [lindex $text 1] {
	001 {
		putloglev 3 * "pspam scan: registered"
		set pong 1
		set idx $ndx
		foreach chan [channels] {
			if {[channel get $chan x:pspam]} {
				putdcc $idx "join $chan"
			}
		}
	}
	433 {
		set digit [rand 10]
		set xnick [string replace $xnick e e $digit] 
		putdcc $ndx "nick $xnick"
	}
	privmsg - notice {
		set src [lindex $text 0]
		set nick [lindex $text 2]
		if {![string equal -nocase $nick $xnick]} {return}
		if {[scan $src {:%[^!]!%s} nick uhost] < 2} {return}
		set text [join [lrange $text 3 e]]
		regsub -all $colore $text {} text
		if {[regexp {(?i)(http://|www\.|irc\.|\s#\w|^#\w)} $text]} {
			set hand [finduser [string trimleft $src :]] 
			foreach chan [channels] {
				if {[channel get $chan x:pspam]} {
					punish $nick $uhost $hand $chan pspam
				}
			}
		}
	}
	pong {set pong 1}
	}
	switch [lindex $text 0] {
	ping {putdcc $idx "pong [lindex $text 1]"}
	}
}

proc init {chan} {
	variable handlers
	variable names; variable udefs
	variable mbinds; variable lbinds
	variable conf1g; variable custom
	setudef flag x:limit
	setudef flag x:stats
	foreach elem $lbinds {
		bind $elem - * [namespace current]::limit
	}
	foreach elem $mbinds {
		bind $elem - * [namespace current]::mass
	}
	bind notc - ** [namespace current]::mass
	bind ctcp - * [namespace current]::mass
	bind sign - * [namespace current]::door
	foreach {type data} [array get conf1g] {
		setudef flag x:$type
		bind [lindex $data 0] - * [namespace current]::$type
		if {[lsearch $handlers $type] != -1} {
			bind notc - ** [namespace current]::$type
			bind ctcp - * [namespace current]::$type
			if {$type != "repeat"} {
				bind part - * [namespace current]::$type
				bind sign - * [namespace current]::$type
			}
		}
		foreach val [lrange $data 1 e] name $names udef $udefs {
			setudef $udef x:$type:$name
			if {$udef == "int"} {set void 0} {set void ""}
			if {[channel get $chan x:$type:$name] == $void} {
				channel set $chan x:$type:$name $val
			}
		}
	}
	foreach {type data} [array get custom] {
		foreach elem $data {
			scan $elem {%[^:]:%[^:]:%s} name udef val
			setudef $udef x:$type:$name
			if {$udef == "int"} {set void 0} {set void ""}
			if {[channel get $chan x:$type:$name] == $void} {
				channel set $chan x:$type:$name $val
			}
		}		
	}
}

proc save {} {
	variable names; variable udefs
	variable conf1g; variable custom
	if {![catch {set f [open $::chanfile a]}]} {
		foreach chan [channels] {
		foreach {type data} [array get conf1g] {
			if {[channel get $chan x:$type]} {set sign +} {set sign -}
			puts $f "channel set $chan ${sign}udef-flag-x:$type"
			foreach name $names udef $udefs {
				set val [list [channel get $chan x:$type:$name]]
				puts $f "channel set $chan udef-$udef-x:$type:$name $val"
			}
		}
		if {[channel get $chan x:limit]} {set sign +} {set sign -}
		puts $f "channel set $chan ${sign}udef-flag-x:limit"
		foreach {type data} [array get custom] {
			foreach elem $data {
				scan $elem {%[^:]:%[^:]:%*s} name udef
				set val [list [channel get $chan x:$type:$name]]
				puts $f "channel set $chan udef-$udef-x:$type:$name $val"
			}
		}}
		close $f
	} {
		putlog "$version: ERROR: can't append to chanfile"
	}
}

proc punish {nick uhost hand chan type {subtype ""}} {
	variable offenses; variable stats
	if {[isop $nick $chan] || 
	    [matchattr $hand of|of $chan]} {return}
	set chan [string tolower $chan]
	set bantime [channel get $chan x:$type:bantime]
	set bantype [channel get $chan x:$type:bantype]
	if {$subtype == ""} {set what $type} {set what $subtype}
	set hash [md5 $chan:$what:[maskhost $nick!$uhost $bantype]]
	if {![info exists offenses($hash)]} {set n 1} {
		set n [lindex $offenses($hash) 1]; incr n
	}
	if {[channel get $chan x:stats]} {
		set key $chan:$type:[maskhost $nick!$uhost $bantype]
		if {[info exists stats($key)]} {incr stats($key)} {set stats($key) 1}
	}
	set offenses($hash) [list [unixtime] $n]
	set reason "[channel get $chan x:$type:reason] ($n)"
	set punish [split [channel get $chan x:$type:punish] :]
	set len [llength $punish]; if {$n > $len} {set n $len}
	switch -glob [lindex $punish [incr n -1]] {
	"w" {putserv "privmsg $nick :$reason"}
	"d" {if {[botisop $chan]} {pushmode $chan -v $nick}}
	"k" {if {[botisop $chan]} {putkick $chan $nick $reason}}
	"b*" {
		set btime [string trimleft [lindex $punish $n] b]
		if {$btime == ""} {set btime $bantime}
		newchanban $chan [maskhost $nick!$uhost $bantype] $::nick $reason $btime
		if {[botisop $chan]} {putkick $chan $nick $reason}
	}}
}

proc clone {nick uhost hand chan} {
	variable clones
	set chan [string tolower $chan]
	if {![channel get $chan x:clone]} {return}
	set type [channel get $chan x:clone:type]
	set count [channel get $chan x:clone:count]
	set hash [md5 $chan:[maskhost $nick!$uhost $type]]
	if {![info exists clones($hash)]} {
		set n 1; set ts [unixtime]
	} {
		set n [lindex $clones($hash) 1]; incr n
		set ts [lindex $clones($hash) 0]
		if {$n >= $count} {
			set m 0
			foreach user [chanlist $chan] {
				set mask [maskhost $nick!$uhost $type]
				set user $user![getchanhost $user $chan]
				if {[string match -nocase $mask $user]} {incr m}
			}
			if {$m >= $count} {
				punish $nick $uhost $hand $chan clone
			}
			set n $m; set ts [unixtime]
		}
	}
	set clones($hash) [list $ts $n]
}

proc repeat {nick uhost hand chan args} {
	variable repeats
	fixargs chan text $args
	if {[isbotnick $chan]} {return}
	set chan [string tolower $chan]
	set text [string tolower $text]
	if {![channel get $chan x:repeat]} {return}
	scan [channel get $chan x:repeat:rate] {%[^:]:%s} maxr maxt
	set hash [md5 $chan:$text:[maskhost $nick!$uhost]]
	if {![info exists repeats($hash)]} {
		set n 1; set ts [unixtime]
	} {
		set n [lindex $repeats($hash) 1]; incr n
		set ts [lindex $repeats($hash) 0]
		if {[unixtime] - $ts >= $maxt} {
			set n 1; set ts [unixtime]
		} {
			if {$n >= $maxr} {
				punish $nick $uhost $hand $chan repeat
				unset repeats($hash); return
			}
		} 
	}
	set repeats($hash) [list $ts $n]
}

proc mass {nick uhost hand chan args} {
	variable lag
	variable mcount; variable version
	if {$::lastbind == "**"} {
		set chan [lindex $args 0]
	}	
	if {![validchan $chan]} {return}
	if {[isbotnick $chan]} {return}
	set chan [string tolower $chan]
	if {![info exists mcount($chan)]} {
		set n 1; set ts [unixtime]
	} {
		set n [lindex $mcount($chan) 1]; incr n
		set ts [lindex $mcount($chan) 0]
		scan [channel get $chan x:mass:rate] {%[^:]:%s} maxr maxt
		if {$n >= $maxr} {
			if {[unixtime] - $ts <= $maxt} {
				set thr [channel get $chan x:lag:threshold]
				if {![botisop $chan]} {return}
				if {$lag >= $thr} {return}
				#set buf "mode $chan +mi\n"
				#putdccraw 0 [llength $buf] $buf
				putquick "mode $chan +im" -next
				putlog "$version: Mass Flood on $chan!!! Locking..."
		utimer	5 [list	putserv "notice $chan :Mass Flood!!! We'll re-open shortly..."]
				set duration [channel get $chan x:mass:duration]
				::timer $duration [list putserv "mode $chan -mi"]
				unset mcount($chan); return
			} {
				set n 1; set ts [unixtime]
			}
		}
	}
	set mcount($chan) [list $ts $n]
}

proc limit {nick uhost hand chan args} {
	if {![validchan $chan]} {return}
	if {![botisop $chan]} {return}
	if {![channel get $chan x:limit]} {return}
	set slack [channel get $chan x:limit:slack]
	set len [llength [chanlist $chan]]
	set lim [split [getchanmode $chan]]
	if {[string first l [lindex $lim 0]] == -1} {
		set limit $len
	} elseif {[string first k [lindex $lim 0]] == -1} {
		set limit [lindex $lim 1]
	} {
		set limit [lindex $lim 2]
	}
	if {$limit - $len < $slack} {
		incr limit $slack
	} elseif {$limit - $len > [expr 2*$slack]} {
		incr limit -$slack
	} {return}
	pushmode $chan +l $limit
}

proc bad {nick uhost hand chan args} {
	variable words; variable colore
	fixargs chan text $args
	if {[isbotnick $chan]} {return}
	set chan [string tolower $chan]
	if {![channel get $chan x:bad]} {return}
	set rx [channel get $chan x:other:match]
	set rx [string equal $rx "regexp"]
	if {[info exists words($chan)]} {
	regsub -all $colore $text {} text
	foreach elem $words($chan) {
		if {$rx} {
			set bad [regexp -nocase -- $elem $text]
		} {
			set bad [string match -nocase $elem $text]
		}
		if {$bad} {
			punish $nick $uhost $hand $chan bad
			break
		}
	}} 
}

proc caps {nick uhost hand chan args} {
	fixargs chan text $args
	if {[isbotnick $chan]} {return}
	if {![channel get $chan x:caps]} {return}
	set n 0; foreach c [split $text {}] {
		if {[string is upper $c]} {incr n}
	}
	set pct [channel get $chan x:caps:percent]
	set len [string length $text]
	if {$len > 3 && 100*$n/$len >= $pct} {
		punish $nick $uhost $hand $chan caps
	}
}

proc color {nick uhost hand chan args} {
	variable colore
	fixargs chan text $args
	if {[isbotnick $chan]} {return}
	if {![channel get $chan x:color]} {return}
	if {[regexp $colore $text]} {
		punish $nick $uhost $hand $chan color
	}
}

proc spam {nick uhost hand chan args} {
	variable colore
	fixargs chan text $args
	if {[isbotnick $chan]} {return}
	if {![channel get $chan x:spam]} {return}
	regsub -all $colore $text {} text
	regsub -all -nocase $chan $text {} text
	if {[regexp {(?i)(http://|www\.|irc\.|\s#\w|^#\w)} $text]} {
		punish $nick $uhost $hand $chan spam
	}
}

proc door {nick uhost hand chan msg} {
	if {![validchan $chan]} {return}
	if {![channel get $chan x:door]} {return}
	set stay [channel get $chan x:door:stay]
	if {[unixtime] - [getchanjoin $nick $chan] <= $stay} {
		punish $nick $uhost $hand $chan door
	}
}

proc drone {nick uhost hand chan} {
	if {![channel get $chan x:drone]} {return}
	set score [channel get $chan x:drone:score]
	if {[penalty $nick![scan $uhost {%[^@]@%*s}]] >= $score} {
		punish $nick $uhost $hand $chan drone
	}
}

proc flood {nick uhost hand type chan} {
	if {$chan == "*"} {return}
	if {![channel get $chan x:flood]} {return}
	if {$type == "kick" || $type == "deop"} {return}
	punish $nick $uhost $hand $chan flood $type
	return 1
}

proc whois {nick uhost hand chan} {
	variable whoises
	if {![channel get $chan x:whois]} {return}
	if {[matchattr $hand of|of $chan]} {return}
	set whoises($nick) [list [unixtime] [list $uhost $hand $chan]]
	putserv "whois $nick"
}

proc gotwhois {from keyword text} {
	variable colore
	variable whoises; variable bads
	set text [string trim $text]
	set nick [lindex [split $text] 1]
	if {![info exists whoises($nick)]} {return}
	foreach {uhost hand chan} [lindex $whoises($nick) 1] {}
	if {![channel get $chan x:whois]} {return}
	set chan [string tolower $chan]
	set rx [channel get $chan x:other:match]
	set rx [string equal $rx "regexp"]
	switch $keyword {
	311 {set text [lrange [split $text] 5 e]}
	319 {set text [lrange [split $text] 2 e]}
	312 {set text [lindex [split $text] 2]
		unset whoises($nick)
	}}
	set bad 0
	set len [llength $text]
	if {[info exists bads($chan)]} {
	set text [string trimleft [join $text] :]
	regsub -all $colore $text {} text
	foreach elem $bads($chan) {
		if {$rx} {
			set bad [regexp -nocase -- $elem $text]
		} {
			set bad [string match -nocase $elem $text]
		}
		if {$bad} {break}
	}}
	set count [channel get $chan x:whois:count]
	if {$bad || ($keyword == "319" && $len >= $count)} {
		punish $nick $uhost $hand $chan whois
	}
}

variable heuristics {
	{[0-9aeiouyj]{2}} 1 {[0-9bcdfghjklmnpqrstvwxz]{2}} 1
	{[0-9aeiouyj]{3}} 2 {[0-9bcdfghjklmnpqrstvwxz]{3}} 2
	{[0-9aeiouyj]{4}} 4 {[0-9bcdfghjklmnpqrstvwxz]{4}} 4
	{[0-9aeiouyj]{5}} 8 {[0-9bcdfghjklmnpqrstvwxz]{5}} 8
}

proc penalty {str} {
	variable heuristics
	set score 0; set prev .
	foreach c [split $str {}] {
		if {$c != $prev} {append buf $c}; set prev $c
	}
	foreach {re k} $heuristics {
		incr score [expr $k*[regexp -all -nocase $re $buf]]
	}
	incr score $score
}

proc load {chan type array} {
	variable version
	upvar #1 [namespace current]::$array arr
	set chan [string tolower $chan]
	set rx [channel get $chan x:other:match]
	set rx [string equal $rx "regexp"]
	set fn [channel get $chan x:$type:file]
	if {![catch {set f [open $fn]} err]} {
		if {[info exists arr($chan)]} {unset arr($chan)}
		foreach elem [split [read $f] " \t\r\n\f"] {
			if {$elem != ""} {
				if {$rx && [catch {regexp -- $elem x}]} {continue}
				lappend arr($chan) $elem
			} 
		}
		close $f
	} {
		putlog "$version: $chan: $err"
	}
}

proc store {chan type array} {
	variable version
	upvar #1 [namespace current]::$array arr
	set chan [string tolower $chan]
	set fn [channel get $chan x:$type:file]
	if {![catch {set f [open $fn w]} err]} {
		if {[info exists arr($chan)]} {
		foreach elem $arr($chan) {
			puts $f $elem
		}}
		close $f
	} {
		putlog "$version: $chan: $err"
	}
}

proc pluschan {hand idx text} {
	*dcc:+chan $hand $idx $text
	set chan [lindex [split $text] 0]
	init $chan
	load $chan bad words
	load $chan whois bads	
}

proc xchanset {hand idx text} {
	variable names; variable conf1g
	set text [string trim $text]
	if {$text == ""} {
		set format {[#channel|*] <commonset> [value]}
		putdcc $idx "Usage: .$::lastbind $format"
		return
	}
	set chan [lindex [split $text] 0]
	if {![regexp {^[#*]} $chan]} {
		set chan [lindex [split [console $idx]] 0]
	} {
		set text [join [lrange [split $text] 1 e]]
	}
	if {$chan != "*" && ![validchan $chan]} {
		putdcc $idx "No such channel $chan"
		return
	}
	if {![matchattr $hand n|n $chan]} {
		putdcc $idx "You are not +n on $chan"
		return
	}
	set type [lindex [split $text] 0]
	if {[lsearch -exact $names $type] == -1} {
		putdcc $idx "Invalid commonset $type"
		putdcc $idx "must be one of: [join $names ,]"
		return
	}
	set value [join [lrange [split $text] 1 e]]
	foreach name [array names conf1g] {
		if {$chan == "*"} {
			foreach ch [channels] {
			channel set $ch x:$name:$type $value
			}
		} {
			channel set $chan x:$name:$type $value
		}
	}
	if {$chan == "*"} {set chan "all channels"}
	putdcc $idx "Successfully set '$type' to '$value' on $chan"
	return 1
}

proc xfile {hand idx text} {
	variable anames
	variable adescr
	set text [string trim $text]
	if {$text == ""} {
		set format {[#channel|*] <add|del|list> <bad|whois> [word|pattern]}
		putdcc $idx "Usage: .$::lastbind $format"
		return
	}
	set chan [lindex [split $text] 0]
	if {![regexp {^[#*]} $chan]} {
		set chan [lindex [split [console $idx]] 0]
	} {
		set text [join [lrange [split $text] 1 e]]
	}
	if {$chan != "*" && ![validchan $chan]} {
		putdcc $idx "No such channel $chan"
		return
	}
	if {![matchattr $hand m|m $chan]} {
		putdcc $idx "You are not +m on $chan"
		return
	}
	set cmds {add del list}
	set cmd [lindex [split $text] 0]
	if {[lsearch -exact $cmds $cmd] == -1} {
		putdcc $idx "Invalid command $cmd"
		putdcc $idx "must be one of: [join $cmds ,]"
		return
	}
	set chan [string tolower $chan]
	set type [lindex [split $text] 1]
	set word [lindex [split $text] 2]
	if {![info exists anames($type)]} {
		putdcc $idx "Invalid type $type"
		putdcc $idx "must be one of: [join [array names anames] ,]"
		return
	}
	if {$chan != "*"} {
		lappend chans $chan
	} {
		foreach chan [channels] {lappend chans $chan}
	}
	foreach chan $chans {
		upvar #1 [namespace current]::$anames($type) arr
		switch $cmd {
		"add" {
			if {[info exists arr($chan)]} {
			set where [string tolower $arr($chan)]} {set where {}}
			if {[set i [lsearch -exact $where [string tolower $word]]] == -1} {
				lappend arr($chan) $word
				putdcc $idx "Added '$word' to $adescr($type) list for $chan" 
			}
		}
		"del" {
			if {[info exists arr($chan)]} {
			set where [string tolower $arr($chan)]
			if {[set i [lsearch -exact $where [string tolower $word]]] != -1} {
				set arr($chan) [lreplace $arr($chan) $i $i]
				putdcc $idx "Removed '$word' from $adescr($type) list for $chan" 
			}}
		}
		"list" {
			if {[info exists arr($chan)]} {
				putdcc $idx "Contents of $adescr($type) list for $chan:"
				putdcc $idx [join [lsort -unique $arr($chan)] ,]
			}
		}}
	}	
	return 1
}

proc xstats {hand idx text} {
	variable stats; variable conf1g
	set text [string trim $text]
	if {$text == ""} {
		set format {[#channel|*] <top|clear> [offense]}
		putdcc $idx "Usage: .$::lastbind $format"
		return
	}
	set chan [lindex [split $text] 0]
	if {![regexp {^[#*]} $chan]} {
		set chan [lindex [split [console $idx]] 0]
	} {
		set text [join [lrange [split $text] 1 e]]
	}
	if {$chan != "*" && ![validchan $chan]} {
		putdcc $idx "No such channel $chan"
		return
	}
	set type [lindex [split $text] 1]
	if {$type == ""} {set type *}
	set names [array names conf1g] 
	if {$type != "*" && [lsearch -exact $names $type] == -1} {
		putdcc $idx "Invalid offense $type"
		putdcc $idx "must be one of: [join $names ,]"
		return
	}
	set chan [string tolower $chan]
	set cmd [lindex [split $text] 0]
	switch $cmd {
	"top" {
		set i 0
		set ch $chan
		if {$chan == "*"} {set ch [lindex [channels] 0]} 
		set max [channel get $ch x:stats:top]
		set array [array get stats $chan:$type:*]
		if {[llength $array] > 0} {
		foreach {key value} $array {lappend res [list $key $value]}
		foreach elem [lsort -decreasing -integer -index 1 $res] {
			if {[incr i] <= $max} {
				set n [lindex $elem 1]
				set elem [split [lindex $elem 0] :]
				set mask [lindex $elem e]
				putdcc $idx [format "%3d: %s" $n $mask]
			} {break}
		}}
	}
	"clear" {
		set names [array names stats $chan:*]
		foreach key $names {unset stats($key)}
	}
	default {
		putdcc $idx "Invalid sub-command $cmd"
		putdcc $idx "must be one of: top,clear"
		return 
	}}
	return 1
}

proc gotpong {from keyword text} {
	variable lag
	set arg [lindex [split $text] 1]
	if {[regexp {^:x:} $arg]} {
		set arg [string trimleft $arg :x]
		set lag [expr [unixtime]-$arg]
	}
}

if {[lsearch [modules] channels*] == -1} {
	putlog "$version: ERROR: channels module is not loaded"
	return
} elseif {[llength [channels]] == 0} {
	if {[llength [userlist]] == 0} {
		putlog "$version: restart detected"
		#utimer 5 [list source [info script]]
		bind evnt - loaded {source $::xchannel::script;#}
		return
	} {
		putlog "$version: ERROR: no channels defined"
		return
	}
}

foreach elem [binds] {
	foreach {type flags name hits proc} $elem {
		if {[string match [namespace current]::* $proc]} {
			unbind $type $flags $name $proc
		}
	}
}

if {[info exists [namespace current]::cleanup]} {
	putlog "$version: performing cleanup..."
	foreach elem [channel info [lindex [channels] 0]] {
		if {[regexp {^[+-]?x:} $elem]} {
			set elem [string trim [lindex $elem 0] +-]
			catch {deludef flag $elem}
			catch {deludef int $elem}
			catch {deludef str $elem}
		}
	}
	putlog "$version: cleanup done, reload"
	unset cleanup; return
}

bind time - * [namespace current]::timer

bind raw - 311 [namespace current]::gotwhois
bind raw - 319 [namespace current]::gotwhois
bind raw - 312 [namespace current]::gotwhois

bind raw - pong [namespace current]::gotpong

bind dcc n|n xchanset [namespace current]::xchanset
bind dcc n|- +chan    [namespace current]::pluschan
bind dcc m|m xfile    [namespace current]::xfile
bind dcc m|m xstats   [namespace current]::xstats

catch {
unbind evnt - loaded {source $::xchannel::script;#}
}

if {[lindex [split $::version] 1] < 1061800} {
bind evnt - save {utimer 5 ::xchannel::save;#}
}

foreach chan [channels] {
	init $chan
	foreach type [array names anames] {
		load $chan $type $anames($type)
	}
}

putlog "$version by demond loaded successfully"

}
