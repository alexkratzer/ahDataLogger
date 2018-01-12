package msg_dbg_print;

use strict;

my $log_file = "logger.log";
my $DBG = 1; # print more debug info if true 

sub msg{
  my $msg = shift;
  my $sender_plc = shift;
  my $sender_module = shift;
  
  if(!defined($sender_plc)){
	$sender_plc = "undef";
  }
  if(!defined($sender_module)){
	$sender_module = "undef";
  }
  
  
  my $print_msg = localtime(time) . " [$sender_plc - $sender_module] $msg\n";
  
  open (my $fh, '>>', $log_file) or die "Kann Datei $log_file nicht zum Schreiben oeffnen: $!\n";
  print $fh $print_msg; 
  close $fh;
  print $print_msg;
}

1;