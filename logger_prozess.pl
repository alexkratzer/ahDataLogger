#!/usr/bin/perl -w

use strict;
#use lib '/volume1/homes/git_repos/AutoHome_data-logger';
use IO::Socket;
use logger_DB;
use msg_dbg_print;

# my $log_file = '/volume1/homes/git_repos/AutoHome_data-logger/logger_prozess.log';

my $DBG = 0; # print more debug info if true (set_dbg())
$| = 1;   # auto-flush on socket

my %param = (localhost => $ARGV[0], port => $ARGV[1], PLCname => $ARGV[2]);

#for my $k (keys %param) { print "ARGV param: " . $k . " : " . $param{$k} . "\n";}

#print "\n\nARGV count: " . @ARGV . "\n";
#for (my $i=0; $i<@ARGV; $i++)
#{
#	print "ARGV " . $i . " -> " . $ARGV[$i] . "\n";
#}

#sub msg{
#  my $msg = shift;
#  my $print_msg = "[" . localtime(time) . "] [logger_prozess] $msg\n";  
#  open (my $fh, '>>', $log_file) or die "Kann Datei $log_file nicht zum Schreiben oeffnen: $!\n";
#  print $fh $print_msg; 
#  close $fh;
#  if($DBG){ print $print_msg; }
#}

sub msg{
  my $msg = shift;
  my $sender = shift;
  msg_dbg_print::msg($msg,$sender,'logger_prozess');
}



if(@ARGV==3){
	# msg("call logger_prozess with: \n localhost => ".$ARGV[0]."\n port => ".$ARGV[1]."\n PLCname => ".$ARGV[2]);
	srv(%param);
}
else{
	msg( "call with [".@ARGV."] ARGV (3 are nessesary!)", "ERROR");
	return;
}

#wertet die empfangenen daten aus und übergiebt sie an datenbank
sub evaluate{
	my ($PLCname, $dbh, $index, $job, @data) = @{$_[0]};
	if($DBG){
		my $tmp_data = "";
		foreach (@data){ $tmp_data = "$tmp_data$_|"; }
		msg("[evaluate] index:$index, job:$job, data:$tmp_data", $PLCname);
	}
      
	if($index == 1){ #=================== Data Logger cyclic =================#
		if($job == 2){ ####### eta values #####
			unshift(@data, $dbh);
			logger_DB::log_eta_values(\@data);
			#print localtime(time) . " log eta\n";
		}
		elsif($job == 3){ ####### weather_station ######### 
			  unshift(@data, $dbh);
			  logger_DB::log_weather_station(\@data);
			  #print localtime(time) . " log weather_station\n";
		}
		elsif($job == 4){ ####### plc_sense ######### 
			unshift(@data, $dbh);
			logger_DB::log_sense(\@data);
			#print localtime(time) . " log sense\n";
		}
		else{msg("ERROR: unknown job at $index: $job", $PLCname);}
	}
	elsif($index == 2){ #=================== Data Logger event =================#
		if($job == 1){ #### eta burning time ######
			unshift(@data, $dbh);
			logger_DB::log_eta_burning_time(\@data);
		}
		elsif($job == 2){ ####### jal drive up wind speed ######### 
			unshift(@data, $dbh);
			logger_DB::log_jal_wind_speed(\@data);
		}
		elsif($job == 3){ ####### heater_switch ######### 
			unshift(@data, $dbh);
			logger_DB::log_heater_switch(\@data);
		}
		else{msg("ERROR: unknown job at $index: $job", $PLCname);}
	}
	elsif($index == 3){ ;#=================== diagnostic #DO NOT USE -> see logger_diagnostic_prozess #  =================#
		#msg( "ERROR: unknown job at $index: $job");
		#msg("diagnostic DO NOT USE -> see logger_diagnostic_prozess");
#		if($job == 1){ #### system_message ######
#			unshift(@data, $dbh);
#			unshift(@data, $PLCname);
#			logger_DB::diagnostic_message(\@data);
#		}
#		elsif($job == 2){ ####### diagnostic_operational ######### 
#			unshift(@data, $dbh);
#			unshift(@data, $PLCname);
#			logger_DB::diagnostic_operational(\@data);
#		}
#		elsif($job == 3){ ####### diagnostic DBG ######### 
#			unshift(@data, $dbh);
#			unshift(@data, $PLCname);
#			logger_DB::diagnostic_DBG(\@data);
#		}
#		else{msg( "ERROR: unknown job at $index: $job");}
	}
	elsif($index == 99) #dbg ibs tmp
		{ msg("rcv dbg ibs tmp data index 99", $PLCname); }
	else{msg("ERROR unknown index: $index", $PLCname);} 
}

#wandelt negative zahlen um da über netzwerk unsigned übertragen wird
sub convert_uint16_int16{
  my $data = $_[0];
  my @data_convert;
  
  #print "convert_uint16_int16: ";
  foreach (@$data){
  #  print $_ . ", ";
    push (@data_convert, ($_ & 0x8000) ? -((~$_ & 0xffff) + 1) : $_);
  }
  #print "\n"; 
  return (\@data_convert);
}

sub srv{
	#my ($LocalHost, $port) = shift;
	my %param = @_;
	#my %param = (localhost => $ARGV[0], port => $ARGV[1]);

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
			my @data_unpack = unpack("n*", $data);	
			if($DBG){ msg( "RCV frame ==> (length: " . @data_unpack . ")", "$param{PLCname}:$param{port}"); }
			
			my $data_unpack_conv = &convert_uint16_int16(\@data_unpack);
			
			#my @data_array;
			#print "after convert: ";
			#foreach (@$data_unpack_conv){
			#  print $_ . ", "; 
			#push (@data_array, $_);
			#}
			
			my $dbh = logger_DB::connect_DB();
			unshift(@$data_unpack_conv, $dbh);
			#my $tmp_name = chomp($param{PLCname});
			#my $tmp_port = chomp($param{port});
			unshift(@$data_unpack_conv, "$param{PLCname}:$param{port}");
			#unshift(@$data_unpack_conv, $tmp_name . ":" . $tmp_port );
			evaluate(\@$data_unpack_conv);
			$dbh->disconnect();
		}else{ msg( "### received empty frame, no DB writing ###", "$param{PLCname}:$param{port}"); }
	}
	
	$socket->close();
}

1;
