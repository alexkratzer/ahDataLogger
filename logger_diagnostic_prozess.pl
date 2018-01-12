#!/usr/bin/perl -w

use strict;
#use lib '/volume1/homes/git_repos/AutoHome_data-logger';
use IO::Socket;
use logger_DB;
use msg_dbg_print;

# my $log_file = '/volume1/homes/git_repos/AutoHome_data-logger/logger_prozess_diagnostic.log';

my $DBG = 0; # print more debug info if true 
$| = 1;   # auto-flush on socket

my %param = (localhost => $ARGV[0], port => $ARGV[1], PLCname => $ARGV[2]);

#for my $k (keys %param) { print "ARGV param: " . $k . " : " . $param{$k} . "\n";}

sub msg{
  my $msg = shift;
  my $sender = shift;
  msg_dbg_print::msg($msg,$sender,'logger_diagnostic');
  
  #my $print_msg = "[" . localtime(time) . "] [logger_diagnostic_prozess] $msg\n";
  
  #open (my $fh, '>>', $log_file) or die "Kann Datei $log_file nicht zum Schreiben oeffnen: $!\n";
  #print $fh $print_msg; 
  #close $fh;
  #if($DBG){ print $print_msg; }
}

#print "\n\nARGV count: " . @ARGV . "\n";
#for (my $i=0; $i<@ARGV; $i++)
#{
#	print "ARGV " . $i . " -> " . $ARGV[$i] . "\n";
#}

if(@ARGV==3){
	# msg("call logger_prozess with: \n localhost => ".$ARGV[0]."\n port => ".$ARGV[1]."\n PLCname => ".$ARGV[2]);
	srv(%param);
}
else{
	msg( "call with [".@ARGV."] ARGV (3 are nessesary!)", "ERROR");
	return;
}

#sub print_dbg{
#	my $data = $_[0];
#	msg("print_dbg");
#	foreach (@$data){
#		print $_ . ", ";
#    }
#}
#sub print_dbg_scalar{
#	my $data = shift;
#	msg("print_dbg_scalar: " . $data);
#}
#sub print_dbg_shift{
#	my ($PLCport, $dbh, $data)  = @{$_[0]};
#	msg("print_dbg_shift PLCport: " . $PLCport);
#	msg("print_dbg_shift data: " . $data);
#}

sub srv{
	my %param = @_;
	
	my $socket = new IO::Socket::INET (
		LocalHost => $param{localhost},
		LocalPort => $param{port},
		Proto => 'tcp',
		Listen => 5,
		Reuse => 1
	) or die msg( "ERROR: couldn't open socket on: $param{localhost}:$param{port}", "$param{localhost}:$param{port}");
	
	msg( "start SERVER", "$param{PLCname}:$param{port}");
	
	while(1){
		my $client_socket = $socket->accept();
		my $data = "";
		$client_socket->recv($data, 1024);
		
		unless($data eq ""){
			#$data =~ s/\s+//g; #remove all spaces from msg
			if($DBG){ msg( "RCV frame ==> $data", "$param{PLCname}:$param{port}"); }
			#print_dbg_scalar($data);
			
			my $dbh = logger_DB::connect_DB();
			my @data_shift = ($dbh, $param{port}, $param{PLCname}, $data);
			# print_dbg_shift(\@data_shift);			
			logger_DB::diagnostic_DBG(\@data_shift);		
			$dbh->disconnect();
		}else{ msg( "### received empty diagnostic frame, no DB writing ###", "$param{PLCname}:$param{port}"); }
	}
	
	$socket->close();
	
}

1;
 