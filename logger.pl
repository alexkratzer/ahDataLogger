#!/usr/bin/perl -w
#nohup /volume1/homes/git_repos/AutoHome_data-logger/logger_EG.pl > /volume1/homes/git_repos/AutoHome_data-logger/data_logger.out&

#eintrag in /etc/crontab
#0 * * * * root  perl /volume1/homes/git_repos/AutoHome_data-logger/logger.pl
#restart crontab
#synoservicecfg --restart crond

#=======================
# supportet ARGV:
# "restart" -> restart all logger prozesses
# "kill" -> kill all logger prozesses
# "check" -> verify if $prozess_name is running
#
#=======================

use strict;
use msg_dbg_print;
use Cwd;

my $workingDir = getcwd()."/";#'/volume1/homes/git_repos/ahDataLogger/';
my $config_file = 'config_mapping.txt';
# my $log_file = '/volume1/homes/git_repos/AutoHome_data-logger/logger.log';

my $logger_prozess = "logger_prozess.pl";
my $logger_diagnostic_prozess = "logger_diagnostic_prozess.pl";

#stores config data from file: $config_file
my %config;

#print $msg to logfile
sub msg{
  my $msg = shift;
  msg_dbg_print::msg($msg,'main','logger');
}

#sub msg{
#  my $msg = shift;
#  my $print_msg = "[" . localtime(time) . "] [logger_DB.pm] $msg\n";  
#  open (my $fh, '>>', $log_file) or die "Kann Datei $log_file nicht zum Schreiben oeffnen: $!\n";
#  print $fh $print_msg; 
#  close $fh;
#  if($DBG){ print $print_msg; }
#}


#`nohup /volume1/homes/git_repos/AutoHome_data-logger/logger_EG.pl > /volume1/homes/git_repos/AutoHome_data-logger/logger_EG.out&`;
sub start_prozess{
	msg("start_prozess at workingDir: .$workingDir");
	
	my $ps = $workingDir . $logger_prozess;
	foreach (@{$config{'connect'}}) {
	    msg("try start prozess at listen port: $_");
		system("$ps $config{LocalHost} $_ $config{$_}  &");
		sleep(1); #wartezeit damit subscript zeit für zugriff auf logdatei hat
	}
	
	#my $ps_diag = "/volume1/homes/git_repos/AutoHome_data-logger/$logger_diagnostic_prozess";
	my $ps_diag = $workingDir . $logger_diagnostic_prozess;
	foreach (@{$config{'connect_diagnostic'}}) {
	    msg("try start diag prozess at listen port: $_");
		system("$ps_diag $config{LocalHost} $_ $config{$_}  &");
		sleep(1); #wartezeit damit subscript zeit für zugriff auf logdatei hat
	}
}

sub kill_prozess{
	my @prozess_list =  @{$_[0]};
	msg("kill prozess count: " . @prozess_list);
	
	if(@prozess_list){
		foreach(@prozess_list){
			`kill $_`;
			#msg( "killed ps ID: [".$_."] ");
		}	
	}
	else{ msg( "no prozess to kill exists "); }
}

#verify if $logger_prozess is running
sub check_ps{
	my @prozess = `ps -aux`;
	my $ps_id;
	my @ps_list;
	
	msg("check process total: ".@prozess. " / connect: ".@{$config{'connect'}} . " / connect_diagnostic: " . @{$config{'connect_diagnostic'}});
	foreach(@prozess) {
	  if ($_ =~ /$logger_prozess/ ) {
		($ps_id) = $_ =~ m/(\d+)/;
		#msg("found ps [".$logger_prozess."] with id: [".$ps_id."]");
		push(@ps_list, $ps_id);
	  }
	  if ($_ =~ /$logger_diagnostic_prozess/ ) {
		($ps_id) = $_ =~ m/(\d+)/;
		#msg("found ps diag [".$logger_diagnostic_prozess."] with id: [".$ps_id."]");
		push(@ps_list, $ps_id);
	  }
	}
	
	msg("found running logger processes ".@ps_list);
	return \@ps_list;
}

#TODO: read corect count from check_ps retval array
sub count_running{
	my @prozess = `ps -aux`;
	
	msg("check process running: ".@prozess. " / conf process: ".@{$config{'connect'}}. " / conf diag: " . @{$config{'connect_diagnostic'}});
	my $count = 0;
	foreach(@prozess) {
		if ($_ =~ /$logger_prozess/ ) { $count++;  }
		if ($_ =~ /$logger_diagnostic_prozess/ ) { $count++;  }
	}
	return $count;
}

sub verify_connections{
	my @prozess_list =  @{$_[0]};
	msg("verify_connections prozess count: " . @prozess_list);
	
	my $conn_conf = @{$config{'connect'}} + @{$config{'connect_diagnostic'}};
	my $conn_running = count_running();
	
	msg("conn_conf " . $conn_conf . " / conn_running " . $conn_running);
	
	if($conn_conf == $conn_running){ return 1;}else{ return 0;}
}

sub read_config_file{
	my $conf_file = shift;
	#logger_DB::read_config_file("config_ID_mapping.txt");
	
	if(!defined($conf_file)){msg("call read_config_file with no param: conf_file");}
	open (my $handle, '<', $conf_file) or die msg("Failed to open file: $!");
	
	my $row_count = 0;
	while(<$handle>) { 
		$row_count++;
		chomp; 
		if($_=~"#"){;
			#msg("comment in config file (".$row_count."): " . $_);
		}else{
			
			#$_ =~ s/\n//g; #remove /n/r
			my ($key,$value,$PLCname) = split(/:/, $_);
			
			if(defined($key)){
				
					if(defined($value)){ #key/value oder connection
					
						if(defined($PLCname)){
						$PLCname	=~ s/\n//g; #remove /n/r
						$PLCname 	=~ s/\s+//g; #trimm
						
							if($key eq 'connect'){
								#mapping port zu plc name
								$config{$value} = $PLCname; 
								push( @{$config{'connect'}}, $value); 
							}elsif($key eq 'connect_diagnostic'){
								#mapping port zu plc name
								$config{$value} = $PLCname; 
								push( @{$config{'connect_diagnostic'}}, $value); 
							}
							#elsif($key eq 'interface'){
							#	#mapping aktuatorID to aktuatorDescription
							#	$config{$value} = $PLCname;
							#}
							else{msg("unknown keyword: " . $key)}
						}else{#wenn keine connection
							$config{$key} = $value;
						}
					}#else{msg("unknown config value at $config_file line ".$row_count." key: " . $key);}
			}#else{msg("unknown config value at $config_file line ".$row_count );} 
		}
	}
	close $handle;
	
	# msg("read config with connections parametrized: process " . @{$config{'connect'}} . " / diag: " . @{$config{'connect_diagnostic'}} );
	#for my $k (keys %config) { msg("config: " . $k . " : " . $config{$k})}
	return %config;
}


##############################################################################
################################## main ######################################
##############################################################################

read_config_file($config_file);

if($ARGV[0]){ msg( "========= start logger [$ARGV[0]] ==========="); 
#stores config data from file: $config_file
	
#if(check_ps(%config)){
#msg( "check_ps()==true");
#}else{
#msg( "check_ps()==false");
#}
	
  if($ARGV[0] eq "restart"){
	kill_prozess(check_ps());
	start_prozess();
	check_ps();
  }elsif($ARGV[0] eq "check"){
    check_ps();
  }elsif($ARGV[0] eq "kill"){
    kill_prozess(check_ps());
  }elsif($ARGV[0] eq "dbg"){
  	kill_prozess(check_ps());
	start_prozess();
	check_ps();
  }
  else{msg( "argv is not supportet: " . $ARGV[0] );}
}
else{ msg( "========= start logger [no ARGVs]  ==========="); 
	if(verify_connections(check_ps())){ msg("nothing to do, running == configured")}
	else{start_prozess()}
}
  
msg( "============= start logger [DONE] ===============\n");
