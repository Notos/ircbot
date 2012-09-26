###############################################################################
# holdem.tcl version 1.0                                                      #
# Copyright 2011 Steve Church (rojo on EFnet). All rights reserved.           #
#                                                                             #
# Salt the settings below to taste, load the script, rehash,                  #
# .chanset #channel +holdem, then !holdem to play.  It's not rocket surgery.  #
#                                                                             #
# A note about Unicode / UTF-8: If your bot is compiled with UTF-8 support    #
# (see http://eggwiki.org/Utf-8 for details) and you set settings(unicode) 1, #
# cards are displayed with their suits as extended characters.  If players in #
# your channel are not using a modern, updated IRC client; rather than seeing #
# suits as intended, they may just see garbage.  More information for mIRC    #
# UTF-8 support is available at http://www.mirc.net/newbie/unicode.php .  If  #
# your users use Mibbit, they'll probably see Unicode characters just fine.   #
# Users using any other IRC client are probably intelligent enough to figure  #
# out how to handle UTF-8 on their own.                                       #
#                                                                             #
# Thanks to the unnaturally lucky Sunset, Trex, turgsh01, and the rest of the #
# EFnet #arcade group for helping me squash bugs.  If you find more bugs,     #
# please report them to rojo on EFnet.                                        #
#                                                                             #
# License                                                                     #
#                                                                             #
# Redistribution and use in source and binary forms, with or without          #
# modification, are permitted provided that the following conditions are met: #
#                                                                             #
#   1. Redistributions of source code must retain the above copyright notice, #
#      this list of conditions and the following disclaimer.                  #
#                                                                             #
#   2. Redistributions in binary form must reproduce the above copyright      #
#      notice, this list of conditions and the following disclaimer in the    #
#      documentation and/or other materials provided with the distribution.   #
#                                                                             #
# THIS SOFTWARE IS PROVIDED BY STEVE CHURCH "AS IS" AND ANY EXPRESS OR        #
# IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES   #
# OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN  #
# NO EVENT SHALL STEVE CHURCH OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,       #
# INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES          #
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR          #
# SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER  #
# CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT          #
# LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY   #
# OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH #
# DAMAGE.                                                                     #
###############################################################################

namespace eval holdem {

set settings(udef-flag) holdem  ;# .chanset #channel|* +holdem
set settings(buy-in) 250        ;# amount of money each player starts with
set settings(small-blind) 5     ;# forced bet for the small blind
set settings(big-blind) 10      ;# forced bet for the big blind
set settings(denomination) \$   ;# dollars / euros / pounds / whatever
set settings(timeout) 60        ;# seconds to wait before starting 1st round / timing out a player
set settings(double-at-round) 5 ;# double the values of the blinds every x rounds
set settings(confidence) 5      ;# audacity of the bot for bluffing and so forth (0-10 = less to more aggressive)
set settings(unicode) 1         ;# is your eggdrop patched to handle utf-8 extended characters?  http://eggwiki.org/Utf-8
set settings(ignore-flags) bkqr|kqr
set settings(triggers) {!holdem !th !texas !texasholdem !the}
set settings(stop-triggers) {!stop !end !endgame !stfu !quiet}
# card colors:
# 00 white          08 yellow
# 01 black          09 light green (lime)
# 02 blue (navy)    10 teal (a green/blue cyan)
# 03 green          11 light cyan (cyan) (aqua)
# 04 red            12 light blue (royal)
# 05 brown (maroon) 13 pink (magenta)
# 06 purple         14 gray
# 07 orange (olive) 15 light gray (silver)

# xx,yy foreground,background
set settings(hearts-color) 04,00
set settings(diamonds-color) 00,04
set settings(spades-color) 01,00
set settings(clubs-color) 00,14

set settings(diversions) {
	"relace his shoes"
	"sulk in the kitchen"
	"get more beer from the gas station"
	"look at porn"
	"play Mario Kart"
	"hit on the girl next door"
	"fire his spud gun from the back porch"
	"check his email"
	"check on the steaks"
	"find a bathroom"
	"walk his dog"
	"work on some coding"
	"change his pants"
	"sniff some glue"
	"lick himself"
}
set settings(bot-players) {
	"Ezmirelda McGillicuddy"
	"Mr. Croup"
	"Mr. Vandemar"
	"Oliver Close-Auff"
	"Popeye the Vegan"
	"Mr. Pink"
	"that little Asian kid"
	"Walt Sisname"
	"Four Finger Joe"
	"One-Eyed Pete"
	"The Snoot"
	"my cleaning lady"
	"my next door neighbor"
	"the ginger kid"
	"Mr. Miyagi"
	"Mr. Flibble"
	"Professor Farnsworth"
	"Buzz Lightyear"
	"Rocket Girl"
	"Trapper Keeper"
	"Pippi No-stockings"
	"Mrs. Phipps"
	"the mail man"
	"Harry Cooter"
}

#########################
# end of user variables #
#########################

set scriptver "1.0"
set settings(verbose) 0			;# enable additional putlogs for development
variable settings
variable hands
variable ns [namespace current]

array set hand_name {
	0 {a high card}
	1 {a pair}
	2 {two pair}
	3 {three of a kind}
	4 {a straight}
	5 {a flush}
	6 {a full house}
	7 {four of a kind}
	8 {a straight flush}
}

variable hand_name

foreach t $settings(triggers) {
	bind pub * $t ${ns}::start
}

foreach t $settings(stop-triggers) {
	bind pub * $t ${ns}::stfu
}

if {[info exists settings(udef-flag)] && [string length $settings(udef-flag)]} {
	setudef flag $settings(udef-flag)
}

variable newdeck [list]
foreach suit {H D S C} {
	for {set i 2} {$i < 15} {incr i} {
		lappend newdeck [list $i $suit]
	}
}

proc shuffle {lst {iter 0}} {
	variable settings
	set shuffled [list]
	while {[llength $lst]} {
		set draw [rand [llength $lst]]
		lappend shuffled [lindex $lst $draw]
		set lst [lreplace $lst $draw $draw]
	}
	incr iter
	if {$iter < 3} {
		return [shuffle $shuffled $iter]
	} { return $shuffled }
}

# thanks thommey!
proc is_patched {} { catch {queuesize \u0754} err; expr {[string bytelength $err] - 45} }

proc check_patched {} {
	variable settings
	if {$settings(unicode) && ![is_patched]} {
		set settings(unicode) 0
		putlog "This eggdrop is not patched for UTF-8 / unicode output.  Please see\
		http://eggwiki.org/Utf-8 for details.  For now, unicode output is disabled."
	}
}

proc render {card} {
	variable settings
	# $card is a 2-element list containing value and suit
	if {[lindex $card 0] == 1} { set card [lreplace $card 0 0 14] }
	switch [lindex $card 1] {
		H { set out "\003$settings(hearts-color)\[" }
		D { set out "\003$settings(diamonds-color)\[" }
		S { set out "\003$settings(spades-color)\[" }
		C { set out "\003$settings(clubs-color)\[" }
	}
	# Unicode / UTF-8 extended character support:
	# http://eggwiki.org/Utf-8
	if {$settings(unicode)} {
		# â.¥ \u2665  â.¦ \u2666  â.  \u2660  â.£ \u2663
		array set suits [list H \u2665 D \u2666 S \u2660 C \u2663]
		append out $suits([lindex $card 1])
		append out [string map {14 A 13 K 12 Q 11 J} [lindex $card 0]]
		if {![string equal [encoding system] utf-8]} { set out [encoding convertto utf-8 $out] }
	} else {
		array set suits {H Hearts C Clubs D Diamonds S Spades}
		append out [string map {14 Ace 13 King 12 Queen 11 Jack} [lindex $card 0]]
		append out " of "
		append out $suits([lindex $card 1])
	}
	switch [lindex $card 1] {
		H { append out "\]\003" }
		D { append out "\]\003" }
		S { append out "\]\003" }
		C { append out "\]\003" }
	}
	return $out
}

proc list2pretty {lst} {
	variable settings
	set last [lindex $lst end]
	set first [lreplace $lst end end]
	set first [join $first "\002, \002"]
	return "\002$first\002 and \002$last\002"
}

proc start {nick uhost hand chan txt} {
	variable settings; variable ns
	if {[matchattr $hand $settings(ignore-flags)]} { return }
	if {[info exists settings(udef-flag)] &&\
	[string length $settings(udef-flag)] &&\
	![channel get $chan $settings(udef-flag)]} { return }
	dict set settings($chan) players [list $nick]
	puthelp "PRIVMSG $chan :\001ACTION and $nick sit down at the card table and start dividing up chips, snacks and beer.\001"
	puthelp "PRIVMSG $chan :Who else wants to play?  Type \002!join\002 to play some Hold 'Em with us.  Type \002!play\002 to\
	start the game, or just wait $settings(timeout) seconds for the game to start automatically."
	bind pub * !join ${ns}::join_game
	bind pub * !play ${ns}::trigger_get_bot_players
	utimer $settings(timeout) [list ${ns}::get_bot_players $chan]
	if {$settings(unicode)} { utimer 5 ${ns}::check_patched }
}

proc stfu {nick uhost hand chan txt} {
	variable settings
	if {[matchattr $hand $settings(ignore-flags)]} { return }
	clearqueue help
	if {[info exists settings($chan)]} {
		puthelp "PRIVMSG $chan :OK, shutting up now."
	}
	stop $chan
}

proc stop {chan} {
	variable ns; variable settings
	catch {unbind pub * !join ${ns}::join_game}
	catch {unbind pub * !play ${ns}::trigger_get_bot_players}
	catch {unbind pubm * $chan* ${ns}::round_one}
	catch {unbind pubm * $chan* ${ns}::take_bet}
	catch {unbind pubm * $chan* ${ns}::keep_watching}
	foreach t [utimers] {
		if {[string match *$ns* [lindex $t 1]]} { killutimer [lindex $t 2] }
	}
	if {[info exists settings($chan)]} { unset settings($chan) }
}

proc join_game {nick uhost hand chan txt} {
	variable settings
	if {[matchattr $hand $settings(ignore-flags)]} { return }
	set players [dict get $settings($chan) players]
	if {[lsearch $players $nick] > -1} { return }
	dict lappend settings($chan) players $nick
	lappend players $nick
	if {[llength $players] == 2} {
		puthelp "PRIVMSG $chan :\001ACTION gives $nick his chair and goes off to\
		[lindex $settings(diversions) [rand [llength $settings(diversions)]]].\001"
	} elseif {[llength $players] == 8} {
		puthelp "PRIVMSG $chan :The table is now full.  On with the game."
		round_one $nick $uhost $hand $chan skip
	} else {
		puthelp "PRIVMSG $chan :\001ACTION passes $nick a beer and waits for the game to start.\001"
	}
}

proc get_next_player {chan b4 {iter 0}} {
	variable settings
	foreach var {players players_this_round has_bet} {
		set $var [dict get $settings($chan) $var]
	}
	if {[llength $has_bet] == [llength $players_this_round]} { return "" }

	if {$iter > [llength $players]} {
		putlog "Something's wrong.  has_bet: $has_bet; players_this_round: $players_this_round"
		return ""
	}

	set idx [lsearch -exact $players $b4]
	incr idx
	if {$idx == [llength $players]} { set idx 0 }
	set next [lindex $players $idx]
	if {[lsearch $players_this_round $next] < 0} { return [get_next_player $chan $next [incr iter]] }

	set cash [dict get $settings($chan) !$next cash]
	set bet [dict get $settings($chan) !$next bet]

	if {!$cash && !$bet} { return [get_next_player $chan $next [incr iter]] }

	return $next
}

proc trigger_get_bot_players {nick uhost hand chan txt} {
	get_bot_players $chan
}

proc get_bot_players {chan} {
	variable settings; variable ns
	global botnick
	foreach t [utimers] {
		if {[string equal [lindex $t 1] [list ${ns}::get_bot_players $chan]]} { killutimer [lindex $t 2] }
	}
	catch {unbind pub * !join ${ns}::join_game}
	catch {unbind pub * !play ${ns}::trigger_get_bot_players}
	set players [dict get $settings($chan) players]
	if {[llength $players] == 1} {
		dict set settings($chan) !$botnick confidence [expr {[rand $settings(confidence)] + 5}]
		lappend players $botnick
		puthelp "PRIVMSG $chan :[lindex $players 0]: I guess it's just you and me, then.  May I\
		deal a few imaginary friends in?  (How many more bot players in addition to myself?)"
	} else {
		puthelp "PRIVMSG $chan :[list2pretty $players] seem ready to play.  May I deal myself and\
		a few imaginary friends in?  (How many bot players?)"
	}
	dict set settings($chan) players $players
	bind pubm * $chan* ${ns}::round_one
}

proc round_one {nick uhost hand chan txt} {
	variable settings; variable ns
	set players [dict get $settings($chan) players]
	if {[lsearch $players $nick] == -1} { return }
	if {![regexp -nocase {\y(skip|no(t|ne)?|\d+)\y} $txt - match]} { return }
	catch {unbind pubm * $chan* ${ns}::round_one}
	if {![string equal $txt skip]} {
		if {![string is integer -strict $match]} { set match 0 }
		while {[expr {$match + [llength $players]}] > 8} { incr match -1 }
		if {$match} {
			set potential $settings(bot-players)
			for {set i 0} {$i < $match} {incr i} {
				set idx [rand [llength $potential]]
				lappend players [lindex $potential $idx]
				dict set settings($chan) ![lindex $potential $idx] confidence [expr {[rand $settings(confidence)] + 5}]
				set potential [lreplace $potential $idx $idx]
			}
		}
	}
	set players [shuffle $players]
	dict set settings($chan) players $players
	dict set settings($chan) players_this_round $players
	foreach p $players {
		dict set settings($chan) !$p cash $settings(buy-in)
		dict set settings($chan) !$p bet 0
	}
	set dealer [lindex $players [rand [llength $players]]]
	dict set settings($chan) dealer $dealer
	dict set settings($chan) has_bet [list]
	dict set settings($chan) round 0
	dict set settings($chan) sbvalue $settings(small-blind)
	dict set settings($chan) bbvalue $settings(big-blind)
	dict set settings($chan) folds 0
	set d $settings(denomination)
	clearqueue help
	puthelp "PRIVMSG $chan :We have our players.  Players sit in the following order: [list2pretty $players].  Each player starts with\
	$d$settings(buy-in).  Blinds are at $d$settings(small-blind) / $d$settings(big-blind)."
	deal $chan
}

proc get_diff {chan nick} {
	variable settings
	set bet [dict get $settings($chan) !$nick bet]
	set difference 0
	foreach p [dict get $settings($chan) players_this_round] {
		set bet_diff [expr {[dict get $settings($chan) !$p bet] - $bet}]
		if {$bet_diff > $difference} { set difference $bet_diff }
	}
	return $difference
}

proc deal {chan} {
	variable settings; variable newdeck; variable ns
	global botnick
	foreach var {players round dealer sbvalue bbvalue} {
		set $var [dict get $settings($chan) $var]
	}
	set players_this_round $players
	set d $settings(denomination)
	set out "PRIVMSG $chan :\00307Current standings:\003"
	foreach p $players {
		dict set settings($chan) !$p bet 0
		if {![set cash [dict get $settings($chan) !$p cash]]} {
			set idx [lsearch -exact $players_this_round $p]
			set players_this_round [lreplace $players_this_round $idx $idx]
		} else {
			append out "  \002$p\002 has \00306$d$cash\003."
		}
	}
	puthelp $out
	dict set settings($chan) players_this_round $players_this_round
	dict set settings($chan) checks 0
	if {$settings(verbose)} { putlog "dealing to players: $players_this_round" }
	set dealer [get_next_player $chan $dealer]

	if {[llength $players_this_round] == 2} {
		set sbplayer $dealer
	} {
		set sbplayer [get_next_player $chan $dealer]
	}
	set bbplayer [get_next_player $chan $sbplayer]
	foreach var {dealer sbplayer bbplayer players_this_round} {
		dict set settings($chan) $var [set $var]
	}
	set deck [shuffle $newdeck]
	set cards [list]
	set phase deal
	set has_bet [list]
	set skip_betting 0
	incr round
	if {[string equal $botnick $dealer]} { set dlr "I am" } { set dlr "\002$dealer\002 is" }
	set out "PRIVMSG $chan :\00304Round $round\003.  "
	if {!($round % $settings(double-at-round))} {
		incr sbvalue $settings(small-blind)
		set bbvalue [expr {$sbvalue * 2}]
		append out "\00307Blind values have been increased to \002$d$sbvalue\002 / \002$d$bbvalue\002.\003  "
	}
	dict set settings($chan) min_bet $bbvalue
	append out "$dlr dealing.  "
	if {[string equal $botnick $sbplayer]} { set dlr "I am" } { set dlr "\002$sbplayer\002 is" }
	append out "$dlr the small blind this round; "
	if {[string equal $botnick $bbplayer]} { set dlr "I am" } { set dlr "\002$bbplayer\002 is" }
	append out "$dlr the big blind.  Please wait...."
	puthelp $out
	set pot 0
	foreach p $players_this_round {
		set cash [dict get $settings($chan) !$p cash]
		set bet 0
		if {[string equal $p $bbplayer]} {
			if {$cash >= $bbvalue} {
				incr pot $bbvalue
				set bet $bbvalue
				incr cash -$bbvalue
			} {
				incr pot $cash
				set bet $cash
				set cash 0
			}
		} elseif {[string equal $p $sbplayer]} {
			if {$cash >= $sbvalue} {
				incr pot $sbvalue
				set bet $sbvalue
				incr cash -$sbvalue
			} {
				incr pot $cash
				set bet $cash
				set cash 0
			}
		}

		set cards [list [lindex $deck 0] [lindex $deck 1]]
		set deck [lreplace $deck 0 1]
		foreach val {bet cash cards} {
			dict set settings($chan) !$p $val [set $val]
		}
		set out "NOTICE $p :Your cards this round:"
		foreach c $cards {
			append out " [render $c]"
		}
		if {[string equal $p $botnick] || [lsearch -exact $settings(bot-players) $p] > -1} {
			if {$settings(verbose)} { putlog $out }
		} else {
			puthelp $out
		}
	}

	dict set settings($chan) deck $deck

	if {$settings(verbose)} { putlog "Players this round: $players_this_round" }
	foreach var {cards phase round sbvalue bbvalue pot players_this_round has_bet skip_betting} {
		dict set settings($chan) $var [set $var]
	}

	if {$settings(verbose)} { putlog "At the end of deal, players_this_round: $players_this_round" }

	if {[llength $players_this_round] == 2} {
		set next_player $dealer
	} {
		set next_player [get_next_player $chan $bbplayer]
	}

	dict set settings($chan) bet_round 0	
	dict set settings($chan) better $next_player
	return [prompt $chan $next_player]
}

proc prompt {chan player} {
	variable settings; variable ns
	global botnick
	if {[string equal $player [dict get $settings($chan) better]]} {
		dict incr settings($chan) bet_round
	}
	foreach var {players sbplayer bbplayer sbvalue bbvalue pot phase better has_bet players_this_round skip_betting bet_round min_bet} {
		set $var [dict get $settings($chan) $var]
	}

	set cash 0
	set bets 0
	foreach p $players {
		incr cash [dict get $settings($chan) !$p cash]
		incr bets [dict get $settings($chan) !$p bet]
	}
	set total [expr {$cash + $bets}]
	set started_with [expr {[llength $players] * $settings(buy-in)}]
	set d $settings(denomination)
	if {$total != $started_with} {
		puthelp "PRIVMSG $chan :1. Cash = $d$cash; Bets = $d$bets.  Total = $d$total.  $d$total != $d$started_with.  Stopping the game."
		stop $chan
	} elseif {$bets != $pot} {
		puthelp "PRIVMSG $chan :2. Bets = $d$bets.  Pot = $d$pot.  $d$bets != $d$pot.  Stopping the game."
		foreach p $players {
			putlog "$p bet: $d[dict get $settings($chan) !$p bet]"
		}
		stop $chan
	} else {
		set total [expr {$cash + $pot}]
		if {$total != $started_with} {
			puthelp "PRIVMSG $chan :3. Cash = $d$cash; Pot = $d$pot.  Total = $d$total.  $d$total != $d$started_with.  Stopping the game."
			stop $chan
		}
	}

	if {$skip_betting} { return [start_next_phase $chan] }

	set d $settings(denomination)

	set bet [dict get $settings($chan) !$player bet]
	set cash [dict get $settings($chan) !$player cash]
	set diff [get_diff $chan $player]
	if {$settings(verbose)} { putlog "Prompting $player.  Pot: $pot; Cash: $cash; Bet: $bet" }
	set output "PRIVMSG $chan :\00307\002\002$player\003: "
	if {[string equal $phase deal] && $bet_round == 1} {
		if {[string equal $player $bbplayer]} {
			append output "You are the \00302big blind\003.  "
			if {!$diff} {
				set has_cash [list]
				foreach p $players_this_round {
					if {[dict get $settings($chan) !$p cash]} { lappend has_cash $p }
				}
				if {[llength $has_cash] == 1 && [string equal [lindex $has_cash 0] $player]} {
					if {[string equal $player $botnick]} {
						puthelp "PRIVMSG $chan :\001ACTION checks.\001"
					} else {
						puthelp "PRIVMSG $chan :$player checks."
					}
					return [start_next_phase $chan]
				}
			}
		} elseif {[string equal $player $sbplayer]} {
			append output "You are the \00302small blind\003.  "
		}
	}

	if {$bet && !$cash} {
		append output "You are all-in."
		dict lappend settings($chan) has_bet $player
		if {[string equal $player $botnick]} {
			puthelp "PRIVMSG $chan :\001ACTION is all-in.\001"
		} else {
			puthelp $output
		}
		if {[string length [set next [get_next_player $chan $player]]]} {
			return [prompt $chan $next]
		} else {
			return [start_next_phase $chan]
		}
	}

	set diff [get_diff $chan $player]
	set bid [expr {$diff + $bet}]
	append output "The current pot is worth $d$pot.  "
	if {$diff} {
		append output "The bet is now at $d$bid.  "
	}
	append output "You have $d$cash remaining.  "
	if {$diff >= $cash} {
		append output "You must go all-in to stay in.  "
	} elseif {$diff} {
		append output "You can call for \00306$d$diff\003 to stay in.  "
	}
	append output "If you wish to raise, the minimum raise is \00306$d$min_bet\003.  "

	if {$diff} {
		append output "Do you wish to \002call\002, \002raise\002, or \002fold\002?  If \002raise\002, how much (or \002all-in\002)?"
	} {
		append output "Do you wish to \002check\002, \002raise\002, or \002fold\002?  If \002raise\002, how much (or \002all-in\002)?"
	}
	append output "  Or if you need me to show you your \002cards\002 again, just ask."
	dict set settings($chan) waiting_for $player
	bind pubm * $chan* ${ns}::take_bet
	if {[string equal $player $botnick] || [lsearch -exact $settings(bot-players) $player] > -1} {
		bot_play $chan $player
		return
	} else {
		puthelp $output
		return
	}
}

bind dcc mn peek ${ns}::peek
proc peek {hand idx txt} {
	variable settings; variable hand_name
	foreach chan [array names settings] {
		if {![string match \#* $chan]} { continue }
		set deck [dict get $settings($chan) deck]
		set phase [dict get $settings($chan) phase]
		foreach p [dict get $settings($chan) players_this_round] {
			if {[string equal $phase deal]} {
				set cards [list]
			} { set cards [dict get $settings($chan) cards] }
			set tmpdeck $deck
			while {[llength $cards] < 5} {
				lappend cards [lindex $tmpdeck 0]
				set tmpdeck [lreplace $tmpdeck 0 0]
			}
			set cards [concat [dict get $settings($chan) !$p cards] $cards]
			foreach {rank player res} [hand $cards $p] {
				set out "$player: $hand_name($rank)"
				foreach c $res {
					append out " [render $c]"
				}
				putlog $out
			}
		}
	}
}

proc all_in {chan nick} {
	variable settings
	global botnick

	set diff [get_diff $chan $nick]
	set bet [dict get $settings($chan) !$nick bet]
	set cash [dict get $settings($chan) !$nick cash]
	incr bet $cash
	dict incr settings($chan) pot $cash
	dict set settings($chan) !$nick bet $bet
	dict set settings($chan) !$nick cash 0
	dict set settings($chan) checks 0
	set d $settings(denomination)
	if {$cash > $diff} {
		dict set settings($chan) has_bet [list $nick]
	} else {
		dict lappend settings($chan) has_bet $nick
	}
	if {![string equal $nick $botnick]} {
		set out "PRIVMSG $chan :OK, $nick is \00309all-in\003"
	}
	if {$cash > $diff} {
		append out "\002\002, raising the bet by \00306$d$cash\003 to \00306$d$bet\003"
	}
	append out "."
	puthelp $out
}

proc call {chan nick} {
	variable settings
	global botnick
	set diff [get_diff $chan $nick]
	set bet [dict get $settings($chan) !$nick bet]
	set cash [dict get $settings($chan) !$nick cash]
	dict incr settings($chan) pot $diff
	incr bet $diff
	incr cash -$diff
	dict set settings($chan) !$nick bet $bet
	dict set settings($chan) !$nick cash $cash
	dict lappend settings($chan) has_bet $nick
	set d $settings(denomination)
	if {![string equal $nick $botnick]} {
		puthelp "PRIVMSG $chan :OK, $nick throws in $d$diff and \00302calls\003."
	}
}

proc raise {chan nick match} {
	variable settings
	global botnick
	set diff [get_diff $chan $nick]
	set bet [dict get $settings($chan) !$nick bet]
	set cash [dict get $settings($chan) !$nick cash]
	dict set settings($chan) min_bet $match
	dict set settings($chan) checks 0
	incr match $diff
	dict incr settings($chan) pot $match
	incr bet $match
	incr cash -$match
	dict set settings($chan) !$nick bet $bet
	dict set settings($chan) !$nick cash $cash
	set d $settings(denomination)
	if {$match > $diff} {
		dict set settings($chan) has_bet [list $nick]
	} else {
		dict lappend settings($chan) has_bet $nick
	}
	if {![string equal $nick $botnick]} {
		set out "PRIVMSG $chan :$nick "
		if {$diff} {
			append out "sees the remaining $d$diff"
		}
		set remainder [expr {$match - $diff}]
		if {$diff && $remainder} {
			append out ", and "
		} elseif {$diff} {
			append out "."
		}
		if {$remainder} {
			append out "\00303raises\003 the bet by "
			if {$diff} {
				append out "an additional "
			}
			append out "\00306$d[expr {$match - $diff}]\003 to a total of $d[dict get $settings($chan) !$nick bet]."
		}
		puthelp $out
	}
}

proc dec2pct {what} {
	set what [expr {int(1000 * $what) * 0.1}]
	return [regsub {000000+\d$} $what ""]%
}

proc get_odds {chan nick} {
	# returns an array.  Should be called via "array set odds [get_odds $chan $nick]" or similar
	variable settings; variable newdeck; variable hand_name
	set deck $newdeck
	set players_this_round [llength [dict get $settings($chan) players_this_round]]
	set my_cards [dict get $settings($chan) !$nick cards]
	set all_cards [concat $my_cards [dict get $settings($chan) cards]]
	set undealt [expr {7 - [llength $all_cards]}]
	array set ret [list]
	if {[llength $all_cards] < 5} { return }
	foreach {rank nick my_hand} [hand $all_cards $nick] {}
	array set o {1 0 2 0 3 0 4 0 5 0 6 0 7 0 8 0}
	set outs 0
	foreach c $all_cards {
		set idx [lsearch -exact $deck $c]
		set deck [lreplace $deck $idx $idx]
	}
	foreach c $deck {
		set whatif $all_cards
		lappend whatif $c
		foreach {r n h} [hand $whatif $nick] {}
		foreach mc $my_cards {
			if {[lsearch $h $mc] > -1 && $r > $rank && $r > 1} {
				incr outs
				incr o($r)
			}
			break
		}
	}
	if {$outs} {
		foreach n [array names o] {
			if {$n > $rank && $o($n)} {
				set chance [prob $undealt 1 $o($n) [llength $deck]]
				if {$chance >= 0.001} {
					set ret($n) $chance
				}
			}
		}
	}
	set better 0
	set iter 0
	switch $undealt {
		0 { set lst {0 1} }
		1 { set lst {0 1 2} }
		2 { set lst {0 1 2 3} }
	}
	set deck [make_deck_manageable $lst $all_cards $deck]
	while {[lindex $lst end]} {
		incr iter
		if {!($iter % 10000)} { putlog "Running ${iter}th simulation..." }
		set whatif [dict get $settings($chan) cards]
		foreach idx $lst {
			lappend whatif [lindex $deck $idx]
		}
		foreach {r n h} [hand $whatif opponent] {}
		if {$r > $rank} {
			incr better
		} elseif {$r == $rank && [lsearch [compare $h $my_hand] $h] > -1} {
			incr better
		}
		set lst [simul $lst $deck]
	}
	set p [expr {1.0 * $better / $iter}]
	# binom_dist 2 cards times players which aren't me, 2 cards needed, outs / total
	set opponent_odds [binom_dist [expr {($players_this_round - 1) * 2}] 2 $p]
	set ret(confidence) [expr {1.0 - $opponent_odds}]
	return [array get ret]
}

proc make_deck_manageable {lst all_cards deck} {
	if {[llength $lst] > 2} {
		set deck [list]
		for {set i 2} {$i < 15} {incr i} {
			set c [list]
			set S {S H C D}
			while {[llength $S] && ![llength $c]} {
				set idx [rand [llength $S]]
				set s [lindex $S $idx]
				set S [lreplace $S $idx $idx]
				if {[lsearch $all_cards [list $i $s]] < 0} {
					set c [list $i $s]
					break
				}
			}
			lappend deck $c
		}
	}
	return $deck
}

proc simul {lst deck} {
	# lst = index numerals -- i.e. 0 1 2 3 for [lindex $deck idx0] [lindex $deck idx1] etc
	for {set i [expr {[llength $lst] - 1}]} {$i > -1} {incr i -1} {
		set last [expr {[lindex $lst $i] + 1}]
		set lst [lreplace $lst $i $i $last]
		if {$last < [expr {[llength $deck] - ([llength $lst] - 1 - $i)}]} {
			for {set j [expr {$i + 1}]; set k [expr {$last + 1}]} {$j < [llength $lst]} {incr j; incr k} {
				set lst [lreplace $lst $j $j $k]
			}
			return $lst
		}
	}
	return 0
}

proc compare {args} {
	array set w [list]
	set sortme [list]
	for {set i 0} {$i < [llength $args]} {incr i} {
		set l [lindex $args $i]
		set h [list]
		foreach c $l {
			lappend h [lindex $c 0]
		}
		lappend w($h) [lindex $args $i]
		lappend sortme $h
	}
	set sortme [lsort -int -dec -index 0 [lsort -int -dec -index 1 [lsort -int \
	-dec -index 2 [lsort -int -dec -index 3 [lsort -int -dec -index 4 $sortme]]]]]
	return $w([lindex $sortme 0])
}

proc binom {n k} {
	set k [expr {(($n-$k) > $k) ? $n-$k : $k}]

	if {$k > $n}  {return 0}
	if {$k == $n} {return 1}

	set res 1
	set d 0
	while {$k < $n} {
		set res [expr {($res*[incr k])/[incr d]}]
	}
	set res
}

# P(X = k) = (n,k) * p^k * (1 - p)^(n - k)
proc binom_dist {n success p} {
	# n = cards to be drawn
	# success = cards needed for success
	# p = decimal value of likelihood of success (outs / unseen cards)
	set res 0
	for {set k $n} {$k >= $success} {incr k -1} {
		set b [expr {1.0 * [binom $n $k] * pow($p, $k) * pow((1.0 - $p), ($n - $k))}]
		set res [expr {$b + $res}]
	}
	#set p [expr {1.0 * $outs / $total}]
	#expr {1.0 * [binom $n $k] * pow($p, $k) * pow((1.0 - $p), ($n - $k))}
	return $res
}

proc prob {draws needed outs {decksize 0}} {
	if {$decksize} {
		set p [expr {1.0 * $outs / $decksize}]
	} { set p $outs }
	binom_dist $draws $needed $p
}

proc countdown_timeout {chan} {
	variable settings; variable ns
	global botnick
	set nick [dict get $settings($chan) waiting_for]
	catch {unbind pubm * $chan* ${ns}::force_fold}
	foreach t [utimers] {
		if {[string equal [lindex $t 1] [list ${ns}::hurry_up $chan]]} { killutimer [lindex $t 2] }
	}
	set players [dict get $settings($chan) players]
	set humans 0
	foreach p $players {
		if {![string equal $p $botnick] && [lsearch $settings(bot-players) $p] < 0} {
			incr humans
		}
	}
	if {$humans < 2} { return }
	set t [expr {$settings(timeout) + ([queuesize help] * 2)}]
	utimer $t [list ${ns}::hurry_up $chan]
}

proc hurry_up {chan} {
	variable settings; variable ns
	set nick [dict get $settings($chan) waiting_for]
	puthelp "PRIVMSG $chan :...$nick is taking forever to make a decision.  Shall I make $nick fold?"
	bind pubm * $chan* ${ns}::force_fold
}

proc force_fold {nick uhost hand chan txt} {
	variable settings; variable ns
	foreach v {waiting_for players} {
		set $v [dict get $settings($chan) $v]
	}
	if {[string equal $waiting_for $nick]} { return }
	if {[lsearch $players $nick] < 0} { return }
	if {[regexp -nocase {\y(yes|yep|do it|absolutely|uh huh|sure|affirmative)\y} $txt]} {
		take_bet $waiting_for - - $chan fold
	} elseif {![regexp -nocase {\y(no|don't|nah)} $txt]} {
		return
	}
	catch {unbind pubm * $chan* ${ns}::force_fold}
}

proc take_bet {nick uhost hand chan txt} {
	variable settings; variable ns; variable hand_name
	global botnick
	if {$settings(verbose)} { putlog "proc take_bet $nick $uhost $hand $chan $txt" }
	if {![info exists settings($chan)]} { return }
	set waiting_for [dict get $settings($chan) waiting_for]
	if {![string equal $waiting_for $nick]} { return }

	# if $txt contains a nick in the channel other than the bot's nick
	# avoid using the number in someone's nick as a bet value.
	set rxp [regexp -inline -all -nocase -- {\y[a-z0-9\x5B-\x60\x7B-\x7D]+\y} $txt]
	foreach m $rxp { if {[onchan $m $chan] && [regexp {\d} $m]} { return } }

	catch {unbind pubm * $chan* ${ns}::take_bet}
	foreach var {pot phase players players_this_round has_bet bbvalue min_bet} {
		set $var [dict get $settings($chan) $var]
	}
	foreach var {cash bet} {
		set $var [dict get $settings($chan) !$nick $var]
	}
	set d $settings(denomination)
	set diff [get_diff $chan $nick]
	set bid [expr {$diff + $bet}]

	countdown_timeout $chan

	if {[string match -nocase *cards* $txt]} {
		set out "NOTICE $nick :You are holding these cards:"
		set cards [dict get $settings($chan) !$nick cards]
		foreach c $cards {
			append out " [render $c]"
		}
		if {![string equal $phase deal]} {
			set cards [concat $cards [dict get $settings($chan) cards]]
			set h [hand $cards $nick]
			set rank $hand_name([lindex $h 0])
			append out "  As it stands, your cards earn you \002$rank\002"
			array set odds [get_odds $chan $nick]
			if {[array size odds]} {
				foreach el [lsort -dict [array names odds]] {
					if {[string is integer $el]} {
						append out "; chance of getting $hand_name($el): \002[dec2pct $odds($el)]\002"
					}
				}
				append out "; confidence in your winning this hand: \002[dec2pct $odds(confidence)]\002"
			} { append out "." }
		}
		puthelp $out
		bind pubm * $chan* ${ns}::take_bet
		return
	} elseif {[regexp -nocase {^\yall\y.*\yin\y} $txt]} {
		if {![string equal $nick $botnick] && [lsearch $settings(bot-players) $nick] < 0} { clearqueue help }
		all_in $chan $nick
	} elseif {[regexp -nocase {^(\w* *)?[0-9\,]+} $txt match]} {
		if {![string equal $nick $botnick] && [lsearch $settings(bot-players) $nick] < 0} { clearqueue help }
		regexp {\d+} [string map {, ""} $match] match
		if {[expr {$match + $diff}] > $cash} {
			all_in $chan $nick
		} elseif {!$match} {
			call $chan $nick
		} elseif {$match < $min_bet} {
			puthelp "PRIVMSG $chan :\001ACTION sighs and waits for a raise of at least \002$d$min_bet\002 from $nick.\001"
			bind pubm * $chan* ${ns}::take_bet
			return
		} else {
			raise $chan $nick $match
		}
	} elseif {[regexp -nocase {^\y(raise|bet)\y} $txt]} {
		puthelp "PRIVMSG $chan :$nick: OK, how much would you like to bet?"
		bind pubm * $chan* ${ns}::take_bet
		return
	} elseif {[regexp -nocase {^\ycall\y} $txt]} {
		if {![string equal $nick $botnick] && [lsearch $settings(bot-players) $nick] < 0} { clearqueue help }
		if {!$diff} {
			dict lappend settings($chan) has_bet $nick
			if {![string equal $nick $botnick]} {
				puthelp "PRIVMSG $chan :OK, $nick \00302checks\003."
			}
		} elseif {$diff > $cash} {
			all_in $chan $nick
		} else {
			call $chan $nick
		}
	} elseif {[regexp -nocase {^\ycheck\y} $txt]} {
		if {![string equal $nick $botnick] && [lsearch $settings(bot-players) $nick] < 0} { clearqueue help }
		if {$diff} {
			puthelp "PRIVMSG $chan :$nick: You haven't met the minimum bid.  You must either call, raise or fold."
			bind pubm * $chan* ${ns}::take_bet
			return
		} else {
			dict lappend settings($chan) has_bet $nick
			dict incr settings($chan) checks
			if {![string equal $nick $botnick]} {
				puthelp "PRIVMSG $chan :OK, $nick \00302checks\003."
			}
		}
	} elseif {[regexp -nocase {^\yfold\y} $txt]} {
		if {![string equal $nick $botnick]} {
			if {[lsearch $settings(bot-players) $nick] < 0} { clearqueue help }
			set out "PRIVMSG $chan :$nick \026folds\026, saving $d$cash for better cards.  "
		} { set out "PRIVMSG $chan :" }
		set idx [lsearch $players_this_round $nick]
		set players_this_round [lreplace $players_this_round $idx $idx]
		set idx [lsearch $has_bet $nick]
		if {$idx > -1} { set has_bet [lreplace $has_bet $idx $idx] }
		if {$settings(verbose)} { putlog "$nick folds.  players_this_round: $players_this_round" }
		foreach var {players_this_round has_bet} {
			dict set settings($chan) $var [set $var]
		}
		if {[llength $players_this_round] == 1} {
			if {[string equal $nick $botnick] || [lsearch $settings(bot-players) $nick] > -1} {
				set confidence [dict get $settings($chan) !$nick confidence]
				dict set settings($chan) !$nick confidence [expr {$confidence - 1}]
			}
			set p [lindex $players_this_round 0]
			set cash [dict get $settings($chan) !$p cash]
			incr cash $pot
			if {[string equal $p $botnick] || [lsearch $settings(bot-players) $p] > -1} {
				set confidence [dict get $settings($chan) !$p confidence]
				dict set settings($chan) !$p confidence [expr {$confidence + 1}]
			}
			if {[string equal $p $botnick]} {
				append out "\00307I win the hand.\003"
			} { append out "\00307$p wins the hand.\003" }
			puthelp $out
			dict set settings($chan) !$p cash $cash
			dict set settings($chan) phase score
			return [start_next_phase $chan]
		}
		puthelp $out
	} else {
		bind pubm * $chan* ${ns}::take_bet
		return
	}

	if {$settings(verbose)} {
		putlog "Took bet from $nick.  Pot: $pot; Cash: $cash; Bet: $bet; Has_bet: $has_bet"
		foreach p [dict get $settings($chan) players] {
			putlog "$p bet: $d[dict get $settings($chan) !$p bet]"
		}
	}

	while {[lsearch -exact $players_this_round $nick] == -1} {
		set idx [lsearch -exact $players $nick]
		if {!$idx} { set nick [lindex $players end] } { set nick [lindex $players [expr {$idx - 1}]] }
	}

	if {[string length [set p [get_next_player $chan $nick]]]} {
		return [prompt $chan $p]
	} {
		return [start_next_phase $chan]
	}
}

proc start_next_phase {chan} {
	variable settings; variable ns
	global botnick
	if {$settings(verbose)} { putlog "proc start_next_phase $chan" }
	foreach val {phase players_this_round players bbvalue} {
		set $val [dict get $settings($chan) $val]
	}
	set has_cash 0
	foreach p $players_this_round {
		set l [dict get $settings($chan) !$p bet]
		set limit $l
		foreach p2 $players {
			if {$p2 != $p} {
				set l2 [dict get $settings($chan) !$p2 bet]
				if {$l > $l2} { incr limit $l2 } { incr limit $l }
			}
		}
		dict set settings($chan) !$p limit $limit
		if {[dict get $settings($chan) !$p cash]} { incr has_cash }
	}
	if {$has_cash < 2 && ![dict get $settings($chan) skip_betting]\
	&& [llength $players_this_round] > 1 && ![regexp {(river|score)} $phase]} {
		dict set settings($chan) skip_betting 1
		foreach p $players_this_round {
			set out "PRIVMSG $chan :$p's cards:"
			set C [dict get $settings($chan) !$p cards]
			foreach c $C {
				append out " [render $c]"
			}
			puthelp $out
		}
	}

	dict set settings($chan) bet_round 0
	dict set settings($chan) phase $phase
	dict set settings($chan) has_bet [list]
	dict set settings($chan) min_bet $bbvalue
	switch $phase {
		deal { set phase flop }
		flop { set phase turn }
		turn { set phase river }
		river { set phase score }
		score { set phase deal }
	}
	dict set settings($chan) phase $phase
	if {[string equal $phase deal]} {
		set humans 0
		foreach p $players {
			if {[lsearch -exact $settings(bot-players) $p] > -1 || [string equal $p $botnick]} { continue }
			if {[dict get $settings($chan) !$p cash]} { incr humans; break }
		}
		if {!$humans} {
			puthelp "PRIVMSG $chan :The last human player has busted out.  Do you want to keep\
			watching me play with myself?"
			bind pubm * $chan* ${ns}::keep_watching
			return
		}
	}
	if {[catch {$phase $chan} err]} { putlog $err }
}

proc keep_watching {nick uhost hand chan txt} {
	variable ns
	if {[string match -nocase *no* $txt]} {
		unbind pubm * $chan* ${ns}::keep_watching
		puthelp "PRIVMSG $chan :k.  Whatever."
		catch {stop $chan}
	} elseif {[string match -nocase *yes* $txt]} {
		unbind pubm * $chan* ${ns}::keep_watching
		catch {deal $chan}
	}
}

proc flop {chan} {
	variable settings
	if {$settings(verbose)} { putlog "proc flop $chan" }
	foreach var {players dealer bbplayer deck} {
		set $var [dict get $settings($chan) $var]
	}
	set cards [list [lindex $deck 0] [lindex $deck 1] [lindex $deck 2]]
	set deck [lreplace $deck 0 2]
	dict set settings($chan) deck $deck
	dict set settings($chan) cards $cards
	set out "PRIVMSG $chan :The flop:"
	foreach c $cards {
		append out " [render $c]"
	}
	puthelp $out
	
	set next_player [get_next_player $chan $dealer]
	
	prompt $chan $next_player
}

proc turn {chan} {
	variable settings
	if {$settings(verbose)} { putlog "proc turn $chan" }
	foreach var {players dealer bbplayer deck cards} {
		set $var [dict get $settings($chan) $var]
	}
	set cards [concat $cards [list [lindex $deck 0]]]
	set deck [lreplace $deck 0 0]
	dict set settings($chan) deck $deck
	dict set settings($chan) cards $cards
	set out "PRIVMSG $chan :The turn:"
	foreach c $cards {
		append out " [render $c]"
	}
	puthelp $out
	
	set next_player [get_next_player $chan $dealer]
	
	prompt $chan $next_player
}
proc river {chan} {
	variable settings
	if {$settings(verbose)} { putlog "proc river $chan" }
	foreach var {players dealer bbplayer deck cards} {
		set $var [dict get $settings($chan) $var]
	}
	set cards [concat $cards [list [lindex $deck 0]]]
	set deck [lreplace $deck 0 0]
	dict set settings($chan) deck $deck
	dict set settings($chan) cards $cards
	set out "PRIVMSG $chan :The river:"
	foreach c $cards {
		append out " [render $c]"
	}
	puthelp $out
	
	set next_player [get_next_player $chan $dealer]
	
	prompt $chan $next_player
}

proc score {chan} {
	variable settings; variable hand_name; variable ns
	global botnick
	if {$settings(verbose)} { putlog "proc score $chan" }
	foreach var {players players_this_round cards pot} {
		set $var [dict get $settings($chan) $var]
	}

	set hands [list]
	set has_cash -2
	foreach p $players {
		if {[dict get $settings($chan) !$p cash]} { incr has_cash }
	}

	foreach p $players_this_round {
		set mycards [concat $cards [dict get $settings($chan) !$p cards]]
		set h [hand $mycards $p]
		lappend hands $h
		set out "PRIVMSG $chan :$p had $hand_name([lindex $h 0]):"
		foreach card [lindex $h 2] {
			append out " [render $card]"
		}
		if {[string equal $p $botnick] || [lsearch $settings(bot-players) $p] > -1} {
			set confidence [dict get $settings($chan) !$p confidence]
			dict set settings($chan) !$p confidence [expr {$confidence - 1}]
		}
		puthelp $out
	}
	set hands [lsort -integer -index 0 -decreasing $hands]

	set pot_total $pot
	set d $settings(denomination)
	set out "PRIVMSG $chan :"
	while {$pot && [llength $hands]} {
		set winning_score [lindex [lindex $hands 0] 0]
		set top [list [lindex $hands 0]]
		for {set i 1} {$i < [llength $players_this_round]} {incr i} {
			if {$winning_score > [lindex [lindex $hands $i] 0]} {
				break
			}
			lappend top [lindex $hands $i]
		}
		array set winnars [list]
		set sortme [list]
		foreach h $top {
			set C [lindex $h 2]
			set v [list]
			foreach c $C {
				lappend v [lindex $c 0]
			}
			if {![info exists winnars($v)] || [lsearch $winnars($v) [lindex $h 1]] == -1} {
				lappend winnars($v) [lindex $h 1]
			}
			lappend sortme $v
		}

		set sortme [lsort -int -dec -index 0 [lsort -int -dec -index 1 [lsort -int \
		-dec -index 2 [lsort -int -dec -index 3 [lsort -int -dec -index 4 $sortme]]]]]

		set winning_hand [lindex $sortme 0]
		if {[llength $winnars($winning_hand)] > 1} {
			append out "[list2pretty $winnars($winning_hand)] split the pot.  "
		}

		# in case of split, even out the bets to avoid penalizing someone who
		# went all-in when he didn't have to
		set num_win [llength $winnars($winning_hand)]
		set p [list]
		array set pre [list]
		foreach w $winnars($winning_hand) {
			lappend p [list $w [dict get $settings($chan) !$w bet]]
			set pre($w) 0
		}
		set p [lsort -int -index 1 $p]
		for {set i 0} {$pot && $i < [expr {$num_win - 1}]} {incr i} {
			set j [expr {$i + 1}]
			set this [lindex $p $i]
			set next [lindex $p $j]
			set name [lindex $next 0]
			set val [lindex $next 1]
			set cash [dict get $settings($chan) !$name cash]
			set diff [expr {$val - [lindex $this 1]}]
			if {$pot < $diff} { set diff $pot }
			incr cash $diff
			incr pot -$diff
			incr pre($name) $diff
			dict set settings($chan) !$name cash $cash
			set next [lreplace $next 1 1 [lindex $this 1]]
			set p [lreplace $p $j $j $next]
		}

		set potential [expr {int(ceil(1.0 * $pot / $num_win))}]
		foreach winnar $winnars($winning_hand) {
			for {set i 0} {$i < [llength $hands]} {incr i} {
				if {[string equal [lindex [lindex $hands $i] 1] $winnar]} {
					set hands [lreplace $hands $i $i]
					break
				}
			}

			foreach var {limit cash bet} {
				set $var [dict get $settings($chan) !$winnar $var]
			}

			if {$potential > $pot} { set potential $pot }
			if {$potential > $limit} {
				set winnings $limit
			} { set winnings $potential }

			incr pot -$winnings
			incr cash $winnings
			incr pre($winnar) $winnings
			
			if {$pre($winnar) > $bet} {
				if {[string equal $winnar $botnick] || [lsearch $settings(bot-players) $winnar] > -1} {
					set confidence [dict get $settings($chan) !$winnar confidence]
					dict set settings($chan) !$winnar confidence [expr {$confidence + 3}]
				}
				append out "$winnar wins $d$pre($winnar).  "
			} { append out "$winnar recovers $d$pre($winnar).  " }
			dict set settings($chan) !$winnar cash $cash
		}
	}
	
	if {$pot} { append out "I ended up with $pot left over that I wasn't sure what to do\
	with.  I'll just keep it I guess, and prolly crash the game or something." }

	set has_cash [list]
	set total_cash 0
	foreach p $players {
		set cash [dict get $settings($chan) !$p cash]
		if {$cash} { lappend has_cash $p; incr total_cash $cash }
	}
	if {[llength $has_cash] == 1} {
		puthelp "PRIVMSG $chan :\002[lindex $has_cash 0]\002 wins the game with \00306$d$total_cash\003!"
		${ns}::stop $chan
	} else {
		puthelp $out
		dict set settings($chan) folds 0
		start_next_phase $chan
	}
}

proc straight_flush {lst} {
	return [flush [straight $lst]]
}

proc four_of_a_kind {lst} {
	array set f [list]
	set lst [lsort -integer -index 0 -decreasing $lst]
	for {set i 0} {$i < [llength $lst]} {incr i} {
		lappend f([lindex [lindex $lst $i] 0]) [lindex $lst $i]
	}
	foreach val [lsort -integer -decreasing [array names f]] {
		if {[llength $f($val)] > 3} {
			while {[llength $f($val)] < 5 && [llength $lst]} {
				if {[lindex [lindex $lst 0] 0] != [lindex [lindex $f($val) 0] 0]} {
					lappend f($val) [lindex $lst 0]
				}
				set lst [lreplace $lst 0 0]
			}
			return $f($val)
		}
	}
	return [list]
}

proc full_house {lst} {
	set lst [lsort -integer -index 0 -decreasing $lst]
	set first [three_of_a_kind $lst]
	if {[llength $first]} {
		set first [lrange $first 0 2]
		foreach card $first {
			set idx [lsearch -exact $lst $card]
			set lst [lreplace $lst $idx $idx]
		}
		set last [one_pair $lst]
		if {[llength $last]} {
			set last [lrange $last 0 1]
			return [concat $first $last]
		}
	}
	return [list]
}

proc flush {lst} {
	set lst [lsort -integer -index 0 -decreasing $lst]
	array set f [list]
	for {set i 0} {$i < [llength $lst]} {incr i} {
		lappend f([lindex [lindex $lst $i] 1]) [lindex $lst $i]
	}
	foreach suit [array names f] {
		if {[llength $f($suit)] > 4} {
			return [lrange $f($suit) 0 4]
		}
	}
	return [list]
}

proc straight {lst} {
	# if flush, sort by suit before value to preserve straight flush
	set f [flush $lst]
	if {[llength $f]} {
		set lst $f
	} else {
		set lst [lsort -integer -index 0 -decreasing $lst]
	}

	set card [lindex $lst 0]
	if {[lindex $card 0] == 14} { lappend lst [list 1 [lindex $card 1]] }

	for {set i 0} {$i < [expr {[llength $lst] - 4}]} {incr i} {
		set hand [list [lindex $lst $i]]
		set tmplst $lst
		for {set j $i} {$j < [expr {[llength $tmplst] - 1}]} {incr j} {
			set this_val [lindex [lindex $tmplst $j] 0]
			set next [expr {$j + 1}]
			while {$this_val == [set next_val [lindex [lindex $tmplst $next] 0]]\
			&& $next < [llength $lst]} { set tmplst [lreplace $tmplst $next $next] }
			if {[expr {$this_val - 1}] == $next_val} {
				lappend hand [lindex $tmplst $next]
			} { set hand [list [lindex $tmplst $next]] }
			if {[llength $hand] == 5} {
				return $hand
			}
		}
	}
	return [list]
}

proc three_of_a_kind {lst} {
	array set f [list]
	set lst [lsort -integer -index 0 -decreasing $lst]
	for {set i 0} {$i < [llength $lst]} {incr i} {
		lappend f([lindex [lindex $lst $i] 0]) [lindex $lst $i]
	}
	foreach val [lsort -integer -decreasing [array names f]] {
		if {[llength $f($val)] > 2} {
			while {[llength $f($val)] < 5 && [llength $lst]} {
				if {[lindex [lindex $lst 0] 0] != [lindex [lindex $f($val) 0] 0]} {
					lappend f($val) [lindex $lst 0]
				}
				set lst [lreplace $lst 0 0]
			}
			return $f($val)
		}
	}
	return [list]
}

proc two_pair {lst} {
	set lst [lsort -integer -index 0 -decreasing $lst]
	set first [one_pair $lst]
	if {[llength $first]} {
		set first [lrange $first 0 1]
		foreach card $first {
			set idx [lsearch -exact $lst $card]
			set lst [lreplace $lst $idx $idx]
		}
		set last [one_pair $lst]
		if {[llength $last]} {
			set last [lrange $last 0 2]
			return [concat $first $last]
		}
	}
	return [list]
}

proc one_pair {lst} {
	array set f [list]
	set lst [lsort -integer -index 0 -decreasing $lst]
	
	for {set i 0} {$i < [llength $lst]} {incr i} {
		lappend f([lindex [lindex $lst $i] 0]) [lindex $lst $i]
	}
	foreach val [lsort -integer -decreasing [array names f]] {
		if {[llength $f($val)] > 1} {
			while {[llength $f($val)] < 5 && [llength $lst]} {
				if {[lindex [lindex $lst 0] 0] != [lindex [lindex $f($val) 0] 0]} {
					lappend f($val) [lindex $lst 0]
				}
				set lst [lreplace $lst 0 0]
			}
			return $f($val)
		}
	}
	return [list]
}

proc high_card {lst} {
	return [lrange [lsort -integer -index 0 -decreasing $lst] 0 4]
}

proc hand {lst player} {
	variable settings
	# if {$settings(verbose)} { putlog "proc hand $lst $player" }
	foreach {p rank} {
		straight_flush 8
		four_of_a_kind 7
		full_house 6
		flush 5
		straight 4
		three_of_a_kind 3
		two_pair 2
		one_pair 1
		high_card 0
	} {
		if {![catch {$p $lst} res] && [llength $res]} {
			return [list $rank $player $res]
		}
	}
}

proc bot_raise {chan nick} {
	variable settings
	if {$settings(verbose)} { putlog "proc bot_raise $chan" }
	foreach var {bet_round bbvalue phase min_bet} {
		set $var [dict get $settings($chan) $var]
	}
	foreach var {bet cash} {
		set $var [dict get $settings($chan) !$nick $var]
	}
	set diff [get_diff $chan $nick]
	if {$bet_round < 3} {
		set raise [expr {$min_bet * $bet_round}]
	} {
		set raise $cash
	}
	if {$settings(verbose)} { putlog "bot_raise $raise" }
	if {$raise < $diff} { return $diff }
	if {$raise > $cash} { return $cash } { return $raise }
}

proc bot_play {chan nick} {
	variable settings
	if {$settings(verbose)} { putlog "proc bot_play $chan" }
	global botnick
	foreach var {cards bbvalue phase checks players players_this_round round} {
		set $var [dict get $settings($chan) $var]
	}
	foreach var {cash bet} {
		set $var [dict get $settings($chan) !$nick $var]
	}
	set diff [get_diff $chan $nick]
	set d $settings(denomination)
	set confidence [ai $chan $nick]
	if {$settings(verbose)} { putlog "ai: $confidence" }
	if {$confidence > 50} {
		if {$settings(verbose)} { putlog "confidence > 50" }
		if {!$diff && [bluff $chan $nick]} {
			set action check
		} else {
			set action all-in
		}
	} elseif {$confidence > 40} {
		if {$settings(verbose)} { putlog "confidence > 40" }
		if {[bluff $chan $nick]} {
			if {!$diff} {
				set action check
			} else {
				set action all-in
			}
		} elseif {$bet > $cash} {
			set action call
		} else {
			set action [expr {round([bot_raise $chan $nick] * 1.5)}]
			while {$action % 5} { incr action }
		}
	} elseif {$confidence > 30} {
		if {$settings(verbose)} { putlog "confidence > 30" }
		if {!$diff || [bluff $chan $nick]} {
			set action [bot_raise $chan $nick]
		} elseif {$diff < [expr {round($cash * 0.66)}]} {
			set action call
		} else {
			if {$diff} { set action fold } { set action check }
		}
		if {[string is integer $action] && $cash > 100 && $action > [expr {$cash * 0.75}]} {
			if {$diff} { set action fold } { set action check }
		}
	} elseif {$confidence > 20} {
		if {$settings(verbose)} { putlog "confidence > 20" }
		if {[bluff $chan $nick]} {
			set action [bot_raise $chan $nick]
		} elseif {$diff >= $cash} {
			set action fold
		} elseif {!$diff} {
			set action [bot_raise $chan $nick]
		} elseif {$diff < [expr {round($cash * 0.34)}]} {
			set action call
		} else {
			set action [bot_raise $chan $nick]
		}
		if {[string is integer $action] && $cash > 50 && $action > [expr {$cash * 0.50}]} {
			if {$diff} { set action fold } { set action check }
		}
	} elseif {$confidence > 10} {
		if {$settings(verbose)} { putlog "confidence > 10" }
		if {!$diff} {
			if {[bluff $chan $nick]} {
				set action [bot_raise $chan $nick]
			} else {
				set action check
			}
		} elseif {$diff >= [expr {$cash / 2}]} {
			set action fold
		} elseif {$diff >= [expr {$cash / 6}]} {
			set action call
		} else {
			set action [bot_raise $chan $nick]
		}		
		if {[string is integer $action] && $cash > 25 && $action > [expr {$cash * 0.10}]} {
			if {$diff} { set action fold } { set action check }
		}
	} else {
		if {$settings(verbose)} { putlog "no confidence" }
		if {!$diff} { set action check } { set action fold }
	}
	if {$settings(verbose)} { putlog "action = $action; $checks checks." }
	if {[string is integer $action]} {
		if {!$action} {
			if {!$diff} {
				set action check
			} else {
				set action $diff
			}
		} elseif {$action == $diff} {
			set action call
		}
	}
	switch $action {
		call {
			if {!$diff} {
				set action check
			} elseif {$diff >= $cash} {
				set action all-in
			}
		}
		check {
			switch $phase {
				turn { set checks [expr {$checks * 2}] }
				river { set checks [expr {$checks * 3}] }
			}
			set checks [expr {
				$checks >= ([llength $players_this_round] * 2 - 1) ?
				1 : ([llength $players_this_round] * 2) - $checks
			}]
			if {!([rand 100] % $checks)} {
				set action [bot_raise $chan $nick]
				if {$action >= $cash} { set action all-in }
			}
		}
		fold {
			if {![catch {dict get $settings($chan) !$nick kamikaze} kamikaze]} {
				if {[expr {$round - $kamikaze}] > 2} {
					dict unset settings($chan) !$nick kamikaze
					dict set settings($chan) !$nick confidence [expr {[rand $settings(confidence)] + 5}]
				}
				dict set settings($chan) folds 0
				set action call
			} else {
				dict incr settings($chan) folds
				set folds [dict get $settings($chan) folds]
				set has_cash 0
				foreach p $players {
					if {[dict get $settings($chan) !$p cash] || [dict get $settings($chan) !$p bet]} { incr has_cash }
				}
				if {$folds > [expr {$has_cash * 2}] || $folds > $has_cash && !([rand 100] % $has_cash)} {
					dict set settings($chan) !$nick kamikaze $round
					set action call
				}
			}
		}
	}
	if {[string is integer $action]} {
		if {$action >= $cash} {
			set action all-in
		} elseif {$action < 5} {
			if {!$diff} { set action check } { set action fold }
		}
	}
	if {[string equal $nick $botnick]} {
		switch $action {
			all-in {
				set out "PRIVMSG $chan :\001ACTION throws in \00306$d$cash\003 and goes \00309all-in\003\002\002"
				if {$cash > $diff} {
					append out ", raising the bet by \00306$d[expr {$cash - $diff}]\003"
				}
				append out ".\001"
				puthelp $out
			}
			check { puthelp "PRIVMSG $chan :\001ACTION guards his $d$cash and \00302checks\003.\001" }
			call { puthelp "PRIVMSG $chan :\001ACTION tosses in $d$diff from his $d$cash and \00302calls\003.\001" }
			fold { puthelp "PRIVMSG $chan :\001ACTION hangs onto his $d$cash and \026folds\026.\001" }
			default {
				set out "PRIVMSG $chan :\001ACTION "
				if {$diff} {
					append out "sees the remaining $d$diff, and "
				}
				append out "\00303raises\003\ the bet by \00306$d$action\003.\001"
				puthelp $out
			}
		}
	}
	take_bet $nick - - $chan $action
}

proc ai {chan nick} {
	variable settings; variable newdeck
	foreach var {players_this_round phase cards} {
		set $var [dict get $settings($chan) $var]
	}
	set mycards [lsort -integer -index 0 -decreasing\
	[dict get $settings($chan) !$nick cards]]
	set all_cards [concat $cards $mycards]
	set confidence [dict get $settings($chan) !$nick confidence]
	if {$confidence > 10} {
		set confidence [expr {round($confidence / 2)}]
		dict set settings($chan) !$nick confidence $confidence
	}

	if {[bluff $chan $nick]} {
		if {$settings(verbose)} { putlog "ai: bluffing." }
		incr confidence 10
	}

	if {[string equal $phase deal]} {
		incr confidence [expr {(5 - [llength $players_this_round]) * 5}]
		set c1v [lindex [lindex $mycards 0] 0]
		set c1s [lindex [lindex $mycards 0] 1]
		set c2v [lindex [lindex $mycards 1] 0]
		set c2s [lindex [lindex $mycards 1] 1]
		if {$c1v == $c2v} { incr confidence [expr {$c1v * 2}] }
		if {$c1s == $c2s} { incr confidence 5 }
		foreach v [list $c1v $c2v] {
			incr confidence [expr {$v == 14 ? 7 : ($v > 9 ? round($c1v / 3) : round($c1v / 4))}]
		}
		if {$settings(verbose)} { putlog "ai: $confidence" }
		return $confidence
	}
	array set odds [get_odds $chan $nick]
	if {$settings(verbose)} { putlog "$nick confidence: $odds(confidence) + $confidence" }
	incr confidence [expr {
		$odds(confidence) > 0.95 ? 40 :
		$odds(confidence) > 0.90 ? 30 :
		round($odds(confidence) * 25)
	}]
	set rank [lindex [hand $all_cards $nick] 0]
	incr confidence [expr {$rank * 10}]
	if {$settings(verbose)} { putlog "$nick confidence: $confidence" }

	if {$settings(verbose)} { putlog "ai: $confidence" }
	return $confidence
}

proc bluff {chan nick} {
	variable settings
	set confidence [dict get $settings($chan) !$nick confidence]
	set bluff [expr {$confidence > 13 ? 2 : $confidence < 0 ? 15 : 15 - $confidence}]
	if {!([rand 100] % $bluff)} { return true } { return false }
}

putlog "Hold 'Em $scriptver loaded."

}; # end namespace
