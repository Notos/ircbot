#    __          ___
#   |__|.-----..'  _|.-----..-----..-----..-----.
#   |  ||     ||   _||  _  ||  -__||  _  ||  _  |
#   |__||__|__||__|  |_____||_____||___  ||___  |
#                                  |_____||_____|
#                              version 1.3
#                              www.zeen.co.uk
#                              goatqueen@zeen.co.uk
#                              Darren Moore - February 22th 2001
#                              irc.zirc.org

# Version Information
#	1.0 - Loads of bugs, not many features
#	1.1 - Most bugs ironed out
#	      Can delete/alter variables
#	      Tagging variables for picking up 'wtf' 'what' etc...
#	      Karma crap added
#	      Tell <nick> <question>? Added
#	      Word file made better and moved
#	1.2 - Lock words so they can't be set
#	      Tagging is allowed to anyone
#	      Little vital bugs fixed
#	      Extra variables e.g. $animal and $date are more efficient
#	      Random responses, x is a|b|c|d
#	      $nick Chooses a random nick out of the channel "gay is <reply> I'd guess $nick is gay"
#	      Fixed a return problem, no more dysyncing db!
#	1.3 - No change/Free, this 'locks' the word so it can't be changed (need o)
#	      
#	      
#	      
#	      
#	      

### UPDATE!
# I have smashed, bashed this around. I have let hackers loose on the bot and
# they can't 'hack' me little bot :)
# Have a churn at it and tell me if you manage to exploit anything.
###

##############
#
# infoegg - Based on infobot
# 
# Infoegg talks, reacts just like infobot, it was actually based on the infobot.
# I was getting sick of using infobot's because I could not find it easy to configure
# so I looked at some learn scripts for eggdrops, they where all crap! I mean they
# weren't smart at all so I thought of making an eggdrop version of infobot, here it is!
# 
# I'm still working on bits of this script like status and date but I don't really
# like TCL that much and can't find any real good resources, maybe I'll have to go
# and buy a manual if this script is successful :P
# 
# This bot learns from things like 'dtr is a queer' and if someone says dtr? it will say
# 'i heard dtr is a queer'. The database is just a basic list separated with '=>' just
# like infobot infopacks so you can import these in! l33t :)
# 
# If it learns words like 'this' 'that' 'why' then type 'lock this' etc.. cause then the
# word can't be used.
#
# Hellos and thanks go out to:
# Popeye, DTR, SmuDgeR, Ubu, Ed, Trax, Houlie, Pongyi + anyone else
#
# E-Mail me with suggestions and comments - zeen@zeen.co.uk
#
##############


#############
# set factoid: 				'x is y'      
# random factoid:			'x is a|b|c|d'
# accessing factoid: 			'what is x?' - or just 'x?'
# delete factoid:			'forget x'			(need o)
# append factoid:			'x is also y'
# changing factoid:			'no, x is y'
# disable factoid (loose):		'tag x'
# lock factoid (so it can't be used):	'lock x'			(need o)
# unlock factoid:			'unlock x'			(need o)
# nochange factoid:			'nochange x'			(need o)
# disable nochange:			'free x'			(need o)
# alter factoid:			'x =~ s/a/b/'
# tell factoid:				'tell nick x?'
#
# access karma:				'karma for x?' - or '<karma> x?'
# increase karma:			'x++'
# decrease karma:			'x--'
# set karma:				'karma set x 1'
# reset karma:				'karma reset x'
#############

# Please change the details below (to work in all channels leave it blank!)
set infoegg_version "v1.2"
set infoegg_chans ""
set infoegg_flood 0
set botsnick "earthtone"
set wordfile "scripts/infoegg-words.txt"


### Don't need to touch the stuff below this line

putlog "infoegg $infoegg_version loaded successfully"

bind pubm - "*\\\!" infoegg_question
bind pubm - "*\\\?" infoegg_question
proc infoegg_question {nick host hand chan text} {
	global botsnick
	global wordfile
	global infoegg_flood
	global infoegg_chans
	global infoegg_version
	
	if {(([lsearch -exact [string tolower $infoegg_chans] [string tolower $chan]] != -1) || ($infoegg_chans == "")) && ([string match "*\\\?" $text] && [string length $text] != 1 || [string match "*\\\!" $text] && [string length $text] != 1)} {
		set getquestion_pos [llength $text]
		incr getquestion_pos -1
				
		regsub -all "\\\!" $text "" text
		set start [lindex $text 0]
		set getquestion [string trimright [lindex $text $getquestion_pos] ?]
		set getquestion2 [string trimright [lrange $text 0 $getquestion_pos] ?]

		if {$getquestion == "me?"} { set getquestion $nick }
		
		putlog "!Learn! Question asked by $nick in $chan :: $getquestion : $getquestion2"
		
		## get it asking twice, 2nd time with 2 words
		
		set lquestion $getquestion2
		
		if {$lquestion == "infoegg" || $lquestion == "infobot"} {
			set question "<reply> Infoegg $infoegg_version for eggdrops created by zeen (zeen@zeen.co.uk), www.zeen.co.uk"
		} elseif {$lquestion == "status"} {
			#set infoegg_lines 0
			#set fh [open $wordfile r]
			#	set returnword {}
			#	while {![eof $fh]} { incr infoegg_lines 1 }
			#close $fh
			putlog "!Learn! Status";
			set question "Current Factoids: $infoegg_lines"
		} else {
			set question [infoegg_get_word $getquestion2]
		}
		
		if {$question == "" && $getquestion2 != $getquestion} { 
			set lquestion $getquestion
			set question [infoegg_get_word $getquestion]
		}
		
		if {[lindex $question 0] == "!"} {
			# Strip nochange ! char
			set question [string range $question 2 [string length $question]]
		}
		
		regsub -all "\{" $question "" question
		regsub -all "\}" $question "" question
		
		regsub -all "\\\$who" $question $nick question
		regsub -all "\\\$date" $question "[ctime [unixtime]]" question
		regsub -all "\\\$month" $question "[infobot_month]" question
		regsub -all "\\\$day" $question "[infobot_day]" question
		regsub -all "\\\$animal" $question "[infobot_animal]" question
		regsub -all "\\\$nick" $question "[infobot_nick $chan]" question
		
		# Random Seed
		set israndom [lsearch -exact $question "|"]
		if {$israndom != -1} { set question "[infobot_randq $question]" }
		#############


		set sendto $chan
		if {$start == "tell"} {
			set nwhom [lsearch -exact $text "tell"] 
			set grabsend [lindex $text [expr $nwhom +1]]
			if {$grabsend != ""} {
				set sendto $grabsend
			}
		}
		
		if {$question != "" && $question != "`" && $question != "~"} {
			set randno [rand 10]
			
			set getstart [lindex $question 0] 
			set getrest [lrange $question 1 end] 
			
			if {$getstart == "<reply>"} {  
				putserv "PRIVMSG $sendto :$getrest"
			} elseif {$getstart == "<action>"} {  
				putserv "PRIVMSG $sendto :\001ACTION $getrest\001"
			} else {
				if {$randno == "0"} { set randmsg "I heard that $lquestion is $question" }
				if {$randno == "1"} { set randmsg "$lquestion is $question" }
				if {$randno == "2"} { set randmsg "It's been said that $lquestion is $question" }
				if {$randno == "3"} { set randmsg "Someone said that $lquestion is $question" }
				if {$randno == "4"} { set randmsg "$lquestion is probably $question" }
				if {$randno == "5"} { set randmsg "I guess $lquestion is $question" }
				if {$randno == "6"} { set randmsg "Hmmm. I think $lquestion is $question" }
				if {$randno == "7"} { set randmsg "I'm sure $lquestion is $question" }
				if {$randno == "8"} { set randmsg "I guess $lquestion is $question" }
				if {$randno == "9"} { set randmsg "Well, $lquestion is $question" }
				if {$randno == "10"} { set randmsg "I think $lquestion is $question" }
				putserv "PRIVMSG $sendto :$randmsg"
			}
		} elseif {$start == "$botsnick,"} {
			set randno [rand 5]			
			if {$randno == "0"} { set randmsg "No idea $nick!" }
			if {$randno == "1"} { set randmsg "God knows $nick!" }
			if {$randno == "2"} { set randmsg "Got no idea $nick" }
			if {$randno == "3"} { set randmsg "I don't know $nick" }
			if {$randno == "4"} { set randmsg "Really don't know $nick" }
			if {$randno == "5"} { set randmsg "Fook knows" }
			putserv "PRIVMSG $sendto :$randmsg"
		}

	}
}

proc infoegg_resetflood {} {
	global infoegg_flood
	set infoegg_flood 0
}

bind pubm - "* is *" infoegg_learn
proc infoegg_learn {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	
	# fuck colours, underline and bold! no need, look ugly
	regsub -all \02 $text "" text
	regsub -all \031 $text "" text
	regsub -all \03 $text "" text
	
	#############
	regsub -all "\{" $text "" text
	regsub -all "\}" $text "" text
	#############
	
	if {[lsearch -exact $text \n] != -1} { 
		# Fix the break return bug
		putserv "PRIVMSG $chan :String cannot have returns!";
	} else {


		set type [lsearch -exact $text "is"]
		if {$type != "-1"} { 
			set type "is"
		} {
			set type "are"
		}

		set nwhom [lsearch -exact $text "$type"]
		set whatis [lrange $text 0 [expr $nwhom - 1]]
		set whatis2 [lrange $text [expr $nwhom + 1] end]
		set also [lindex $text [expr $nwhom + 1]]

		# replace a few things
		regsub -all "my" $whatis2 "$nick's" whatis2
		regsub -all "i am" $whatis2 "$nick is" whatis2

		set start [lindex $text 0]
		set question {}
		set orginal {}

		if {$start == "no,"} {
			set whatis [lrange $whatis 1 end]
			set orginal [infoegg_get_word $whatis]
			if {$orginal != "~" && [lindex $orginal 0] != "!"} {
				infoegg_del_word $whatis
			}
		} elseif {$also == "also"} {
			set question [infoegg_get_word $whatis]
			if {$question != ""} {
				infoegg_del_word $whatis
				set whatis2 "$question and also [lrange $whatis2 1 end]"
				putlog "!Learn! Also used by $nick"
				set question {}
			}
		} else {
			set question [infoegg_get_word $whatis]
		}

		if {$question == "" && $orginal != "~" && [lindex $orginal 0] != "!" && [string length $whatis] >= 3 && [string length $whatis] <= 15}  { 
			infoegg_add_word $whatis $whatis2
			putlog "!Learn! Word Added: $whatis => $whatis2"
			if {$start == "no," || $start == "tag,"} { putserv "PRIVMSG $chan :Ok $nick" }
		} elseif {[string length $whatis] <= 3} {
			if {$start == "no," || $start == "tag,"} { putserv "PRIVMSG $chan :String too short $nick!" }
		} elseif {[string length $whatis] >= 15} {
			if {$start == "no," || $start == "tag,"} { putserv "PRIVMSG $chan :String too long $nick!" }
		}
	}
}

bind pubm - "* \\\=\\\~ *" infoegg_alter
proc infoegg_alter {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text

	regsub -all " s/" $text " " text
	regsub -all "/" $text " / " text
	set fseperator [lsearch -exact $text "=~"]
	set seperator [lsearch -exact $text "\/"]
	
	set alterstring [lrange $text 0 [expr $fseperator -1]]
	set alterwhat [lrange $text 2 [expr $seperator -1]]
	set alterwith [lrange $text [expr $seperator +1] end]
	regsub -all " /" $alterwith "" alterwith
	
	set question [infoegg_get_word $alterstring]
	set searchforwhat [lsearch -exact $question $alterwhat]
		
	if {$question == "~" || $question == "`"} {
		putserv "PRIVMSG $chan :This variable has been locked/tagged $nick!"
		
	} elseif {[lindex $question 0] == "!"} {
		putserv "PRIVMSG $chan :This variable has been set as nochange $nick!"
		
	} elseif {$question == ""} {
		putserv "PRIVMSG $chan :There's no variable set in the first place $nick!"
		
	} elseif {$searchforwhat == "-1"} {
		putserv "PRIVMSG $chan :$alterwhat doesn't exist in $alterstring!"
		
	} else {
		regsub -all $alterwhat $question $alterwith result
		infoegg_del_word $alterstring
		infoegg_add_word $alterstring $result
		putlog "!Learn! Alter: $question /is now/ $result"
		putserv "PRIVMSG $chan :Ok $nick, $alterstring is altered"
	}
}

bind pub o "nochange" infoegg_nochange
proc infoegg_nochange {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	set nwhom [lsearch -exact $text "nochange"]
	set tagwhat [lrange $text [expr $nwhom + 1] end]
	
	set answer [infoegg_get_word $tagwhat]
		
	if {[lindex $answer 0] == "!"} {
		putserv "PRIVMSG $chan :This word has already been nochanged $nick"
	} elseif {$tagwhat != ""} {
		infoegg_del_word $tagwhat
		infoegg_add_word $tagwhat "! $answer"
		putserv "PRIVMSG $chan :Ok $nick, $tagwhat has been set as nochange"
	} {
		putserv "PRIVMSG $chan :Enter a word to be nochanged $nick"
	}
}

bind pub o "free" infoegg_free
proc infoegg_free {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	set nwhom [lsearch -exact $text "free"]
	set tagwhat [lrange $text [expr $nwhom + 1] end]
	
	set answer [infoegg_get_word $tagwhat]
	set answer [string range $answer 2 [string length $answer]]
	
	if {$tagwhat != ""} {
		if {$answer == ""} {
			putserv "PRIVMSG $chan :Nothing to free $nick!"
		} {
			infoegg_del_word $tagwhat
			infoegg_add_word $tagwhat "$answer"
			putserv "PRIVMSG $chan :Ok $nick, $tagwhat has been freed"
		}
	} {
		putserv "PRIVMSG $chan :Enter a word to be freed $nick"
	}
}

bind pub - "tag" infoegg_tag
proc infoegg_tag {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	set nwhom [lsearch -exact $text "tag"]
	set tagwhat [lrange $text [expr $nwhom + 1] end]
	
	set answer [infoegg_get_word $tagwhat]
	
	
	if {[lindex $answer 0] == "!"} {
		putserv "PRIVMSG $chan :This word has been set as nochange $nick"
	} elseif {$tagwhat != ""} {
		infoegg_del_word $tagwhat
		infoegg_add_word $tagwhat "`"
		putlog "!Learn! Tagged $tagwhat"
		putserv "PRIVMSG $chan :Ok $nick, $tagwhat tagged"
	} {
		putserv "PRIVMSG $chan :Enter a word to be tagged $nick"
	}
}

bind pub o "lock" infoegg_lock
proc infoegg_lock {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	set nwhom [lsearch -exact $text "lock"]
	set lockwhat [lrange $text [expr $nwhom + 1] end]
	
	set answer [infoegg_get_word $lockwhat]
	if {[lindex $answer 0] == "!"} {
		putserv "PRIVMSG $chan :This word has been set as nochange $nick"
	} elseif {$lockwhat != ""} {
		infoegg_del_word $lockwhat
		infoegg_add_word $lockwhat "~"
		putlog "!Learn! Locked $lockwhat"
		putserv "PRIVMSG $chan :Ok $nick, $lockwhat locked"
	} {
		putserv "PRIVMSG $chan :Enter a word to be locked $nick"
	}
}

bind pub o "unlock" infoegg_unlock
proc infoegg_unlock {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	set nwhom [lsearch -exact $text "unlock"]
	set lockwhat [lrange $text [expr $nwhom + 1] end]
	
	set answer [infoegg_get_word $lockwhat]
	if {[lindex $answer 0] == "!"} {
		putserv "PRIVMSG $chan :This word has been set as nochange $nick"
	} elseif {$lockwhat != ""} {
		infoegg_del_word $lockwhat
		putlog "!Learn! UnLocked $lockwhat"
		putserv "PRIVMSG $chan :Ok $nick, $lockwhat unlocked"
	} {
		putserv "PRIVMSG $chan :Enter a word to be unlocked $nick"
	}
}

bind pub o "forget" infoegg_forget
proc infoegg_forget {nick host hand chan text} {
	global botsnick
	regsub -all "$botsnick, " $text "" text
	set nwhom [lsearch -exact $text "forget"]
	set forgetwhat [lrange $text [expr $nwhom + 1] end]
	set question [infoegg_get_word $forgetwhat]

	if {[lindex $question 0] == "!"} {
		putserv "PRIVMSG $chan :This word has been set as nochange $nick"
	} elseif {$question == ""} {
		putserv "PRIVMSG $chan :'$forgetwhat' not found $nick!"
	} elseif {$forgetwhat != "" || [llength $forgetwhat] > 3} {
		infoegg_del_word $forgetwhat
		putserv "PRIVMSG $chan :Ok $nick"
	} else {
		putserv "PRIVMSG $chan :$nick set a forget or make it longer!"
	}
}


bind pub - "karma" karma_info
proc karma_info {nick host hand chan text} {
	global botsnick
	set karma_action [lindex $text 0]
	regsub -all "\\\?" $text "" text
	set karma [lindex $text 1]
	if {$karma == "me"} { set karma $nick }

	if {$karma == ""} {
			putserv "PRIVMSG $chan :You have not entered a karma option 'karma for/set/reset'"
	} elseif {$karma_action == "for"} {
		set answer [infoegg_get_word "<karma> $karma"]
		if {$answer == "" || $answer == "0"} {
			putserv "PRIVMSG $chan :$karma has neutral karma"
		} {
			putserv "PRIVMSG $chan :$karma has karma of $answer"
		}
	} elseif {$karma_action == "set"} {
		set karma_setas [lindex $text 2]
		if {$karma == $nick} {
			putserv "NOTICE $nick :please don't karma yourself"
		} elseif {$karma_setas != ""} {
			putlog "!Karma! $karma been changed to $karma_setas"
			infoegg_del_word "<karma> $karma"
			infoegg_add_word "<karma> $karma" $karma_setas
			putserv "PRIVMSG $chan :$karma has now been set to $karma_setas"
		} {
			putserv "PRIVMSG $chan :You have not entered a set value! 'karma set <karma> <new value>'"
		}
	} elseif {$karma_action == "reset"} {
		if {$karma == $nick} {
			putserv "NOTICE $nick :please don't karma yourself"
		} else {
			infoegg_del_word "<karma> $karma"
			infoegg_add_word "<karma> $karma" ""
			putserv "PRIVMSG $chan :$karma has been reset"
		}
	}
}


bind pubm - "*\-\-" karma_action
bind pubm - "*\+\+" karma_action
proc karma_action {nick host hand chan text} {
	global botsnick
	regsub -all "\\\+\\\+" $text " \+\+" text
	regsub -all "\\\-\\\-" $text " \-\-" text
	set karma [lindex $text 0]
	set question [infoegg_get_word "<karma> $karma"]

	if {$karma == "me"} { set karma $nick }
		
	if {$question == ""} {
		infoegg_add_word "<karma> $karma" 0
		putlog "!Karma! $karma set to 0"
	} elseif {[string tolower $karma] == [string tolower $nick]} {
                putserv "NOTICE $nick :please don't karma yourself"
        } else {
		if {[lsearch -exact $text "\+\+"] == -1} {
			incr question -1
		} {
			incr question 1
		}
		infoegg_del_word "<karma> $karma"
		infoegg_add_word "<karma> $karma" $question
		putlog "!Karma! $karma set to $question"
	}
}


proc infoegg_add_word {keyword sayback} {
	global botsnick
	global wordfile
	set fh [open $wordfile a]
	puts $fh "$keyword => $sayback"
	close $fh
}

proc infoegg_get_word {keyword} {
	global botsnick
	global wordfile
	set fh [open $wordfile r]
	set returnword {}
	while {![eof $fh]} {
		set stdin [string trim [gets $fh]]
		if {[eof $fh]} { break }
		set breaker [lsearch -exact $stdin "=>"]
		set getkey [lrange $stdin 0 [expr $breaker - 1]] 
		set getresult [lrange $stdin [expr $breaker + 1] end]
		if {[string tolower $getkey] == [string tolower $keyword]} { set returnword $getresult }
	}
	close $fh
 	return $returnword
}

proc infoegg_del_word {word} {
	global botsnick
	 global wordfile
	 set fh [open $wordfile r]
	 set return {}
	 set del 0
	 while {![eof $fh]} {
		set stdin [string trim [gets $fh]]
		if {[eof $fh]} { break }
		if {![regexp -nocase $word $stdin]} {
			lappend return $stdin
		} {
			incr del 1
		}
	 }
	 close $fh;
	 set fh [open $wordfile w]
	 foreach a $return {
	  puts $fh $a
	 }
	 close $fh
	 return $del
}

proc infobot_animal {} {
	set randanimal {
		"goat"
		"llama"
		"lemming"
		"hamster"
		"penguin"
		"goat"
		"bear"
		"emu"
		"donkey"
		"cat"
		"dog"
		"monkey"
		"eel"
		"monkey faced eel"
		"iguana"
		"hippo"
		"bull"
		"cow"
		"duck"
		"zebra"
		"giraffe"
	}
   	return [lindex $randanimal [rand [llength $randanimal]]]
}

proc infobot_day {} {
	set randday {
		"Monday"
		"Tuesday"
		"Wednesday"
		"Thursday"
		"Friday"
		"Saturday"
		"Sunday"
	}
   	return [lindex $randday [rand [llength $randday]]]
}

proc infobot_nick {chan} {  	
   	set randn [lindex [split [chanlist "$chan"]] [rand [llength [split [chanlist "$chan"]]]]]
   	return $randn
}


proc infobot_month {} {
	set randmonth {
		"January"
		"February"
		"March"
		"April"
		"May"
		"June"
		"July"
		"August"
		"September"
		"October"
		"November"
		"December"
	}
   	return [lindex $randmonth [rand [llength $randmonth]]]
}

proc infobot_randq {text} {
	regsub -all "\\|" $text "\t" text
   	set randq [lindex [split $text \t] [rand [llength [split $text \t]]]]
   	return $randq
}

