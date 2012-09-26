#|---------------------------------------------------------|
#|       TVRage Sctipt by Gecko321 - P2P-Network           |
#|                        JeepXJ92@gmail.com               |
#|---------------------------------------------------------|
#| Checks TVRage.com for information on shows and on       |
#| what is scheduled.                                      |
#|---------------------------------------------------------|
#| Updates:                                                |
#|  v2.0 - Added where it will show how long till the      |
#|         next episode airs.                              |
#|         Added !next !last !today !tomorrow.             |
#|         Added an announcer for whats coming up.         |
#|                                                         |
#|  v2.1 - Added Error checking for TVRage Site            |
#|                                                         |
#|  v2.2 - Added ability to change Time Offset through     |
#|         Partyline                                       |
#|                                                         |
#|  v2.3 - Added ability to show show summary for a        |
#|         specific show or show episode                   |
#|                                                         |
#|  v2.4 - Added option to turn off time change and        |
#|         displaying airing to. This speeds up the        |
#|         output.                                         |
#|         Fixed where if there were no shows airing       |
#|         on selected networks for schedule doesn't       |
#|         show just the time.                             |
#|         Added commands to partyline. Type .tvhelp       |
#|         for list of options.                            |
#|         Added option on where to show schedule. Can be  |
#|         changed through the party line.                 |
#|---------------------------------------------------------|
#|                  ---Commands---                         |
#|---------------------------------------------------------|
#|  Channel Commands:                                      |
#|                                                         |
#| !tv <show>                                              |
#|      Gets information on <show>                         |
#| !next <show>                                            |
#|      Shows when the <show> is airing next               |
#| !last <show>                                            |
#|      Show what the <show> was aired last                |
#| !today/!tomorrow                                        |
#|      Show the schedule for either <today> or            |
#|      <tomorrow>.                                        |
#| !sum <show> <SseasonXepisode>                           |
#|      Example !sum House (Optional s2x04)                |
#|      Shows the summary of the specific episode          |
#|                                                         |
#|  Partyline Commands                                     |
#|                                                         |
#|  .timechange (+/- 0-12)                                 |
#|      Changes time offset through the partyline          |
#|---------------------------------------------------------|

bind pub - !tv tv:search
bind pub - !today tv:today
bind pub - !tomorrow tv:tomorrow
bind pub - !next tv:next
bind pub - !last tv:last
bind pub - !sum tv:summary
bind dcc - timechange tv:timechange
bind dcc - airing tv:duration
bind dcc - tvhelp tv:help
bind dcc - schedule tv:schedule
clearqueue all
#---------------------------------------------------------------------------------------
#Comment or uncomment the following line to turn off the announcement of upcoming  shows
#Uncomment if using eggdrop 1.6.19
#bind time - "?0 * * * *" tv:anon
#Uncomment if using eggdrop 1.6.20
bind cron - {*/10 * * * *} tv:anon
#----------------------------------------------------------------------------------------

#Select networks to show
#A&E|ABC|ABC Family|Adult Swim|AMC|Animal Planet|BBC America|Biography Channel|Bounce|Bravo|Cartoon Network|CBS|CineMax|CMT|Comedy Central|Cooking Channel|Destination America|DIRECTV|Discovery Channel|Disney Channel|Disney XD|DIY Network|E!|Food Network|FOX|Fox Business Network|Fuel TV|Fuse|FX|G4|GAC|Golf Channel|H2 TV|HBO|HDNet|HGTV|History Channel|HLN|HUB|ID: Investigation Discovery|IFC|Investigation Discovery|Lifetime|Logo|Military Channel|MTV|MTV2|National Geographic Channel|National Geographic Wild|NBC|NBC Sports Network|Nick @ Nite|Nickelodeon|NickToons|Ovation TV|OWN|Oxygen|Pay-Per-View|PBS|Playboy TV|ReelzChannel|Science Channel|Showtime|Smithsonian Channel|Speed Channel|Spike TV|Style|Sundance|Syfy|Syndicated|TBS|TeenNick|The CW|The Golf Channel|TLC|TNT|Travel Channel|truTV|TV Guide Channel|TV Land|TV One|USA|Velocity|VH1|WE|Weather Channel
set networks "A&E|ABC|ABC Family|Adult Swim|AMC|Animal Planet|BBC America|Biography Channel|Bounce|Bravo|Cartoon Network|CBS|CineMax|CMT|Comedy Central|Cooking Channel|Destination America|DIRECTV|Discovery Channel|Disney Channel|Disney XD|DIY Network|E!|Food Network|FOX|Fox Business Network|Fuel TV|Fuse|FX|G4|GAC|Golf Channel|H2 TV|HBO|HDNet|HGTV|History Channel|HLN|HUB|ID: Investigation Discovery|IFC|Investigation Discovery|Lifetime|Logo|Military Channel|MTV|MTV2|National Geographic Channel|National Geographic Wild|NBC|NBC Sports Network|Nick @ Nite|Nickelodeon|NickToons|Ovation TV|OWN|Oxygen|Pay-Per-View|PBS|Playboy TV|ReelzChannel|Science Channel|Showtime|Smithsonian Channel|Speed Channel|Spike TV|Style|Sundance|Syfy|Syndicated|TBS|TeenNick|The CW|The Golf Channel|TLC|TNT|Travel Channel|truTV|TV Guide Channel|TV Land|TV One|USA|Velocity|VH1|WE|Weather Channel"

#Time offset, all of the times are reported in Us times, if
#you want to convert it to local time. Set the offset here
#set to 0 not to convert. otherwise use -hours or +hours
#0 is for EST
set time_offset "0"

#sets location for schedule display.
# chan displays it in a channel
# nick diplays it in a PM
set location "chan"

#Change to (on/off) to turn on to show time airing till.
set tv_time "off"

#select channel to show Upcoming in
set chan "#Chan"

#------------------------
#Do not edit below here!!
#------------------------
proc tv:search {nick host hand chan arg} {
	global time_offset tv_time
	if {$arg == ""} {
		putserv "PRIVMSG $chan :Commands for TVRage Bot."
		putserv "PRIVMSG $chan :-!tv <show>"
		putserv "PRIVMSG $chan :-!last/!next <show>"
		putserv "PRIVMSG $chan :-!today/!tomorrow"
		putserv "PRIVMSG $chan :-!sum <show> (seasonXepisode)"
	} else {
		set arg [string map { " " "%20" } $arg]
		set url "http://services.tvrage.com/tools/quickinfo.php?show=$arg"
		set page [tv:web2data $url]
		if {$page == "timeout"} { putquick "PRIVMSG $chan :TVRage has timed out. Please try again later."
		} elseif {$page == 0 || $page == ""} { putquick "PRIVMSG $chan :TVRage services are currently down"
		} else {
	    regexp {Show Name@([A-Za-z 0-9\&\':]+)} $page gotname show_name
			if {![info exists show_name]} { putquick "PRIVMSG $chan :No Such Show!"
			}  else {    
				regexp {Show URL@http://www.tvrage.com/([A-Za-z_0-9/-]+)} $page goturl show_url
				regexp {Latest Episode@([0-9x]+)\^([A-Za-z0-9 -\`\"\'\&:\.,]+)\^([A-Za-z0-9/]+)} $page gotlatest latest_ep latest_ep_title latest_ep_date
				regexp {Next Episode@([0-9x]+)\^([A-Za-z0-9 -\`\"\'\&:.,]+)\^([A-Za-z0-9/]+)} $page gotnext next_ep next_ep_title next_ep_date
				regexp {Status@([A-Za-z/ ]+)} $page gotstatus show_status
				regexp {Network@([A-Za-z 0-9\!@\:]+)} $page gotnetwork show_network
				regexp {Airtime@([A-Za-z, 0-9:]+)} $page gotairtime show_airtime
				regexp {[0-9]+\:([0-9]+).*?([A-Za-z]+)} $show_airtime time 
				regexp {RFC3339@([A-Za-z 0-9-]+[0-9:]+)} $page gotrfc show_rfc    
				regexp -line {Genres@(.*)} $page => genre		
				if {$time_offset != 0} { set show_airtime [tv:time $latest_ep_date $time] }
				putquick "PRIVMSG $chan :$show_name -- $show_airtime $show_network ($show_status) ($genre)"
				putquick "PRIVMSG $chan :Episode URL: http://www.tvrage.com/$show_url"
				putquick "PRIVMSG $chan :Latest Episode: $latest_ep_date $latest_ep $latest_ep_title"
				if { [info exists show_rfc] } {    
					if {$tv_time == "on"} {
						set show_date_time [chng_time [clock scan "$next_ep_date $time" -format {%b/%d/%Y %I:%M %p}]]
						set airing "(Airing in [duration [expr {$show_date_time - [unixtime]}]])"
					} else { set airing "" }
					putquick "PRIVMSG $chan :Next Episode: $next_ep_date $next_ep $next_ep_title $airing"
				}
			}
		}
	}
}
proc tv:anon {minute hour day month weekday} {  
  global chan networks
  set url "http://services.tvrage.com/tools/quickschedule.php"
  set page [tv:web2data $url]
  if {$page != 0 || $page != ""} {
    regexp {(\[DAY\].*?)\[DAY\]} $page gotday show_day
    if {[info exists show_day]} {  
      regexp {\[DAY\](.*?)\[/DAY\]} $show_day gotday show_date     
      set show_day "$show_day\[TIME\]"  
      while {[regexp {\[TIME\](.*?)\[\/TIME\]} $show_day gottime time]} {
        regexp {(\[TIME\].*?)\[TIME\]} $show_day gottime shows
        if {[info exists shows]} {
          set show_date_time [chng_time [clock scan "$show_date $time"]]
          regexp {[0-9]+\:([0-9]+).*?([A-Za-z]+)} $time m min hr            
          if { $hr == "am"} { set show_date_time [expr {$show_date_time + 86400}] }
          set time_till [expr {$show_date_time - [unixtime]}]
          regsub {(\[TIME\].*?\[/TIME\])} $show_day "" show_day
          if {$time_till < 600 && $time_till > 0} { putserv "PRIVMSG $chan :The following shows are airing in [duration $time_till]"	  
						foreach line [split $shows "\n"] {
              if {[regexp {\[SHOW\](.*?)\[/SHOW\]} $line gotshow show]} { regexp {(.*?)\^(.*?)\^(.*?)\^} $show t network show episode	    
								if {[info exists network]} { if {[regexp $network $networks]} { putserv "PRIVMSG $chan :-($network) $show - $episode" } ; unset network show episode }
				      }
						}
            if {$min == "00" || $min == "30"} { break }
          } 
        }
      }
    }
  }
}

proc tv:tomorrow {nick host hand chan arg} {
  global networks time_offset location
  set url "http://services.tvrage.com/tools/quickschedule.php"
  set page [tv:web2data $url]
  if {$page == "timeout"} { putserv "PRIVMSG $chan :TVRage has timed out. Please try again in a few minutes"
	} elseif {$page == 0 || $page == ""} { putserv "PRIVMSG $chan :TVRage services are currently down"
  } else {
    regsub {(\[DAY\].*?\[/DAY\])} $page "" page   
    regexp {(\[DAY\].*?)\[DAY\]} $page gotday show_day
    regexp {\[DAY\](.*?)\[/DAY\]} $show_day gotday show_date  
    set show_day "$show_day\[TIME\]"  
    putquick "PRIVMSG [set $location] :Shows airing tomorrow $show_date:"  
    while {[regexp {\[TIME\](.*?)\[\/TIME\]} $show_day gottime show_time]} {
      if {[info exists show_time]} {
        regexp {\[TIME\](.*?)\[/TIME\]} $show_day gottime time
        regexp {(\[TIME\].*?\[TIME\])} $show_day gottime shows      
        regsub {(\[TIME\].*?\[TIME\])} $show_day "\[TIME\]" show_day   
        foreach line [split $shows "\n"] {
          if {[regexp {\[SHOW\](.*?)\[/SHOW\]} $line gotshow show]} {
            regexp {([A-Za-z 0-9@\:]+)\^([A-Za-z0-9 -\`\"\'\&:\.,]+)\^([0-9x]+)\^} $show t network show episode	            
            if {[info exists network] && [regexp $network $networks]} { append new_shows "--($network) $show - $episode \n" ; unset network show episode }
					}
        }
				if {[info exists new_shows]} {
				  if {$time_offset != 0} { set time [strftime {%I:%M %p} [chng_time [clock scan $time]]]}
					putquick "PRIVMSG [set $location] :-$time"	; foreach line [split $new_shows "\n"] { if {$line != ""} { putquick "PRIVMSG [set $location] :$line" }}
				  unset new_shows
	    	}
      }
    }
  }
}

proc tv:today {nick host hand chan arg} {
  global networks time_offset location
  set url "http://services.tvrage.com/tools/quickschedule.php"
  set page [tv:web2data $url]
  if {$page == "timeout"} { putserv "PRIVMSG $chan :TVRage has timed out. Please try again in a few minutes"
	} elseif {$page == 0 || $page == ""} { putserv "PRIVMSG $chan :TVRage services are currently down"
  } else {
    regexp {(\[DAY\].*?)\[DAY\]} $page gotday show_day
    regexp {\[DAY\](.*?)\[/DAY\]} $show_day gotday show_date  
    set show_day "$show_day\[TIME\]"
    putquick "PRIVMSG [set $location] :Shows airing today $show_date:"    
    while {[regexp {\[TIME\](.*?)\[\/TIME\]} $show_day gottime show_time]} {
      if {[info exists show_time]} {
        regexp {\[TIME\](.*?)\[/TIME\]} $show_day gottime time
        regexp {(\[TIME\].*?\[TIME\])} $show_day gottime shows
        regsub {(\[TIME\].*?\[TIME\])} $show_day "\[TIME\]" show_day   
        foreach line [split $shows "\n"] {
          if {[regexp {\[SHOW\](.*?)\[/SHOW\]} $line gotshow show]} {
            regexp {([A-Za-z 0-9@\:]+)\^([A-Za-z0-9 -\`\"\'\&:\.,]+)\^([0-9x]+)\^} $show t network show episode	            
            if {[info exists network] && [regexp $network $networks]} { append new_shows "--($network) $show - $episode \n" ; unset network show episode }
					}
        }
				if {[info exists new_shows]} {
				  if {$time_offset != 0} { set time [strftime {%I:%M %p} [chng_time [clock scan $time]]]}
					putquick "PRIVMSG [set $location] :-$time"	; foreach line [split $new_shows "\n"] { if {$line != ""} {putquick "PRIVMSG [set $location] :$line"}}
				  unset new_shows
	    	}
      }
    }
  }
}

proc tv:next {nick host hand chan arg} {
  global time_offset tv_time
	set arg [string map { " " "%20" } $arg]
  set url "http://services.tvrage.com/tools/quickinfo.php?show=$arg"
  set page [tv:web2data $url]
  if {$page == "timeout"} { putserv "PRIVMSG $chan :TVRage has timed out. Please try again in a few minutes"
	} elseif {$page == 0 || $page == ""} { putserv "PRIVMSG $chan :TVRage services are currently down"
  } else {
    regexp {Show Name@([A-Za-z 0-9\&\':]+)} $page gotname show_name
    regexp {Next Episode@([0-9x]+)\^([A-Za-z0-9 -\`\"\'\&:.,]+)\^([A-Za-z0-9/]+)} $page gotnext next_ep next_ep_title next_ep_date
		regexp {Airtime@([A-Za-z, 0-9:]+)} $page gotairtime show_airtime
		regexp {Network@([A-Za-z 0-9\!@\:]+)} $page gotnetwork show_network
		regexp {[0-9]+\:([0-9]+).*?([A-Za-z]+)} $show_airtime time
    regexp {RFC3339@([A-Za-z 0-9-]+[0-9:]+)} $page gotrfc show_rfc
    if {$time_offset != 0} { set show_airtime [tv:time  $next_ep_date $time] }
		if {[info exists show_rfc]} {
			if {$tv_time == "on"} {
				set show_date_time [chng_time [clock scan "$next_ep_date $time" -format {%b/%d/%Y %I:%M %p}]]
				set sec [clock seconds]
				set airing "- [duration [expr {$show_date_time - $sec}]] from now"
			} else { set airing "" }
			putquick "PRIVMSG $chan :$show_name - $next_ep $next_ep_title - Airs: $next_ep_date - $show_airtime on $show_network $airing"
    } elseif {![info exists show_name]} { putquick "PRIVMSG $chan :No Such Show!"
    } else { putquick "PRIVMSG $chan :The next episode of $show_name is not yet scheduled." }
  }
}
proc tv:last {nick host hand chan arg} {
	global time_offset
  set arg [string map { " " "%20" } $arg]
  set url "http://services.tvrage.com/tools/quickinfo.php?show=$arg"
  set page [tv:web2data $url]
  if {$page == "timeout"} { putserv "PRIVMSG $chan :TVRage has timed out. Please try again in a few minutes"
	} elseif {$page == 0 || $page == ""} { putserv "PRIVMSG $chan :TVRage services are currently down"
  } else {
    regexp {Show Name@([A-Za-z 0-9\&\':]+)} $page gotname show_name
    regexp {Latest Episode@([0-9x]+)\^([A-Za-z0-9 -\`\"\'\&:\.,]+)\^([A-Za-z0-9/]+)} $page gotlatest latest_ep latest_ep_title latest_ep_date
		regexp {Airtime@([A-Za-z, 0-9:]+)} $page gotairtime show_airtime
		regexp {Network@([A-Za-z 0-9\!@\:]+)} $page gotnetwork show_network
		regexp {[0-9]+\:([0-9]+).*?([A-Za-z]+)} $show_airtime time
    if {![info exists show_name]} { putquick "PRIVMSG $chan :No Such Show!"
    } else {
			if {$time_offset != 0} { set latest_ep_date [tv:time $latest_ep_date $time] }
			putquick "PRIVMSG $chan :$show_name - $latest_ep $latest_ep_title - Aired: $latest_ep_date - $show_airtime on $show_network"
	  }
	}
}
proc tv:summary {nick host hand chan arg} {
	set ep ""
	regexp {[Ss]?([1-9]+[XxEe][0-9]+)} $arg => ep
	regsub {[Ss]?([1-9]+[XxEe][0-9]+)} $arg "" arg
	set arg [string map { " " "%20" } [string trim $arg]]
	if {[info exists ep]} { set ep [string map {"e" "x" "s" "" } $ep] ; set url "http://services.tvrage.com/tools/quickinfo.php?show=$arg&ep=$ep"
	} else { set url "http://services.tvrage.com/tools/quickinfo.php?show=$arg" }
	set page [tv:web2data $url]
  if {$page == "timeout"} { putserv "PRIVMSG $chan :TVRage has timed out. Please try again in a few minutes"
	} elseif {$page == 0 || $page == ""} { putserv "PRIVMSG $chan :TVRage services are currently down"
  } else {
    regexp {Show Name@([A-Za-z 0-9\&\':]+)} $page gotname show_name
		regexp {Show URL@http://www.tvrage.com/([A-Za-z_0-9/-]+)} $page goturl show_url
		if {![info exists show_name]} { putserv "PRIVMSG $chan :No Such Show!"
    } else {
			regexp {Episode URL@http://www.tvrage.com/([A-Za-z_0-9/-]+)} $page => ep_url			
			regexp {Episode Info@([0-9x]+)\^} $page => ep
			if {[info exists ep_url]} { set page [tv:web2data "http://www.tvrage.com/$ep_url"]
			} else { set page [tv:web2data "http://www.tvrage.com/$show_url"] }
			regexp {show_synopsis['|"]>(.*?)<\/div>} $page a sum
			regsub -all {(<script.*?<\/script>)} $sum "" summary
		  regsub {<b>Source: <\/b>.*?<br>} $summary "" summary
			regsub -all {(<.*?>)} $summary "" summary
			set summary [string trim $summary]
			if {[string length $summary] > 300} { set summary "[string range $summary 0 300] ..." }
			if {[info exists ep_url]} { set url $ep_url } else { set url $show_url }
			if {![info exists summary]} { putquick "PRIVMSG $chan :There is no show summary for $show_name $ep"
			} else { putquick "PRIVMSG $chan :Summary of $show_name $ep: [string trim $summary] : http://www.tvrage.com/$url" }
		}
	}
}

proc tv:web2data {website} {
	package require http
	if { [catch { set token [http::geturl $website -timeout 500000]} error] } {  return 0
	} elseif { [http::ncode $token] == "404" } { return 0
	} elseif { [http::status $token] == "ok" } { set data [http::data $token]
	} elseif { [http::status $token] == "timeout" } {  return "timeout"
	} elseif { [http::status $token] == "error" } {  return 0 }
	http::cleanup $token
	if { [info exists data] } { return $data
	} else { return 0 }
}

proc chng_time {temptime} {  
	global time_offset
	if {[string index $time_offset 0] == "+" || ( [string index $time_offset 0] == "-" )} {
		set offset_type [string index $time_offset 0]
		set offset [string range $time_offset 1 end]
		if {[string is integer -strict $offset] && $offset != 0} { set temptime [expr $temptime $offset_type [expr $offset * 3600]]}
	}     
	return $temptime     
}
proc tv:timechange {hand idx arg} {
	global time_offset
	if {$arg == 0} { set time_offset $arg ; putdcc $idx "Time offset changed to: $arg for TVRage"
	}	elseif {[string index $arg 0] == "+" || ( [string index $arg 0] == "-" )} {
		set offset [string range $arg 1 end]
		if {[string is integer -strict $offset] && $offset != 0} { set time_offset $arg ; putdcc $idx "Time offset changed to: $arg for TVRage" }
	}
}
proc tv:help {hand idx arg} {
	putdcc $idx "Commands for TVRage Bot"
	putdcc $idx "Channel Commands"
	putdcc $idx "!tv <show>"
	putdcc $idx "!next/!last <show>"
	putdcc $idx "!today/!tomorrow"
	putdcc $idx "!sum <show> (seasonXepisode)"
	putdcc $idx "Partyline Commands"
	putdcc $idx ".timechange (+/- 0-12)"
	putdcc $idx ".airing"
	putdcc $idx ".schedule"
}
proc tv:time {date time } {
	return  [strftime {%A at %I:%M %p}] [chng_time [clock scan "$date $time" -format {%b/%d/%Y %I:%M %p}]]]
	
}
proc tv:duration {hand idx arg} {
	global tv_time
  if {$tv_time == "on"} { set tv_time "off"
  } else { set tv_time "on" } 
  putdcc $idx "Airing in has been turned: $tv_time"
}
proc tv:schedule {hand idx arg} {
	global location
  if {$location == "chan"} { set location "nick"
  } else { set location "chan" } 
  putdcc $idx "Schedule will now be sent to: $location"
}

putlog "TVRage v2.4"