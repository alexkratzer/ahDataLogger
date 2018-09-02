#!/usr/bin/perl -w

use strict;
#use lib '/volume1/homes/git_repos/AutoHome_data-logger';
use IO::Socket;
use msg_dbg_print;

# my $log_file = '/volume1/homes/git_repos/AutoHome_data-logger/logger_prozess_diagnostic.log';

my $DBG = 1; # print more debug info if true 
$| = 1;   # auto-flush on socket

my %param = (localhost => $ARGV[0], port => $ARGV[1], PLCname => $ARGV[2]);

#for my $k (keys %param) { print "ARGV param: " . $k . " : " . $param{$k} . "\n";}

sub msg{
  my $msg = shift;
  my $sender = shift;
  msg_dbg_print::msg($msg,$sender,'mqtListener');
}

if(@ARGV==3){
	# msg("call logger_prozess with: \n localhost => ".$ARGV[0]."\n port => ".$ARGV[1]."\n PLCname => ".$ARGV[2]);
	srv(%param);
}
else{
	msg( "call with [".@ARGV."] ARGV (3 are nessesary!)", "ERROR");
	return;
}

sub srv{
	my %param = @_;
	
	my $socket = new IO::Socket::INET (
		LocalHost => $param{localhost},
		LocalPort => $param{port},
		Proto => 'tcp',
		Listen => 5,
		Reuse => 1
	) or die msg( "ERROR: couldn't open socket on: $param{localhost}:$param{port}", "$param{localhost}:$param{port}");
	
	msg( "start mqtListener", "$param{PLCname}:$param{port}");
	
	while(1){
		my $client_socket = $socket->accept();
		my $data = "";
		$client_socket->recv($data, 1024);
		
		unless($data eq ""){
			#$data =~ s/\s+//g; #remove all spaces from msg
			#if($DBG){ msg( "RCV frame ==> $data", "$param{PLCname}:$param{port}"); }
			#msg( "RCV frame ==> $data", "$param{PLCname}:$param{port}");
			my ($topic, $msg) = split(/;#/, $data);
			msg( "[$topic] $msg", "$param{PLCname}:$param{port}");

			#my $dbh = logger_DB::connect_DB();
			#my @data_shift = ($param{port}, $param{PLCname}, $data);
			#logger_DB::diagnostic_DBG(\@data_shift);		
			#$dbh->disconnect();
		}else{ msg( "### received empty mqt frame, no printing ###", "$param{PLCname}:$param{port}"); }
	}
	
	$socket->close();
	
}

1;
 