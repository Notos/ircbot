# Op Commands By xTc^bLiTz

# Gonna Ask You Not To Rip This, But Since Half Of You Probably Are Not To
# Much I Can Do About It.  Just Remember That Ripping This For Yourself
# Takes Away From The Statisfaction Of Making Something Like This Yourself.
# Also If I Find People Ripping My Work, I Will No Longer Post Other
# Scripts, And You Will Have To Start Making Everything For Yourself
# Give Credit Where Credit Is Due.

# This Script Contains A Bunch Of Commands To Be Used By Op/Master Flagged 
# Users To Better Control The Channel And Other Users.  You Can Use 
# !commands In The Channel To List All Available Commands
# NOTE:  Not All Commands Listed When You Use !commands Are Available From 
# This Script, You May Have To Edit The Commands List At The Bottom Of This 
# Script, There Is Notation There On How To Edit It.

# This Script Was Not Written Originally For Distribution, But By Popular 
# Demand/Request I Have Released It On www.egghelp.org, So Forgive Me If 
# It's Not Laid Out Entirely User Friendly-Like

# Set Up Instructions.
# Copy opcmds.tcl To Your eggdrop/scripts Directory, Then Edit Your 
# eggdrop.conf File And Add source scripts/opcmds.tcl To The Bottom In Your 
# Source Section

# Command Bindings

bind pub n|n !die proc_die
bind pub n|n !restart proc_restart
bind pub m|m !addop proc_addop
bind pub m|m !delop proc_delop
bind pub m|m !deluser proc_deluser
bind pub m|m !adduser proc_adduser
bind pub m|m !jump proc_jump
bind pub m|m !gban proc_gban
bind pub o|o !lc proc_lc
bind pub o|o !uc proc_uc
bind pub o|o !ban proc_ban
bind pub o|o !unban proc_unban
bind pub o|o !whois proc_whois
bind pub o|o !opme proc_opme
bind pub o|o !op proc_op
bind pub o|o !deop proc_deop
bind pub o|o !deopme proc_deopme
bind pub o|o !kick proc_kick
bind pub o|o !voice proc_voice
bind pub o|o !devoice proc_devoice
bind pub o|o !server proc_server
bind pub -|- !commands proc_commands

# Processes

# Process lc

proc proc_lc { nick uhost hand chan args } {
  putquick "PRIVMSG $chan :Locking Channel"
  putquick "MODE $chan +im"
}

proc proc_uc { nick uhost hand chan args } {
  putquick "PRIVMSG $chan :UnLocking Channel"
  putquick "MODE $chan -im"
}

# Process die

proc proc_die { nick uhost hand chan text } {
 if {$text == ""} {
  die $nick
 } else { die $text }
}

# Process Restart

proc proc_restart { nick uhost hand chan text } {
  putquick "PRIVMSG $chan :Restart Requested By \002$nick\002. Restarting BRB... (hopefully..)"
  restart
}

# Op Process

proc proc_op { nick uhost hand chan text } {
  putserv "MODE $chan +o $text"
}

# DeOp Process

proc proc_deop { nick uhost hand chan text } {
  global botnick
  if {$text == $botnick} {
    putserv "MSG $chan :umm.. no"
    return 0
  }
  putserv "MODE $chan -o $text"
}

# Process Global Ban

proc proc_gban { nick uhost hand chan text } {
global botnick
#  if {@ isin $text} {
#    +ban $text Auto-Kicked
#    stick ban $text
#    return 0
#  }
  if {[onchan $text]} {
    if {$text == $botnick} { return 0 }
    set banmask [getchanhost $text $chan]
    newchanban $chan $banmask $nick Auto-Kicked 0 sticky
    putkick $chan $text Auto-Kicked
    putlog "\002$nick\002 Globally Banned \002$text\($banmask\)\002"
  } else { putserv "PRIVMSG $chan :$text Not In Channel." } 
}

# Proces Jump

proc proc_jump { nick uhost hand chan text } {
  jump $text
}

# Process Server

proc proc_server { nick uhost hand chan text } {
  global serveraddress
  putserv "PRIVMSG $chan :I Am Current Connected To \002$serveraddress\002"
}

# Addop Process

proc proc_addop { nick uhost hand chan text } {
  set addopnick [nick2hand $text]
  if {[validuser $addopnick]} {
    chattr $addopnick +o
    putserv "PRIVMSG $chan :$text Has Been Giving Auto-Op Access"
    putlog "$nick added $addopnick to Auto-Op"
    putquick "MODE $chan +o $text"
    putserv "NOTICE $text :You Have Been Givin Auto-Op Access For Channel: \002$chan\002 use \002!commands\002 To List New Channel Commands Available To You"
  } else { putserv "PRIVMSG $chan :$text Not Found In User Database, Use !whois <nickname>" }
  unset addopnick
}

# Delop Process

proc proc_delop { nick uhost hand chan text } {
  set delopnick [nick2hand $text]
  if {[validuser $delopnick]} {
    chattr $delopnick  -o
    putserv "PRIVMSG $chan :$text Removed From Auto-Op Access"
    putlog "$nick removed $delopnick from Auto-Op"
    putquick "MODE $chan -o $text"
  } else { putserv "PRIVMSG $chan :$text Not Found In User Database, Use !whois <nickname>" }
  unset delopnick
}

# Ban Process

proc proc_ban { nick uhost hand chan text } {
  global botnick
  if {[onchan $text]} {
    if {$text == $botnick} { return 0 }
    set banmask [getchanhost $text $chan]
    putquick "MODE $chan +b $banmask"
    putkick $chan $text :Requested
  } else { putserv "PRIVMSG $chan :$text Is Not In The Channel" }
}

# Unban Process

proc proc_unban { nick uhost hand chan text } {
  if {[ischanban $text $chan]} {
    pushmode $chan -b $text
  } else { putserv "PRIVMSG $chan :$text Is Not In The Ban List" }
}

proc proc_whois { nick uhost hand chan text } {
  set whoisnick [nick2hand $text]
  if {$whoisnick == ""} {
    putserv "PRIVMSG $chan :\002$text\002 Not Currently In Channel: \002$chan\002"
  } elseif {$whoisnick == "*"} { 
    putserv "PRIVMSG $chan :\002$text\002 Not Found In User Database, Use \002!adduser $text\002" 
  } else { putserv "PRIVMSG $chan :I Recognize \002$text\002 As \002$whoisnick\002" }
}  

# Process Opme

proc proc_opme { nick uhost hand chan text } {
  putquick "MODE $chan +o $nick"
}

# Process Deopme

proc proc_deopme { nick uhost hand chan text } {
  putquick "MODE $chan -o $nick"
  putquick "MODE $chan +v $nick"
}

# Process AddUser

proc proc_adduser { nick uhost hand chan text } {
  set addusernick [nick2hand $text]
  if {[validuser $addusernick]} {
   putserv "PRIVMSG $chan :\002$text\002 Is Already In User Database As \002$addusernick\002"
  } else  {
   unset addusernick
   set addusermask [maskhost $text![getchanhost $text $chan]]
   adduser $text $addusermask
   set addusernick [nick2hand $text]
   putlog "\002$nick\002 Added \002$addusernick\($text\)\002 To User Database"
   putserv "PRIVMSG $chan :\002$text\002 Added To User Database As \002$addusernick\002"
   unset addusermask
   unset addusernick
  }
}

# Process DelUser

proc proc_deluser { nick uhost hand chan text } {
  set delusernick [nick2hand $text]
  if {[validuser $delusernick]} {
    deluser $delusernick
    putserv "PRIVMSG $chan :\002$text \($delusernick\)\002 Has Been Removed From User Database"
    putlog "$nick Removed $delusernick From user Database"
  } else { putserv "PRIVMSG $chan :\002$text\002 Not Found In User Database, Use !whois <nickname>" }
}

# Process Kick

proc proc_kick { nick uhost hand chan text } {
  if {[onchan $text]} {
    putquick "KICK $chan $text :Requested"
  } else { putserv "PRIVMSG $chan :\002$text\002 Not In Channel: \002$chan\002" }
}

# Voice Process

proc proc_voice { nick uhost hand chan text } {
  if {[onchan $text]} {
    set voicenick [nick2hand $text]
    if {[validuser $voicenick]} {
      chattr $voicenick +v
      putquick "MODE $chan +v $text"
      putserv "PRIVMSG $chan :\002$text\002 Added To Auto-Voice List"
      putlog "$nick Added $voicenick To Auto-Voice List"
    } else {
      putquick "MODE $chan +v $text"
    }
  } else { putserv "PRIVMSG $chan :\002$text\002 Not Found In Channel: \002$chan\002"
  }
}

# DeVoice Process

proc proc_devoice { nick uhost hand chan text } {
  if {[onchan $text]} {
    set devoicenick [nick2hand $text]
    if {[validuser $devoicenick]} {
      chattr $devoicenick -v
      putquick "MODE $chan -v $text"
      putserv "PRIVMSG $chan :\002$text\002 Removed From Auto-Voice List"
      putlog "$nick Removed $devoicenick From Auto-Voice List"
    } else {
      putquick "MODE $chan -v $text"
    }
   } else { putserv "PRIVMSG $chan :\002$text\002 Not Found In Channel: \002$chan\002" }
}

# Commands Process

proc proc_commands { nick uhost hand chan text } {
  if {[matchattr $hand m|m $chan]} {
   putserv "NOTICE $nick :You Are Currently Bot Master, And Have Access To The Following Commands"
   proc_listcommands $nick $uhost $hand $chan
   return 0
  } elseif {[matchattr $hand o|o $chan]} {
   putserv "NOTICE $nick :You Are Currently Auto-Op, And Have Access To The Following Commands"
   proc_listcommands $nick $uhost $hand $chan
   return 0
  } else {
      putserv "NOTICE $nick :You Are A Basic User, And Have Access To Teh Following Commands"
      proc_listcommands $nick $uhost $hand $chan
      return 0
 }
}

# List Commands Process - This Process Is Where You Can Enter The Commands 
# For The !commands List, Just Follow The Format That Is Listed Below, Also 
# If You Have Commands Listing That You Do Not Have Available On Your Bot, 
# Then You Can Remove The Line For That Command.  Feel Free To Add Any 
# Commands You Have Listed For Your Bot In Here. The Command List Is Broken 
# Down According To Flags In This Order

# Basic - People No Op/Master Flags
# Auto-Op - People Who Have Op Flag. I Used The Default o Flag, You Will 
#  Have To Edit The Flags In Both This Process And The Above Process If You 
#  Use A Different Flag.
# Master - People Who Have Master Flag. Again I Used Default m Flag.

proc proc_listcommands { nick uhost hand chan } {
  global botnick
  putserv "NOTICE $nick :\002Basic User\002 Commands"
  putserv "NOTICE $nick :!seen <nickname> - See When The Last Time <nickname> Was Online"
  putserv "NOTICE $nick :!seennick <nickname> - Search For A Specific Nickname"
  putserv "NOTICE $nick :!google <search keyword\(s\)> - Search Google And Return Top Result"
  putserv "NOTICE $nick :!statsite - Get The Link To The $chan Stats Site"
  putserv "NOTICE $nick :!vibrate - Gets The Bot Vibrating For You"
  putserv "NOTICE $nick :!unf <nickname> - Give Someone A Good Unfin"
  putserv "NOTICE $nick :!slap <nickname> - Slap Someone Around A Bit, DO NOT Abuse This Or You Will Be Banned"
  putserv "NOTICE $nick :!spork <nickname> - Give Someone A Good Sporking"
  putserv "NOTICE $nick :!Top<stat> - Returns The Top Statistics For The <Stat> Type.  Stat Types Are: talk lol smile swear kick time speed"
  putserv "NOTICE $nick :!My<stat> - Returns Your Rating In The Statistics For The <Stat> Type. Stat Types Are: talk lol smile swear kick time speed stat total."
  putserv "NOTICE $nick : - Users Found Abusing The !Top And !My Commands Will Be Banned From The Bot And Stats Will Not Be Recorded For Them.  Please Use Some Courtesy Here."
  putserv "NOTICE $nick :End Of Basic User Commands"
  if {[matchattr $hand o|o $chan]} {
    putserv "NOTICE $nick :\002Auto-Op\002 Commands"
    putserv "NOTICE $nick :!commands - Kinda Obvious Don't Ya Think.."
    putserv "NOTICE $nick :!opme - Have The Bot Op You"
    putserv "NOTICE $nick :!deopme - Have The Bot De-Op You"
    putserv "NOTICE $nick :!op <nickname> - Have The Bot Op Someone"
    putserv "NOTICE $nick :!deop <nickname> - Have Tbe Bot DeOp Someone"
    putserv "NOTICE $nick :!whois <nickname> - Find Out If The Nickname Is In The Bots User Database"
    putserv "NOTICE $nick :!kick <nickname> - Have The Bot To A Quick Kick Of Nickname"
    putserv "NOTICE $nick :!ban <nickname> - Have The Bot Do A Quick Kick/Ban Of Nickname"
    putserv "NOTICE $nick :!server - Find Out What Server:Port The Bot Is On"
    putserv "NOTICE $nick :!lc - Lock The Channel To Prevent Flooding"
    putserv "NOTICE $nick :!uc - Unlock The Channel"
    putserv "NOTICE $nick :!seenstats - Display Database Information For !seen Database"
    putserv "NOTICE $nick :End Of Auto-Op Commands"
  }
  if {[matchattr $hand m|m $chan]} {
    putserv "NOTICE $nick :\002Bot Master\002 Commands"
    putserv "NOTICE $nick :!addop <nickname> - Add The Nickname To The Bots Auto-Op List"
    putserv "NOTICE $nick :!delop <nickname> - Remove The Nickname From The Bots Auto-Op List"
    putserv "NOTICE $nick :!adduser <nickname> - Add  User To The User Database With Default Flags"
    putserv "NOTICE $nick :!deluser <nickname> - Remove A User From The Bots Database, Can Be Used If User Needs To Re-Register With The Bot"
    putserv "NOTICE $nick :!jump <server> - Forces The Bot To Change Servers To Server Entered"
    putserv "NOTICE $nick :!update - Manually Update The Stats Site"
    putserv "NOTICE $nick :getlog <date> - Have A Logfile From A Certain Date Sent To You.  Usage: /msg $botnick  getlog <ddMonyyyy> \(ie getlog 01Jul2005\) Month MUST Have A Capital First Letter"
    putserv "NOTICE $nick :!gban <nickname> - Add A Global Ban To The Bots Internal Ban List (ie: akick)"
    putserv "NOTICE $nick :!noop <nickname> - Adds A Flag To The Nickname That Prevets The Person From Being Op\'d"
    putserv "NOTICE $nick :!allowop <nickname> - Removes The Flag That Prevents People From Getting Op\'d"
    putserv "NOTICE $nick :End Of Bot Master Commands"
  }
}


putlog "*** Op Commands by xTc^bLiTz <xtc_blitz@hotmail.com>  Loaded"
