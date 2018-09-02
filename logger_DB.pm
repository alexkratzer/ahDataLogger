package logger_DB;
use strict;
use DBI;
use msg_dbg_print;

my $DBG =  0; # print more debug info if true 
#my $DB_NAME = "";
#my $DB_DSN = "DBI:mysql:database=$DB_NAME";
#my $DB_USER = "auto_home";
#my $DB_PASSWD = "";

my %ID_Mapping;

my $config_ID_mapping = "config_ID_mapping.txt";

sub msg{
  my $msg = shift;
  my $sender = shift;
  msg_dbg_print::msg($msg,$sender,'logger_DB.pm');
}

#my $dbh = DBI->connect($DB_DSN, $DB_USER, $DB_PASSWD) or die "Fehler bei Datenbankverbindung: $!";
sub connect_DB{ 	
	my %DBconnection = read_config_DB('config_DB.cfg');
	
	#for my $k (keys %DBconnection) { 
	#	msg("DBconnection [$k : $DBconnection{$k}]")
	#}
	
	#msg("####################### connect_DB");
	#msg("$DBconnection{'DB_DSN'}, $DBconnection{'DB_USER'}, $DBconnection{'DB_PASSWD'}");
	
	return (DBI->connect($DBconnection{'DB_DSN'}, $DBconnection{'DB_USER'}, $DBconnection{'DB_PASSWD'}, {PrintError => 1, RaiseError => 0,  AutoCommit => 1})); 
	#return (DBI->connect($DB_DSN, $DB_USER, $DB_PASSWD, {PrintError => 1, RaiseError => 0,  AutoCommit => 1})); 
}

sub log_weather_station{
  my ($dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO weather_station (temperature,sun_south,sun_west,sun_east,light,wind,rain, wind_max) VALUES (?,?,?,?,?,?,?,?)});
  $sth->execute($data[0]/100,$data[1],$data[2],$data[3],$data[4],$data[5]/100,$data[6],$data[7]/1000);
  $sth->finish;
}
sub log_eta_values{
  my ($dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO eta_values (kessel,abgas,pufferladezustand,puffer_oben,puffer_mitte,puffer_unten,kesselruecklauf,kollektor,boiler_solar,aussentemperatur,vorlauf) VALUES (?,?,?,?,?,?,?,?,?,?,?)});
  $sth->execute($data[0]/10,$data[1]/10,$data[2],$data[3]/10,$data[4]/10,$data[5]/10,$data[6]/10,$data[7]/10,$data[8]/10,$data[9]/10,$data[10]/10);
  $sth->finish;
}
sub log_sense{
  my ($dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO plc_sensorik (temperatur_stairs_og,temperatur_floor_eg,lux_stairs_og,humidity_floor_eg,temperatur_EG_CH1,temperatur_EG_CH2,temperatur_EG_CH3,temperatur_EG_CH4) VALUES (?,?,?,?,?,?,?,?)});
  $sth->execute($data[0]/100,$data[1]/100,$data[2],$data[3]/100,$data[4]/100,$data[5]/100,$data[6]/100,$data[7]/100);
  $sth->finish;
}
sub log_eta_burning_time{
  my ($dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO eta_burning_time (turn_on, jear, month, day, hour, minute, secound) VALUES (?,?,?,?,?,?,?)});
  $sth->execute($data[0],$data[1],$data[2],$data[3],$data[4],$data[5],$data[6]);
  $sth->finish;
}

sub log_jal_wind_speed{
  my ($dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO event_jal_drive_up_wind (id_string, id_int, cur_wind_speed, cur_position, cur_angle, alarm_level) VALUES (?,?,?,?,?,?)});
  $sth->execute($data[0],$data[1],$data[2]/100,$data[3],$data[4],$data[5]/100);
  $sth->finish;
}

sub log_heater_switch{
  my ($dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO event_heater_switch (id_string, id_int, state_new, cur_temp) VALUES (?,?,?,?)});
  $sth->execute($data[0],$data[1],$data[2],$data[3]/100);
  $sth->finish;
}

sub diagnostic_operational{
  my ($PLCport,$dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO diagnostic_message (source, value, dbg_data0, dbg_data1, dbg_data2, dbg_data3) VALUES (?,?,?,?,?,?)});
  $sth->execute($PLCport, $data[0],$data[1],$data[2],$data[3],$data[4]);
  $sth->finish;
}

sub diagnostic_message{
  my ($PLCport, $dbh,@data)  = @{$_[0]};
  my $sth = $dbh->prepare(q{INSERT INTO diagnostic_message (source, value) VALUES (?,?)});
  $sth->execute($PLCport, @data);
  $sth->finish;
}

sub diagnostic_DBG{
	eval{
		my ($dbh, $source_port, $source_plc, $data)  = @{$_[0]};
		# msg("[diagnostic_DBG] source_port: $source_port, source_plc: $source_plc, data: $data");
		read_config_file($config_ID_mapping);

		my ($plc_time, $module, $submodule, $type, $value) = split(/;/, $data);
				
		if(!defined($value)){
			msg("ERROR: ### diagnostic_DBG received messega with no initialised value ###", "$source_plc:$source_port");
			return;
		}
		
		$plc_time =~ s/\s+//g; #remove spaces done in rcv process
		my ($Y, $M, $D, $h, $m, $s) = split(/:/, $plc_time);
		my $plc_timestamp = "$Y-$M-$D $h:$m:$s";
				
		$submodule =~ s/\s+//g; #remove spaces done in rcv process
		if (exists($ID_Mapping{$submodule})){
			#msg("found $submodule in ID_Mapping: $ID_Mapping{$submodule}","DBG");
			$submodule = $ID_Mapping{$submodule};
			$submodule	=~ s/\n//g; #remove /n/r
			$submodule 	=~ s/\s+//g; #trimm
		}
		#else{
		#	msg("$submodule : does not exist in ID_Mapping","DBG");
		#	#for my $k (keys %ID_Mapping) { msg("ID_Mapping: " . $k . " : " . $ID_Mapping{$k})}
		#}
		if($DBG){msg("write in DB ==> plc_time:$plc_time, module:$module, submodule:$submodule, type:$type, value:$value", "$source_plc:$source_port");}
		
		#if($module eq "data_logger"){
		if($type eq 'DataLogger'){
			my %value_hash = split /[\|=]/, $value;
			my $format_value;
			foreach my $key (keys %value_hash)
			{
			  $value_hash{$key} = $value_hash{$key}+0;
			  $format_value = $format_value . "$key ==> $value_hash{$key}, ";
			  #print "$key ==> $value_hash{$key} \n";
			}
			my $sth = $dbh->prepare(q{INSERT INTO diag_data_logger (plc_time, source_port, source_plc, module, submodule, type, value) VALUES (?,?,?,?,?,?,?)});
			$sth->execute($plc_timestamp, $source_port, $source_plc, $module, $submodule, $type, $format_value);
			$sth->finish;
			
			if($submodule eq "eta"){
				  my $sth = $dbh->prepare(q{INSERT INTO diag_eta (kessel,abgas,pufferladezustand,puffer_oben,puffer_mitte,puffer_unten,kesselruecklauf,kollektor,boiler_solar,aussentemperatur,vorlauf) VALUES (?,?,?,?,?,?,?,?,?,?,?)});
				  $sth->execute($value_hash{ks}, $value_hash{ag}, $value_hash{pz}, $value_hash{po}, $value_hash{pm}, $value_hash{pu}, $value_hash{kr}, $value_hash{kt}, $value_hash{bu}, $value_hash{at}, $value_hash{vl});
				  $sth->finish;
			}elsif($submodule eq "weather"){
				my $sth = $dbh->prepare(q{INSERT INTO diag_weather (temperature, sun_south, sun_west, sun_east, light, wind, rain, wind_max) VALUES (?,?,?,?,?,?,?,?)});
				$sth->execute($value_hash{temperatur}, $value_hash{sun_south}, $value_hash{sun_west}, $value_hash{sun_east}, $value_hash{light_lux}, $value_hash{wind}, $value_hash{rain}, $value_hash{wind_max});
				$sth->finish;
			}elsif($submodule eq "PLC_sensor_OG"){
				my $sth = $dbh->prepare(q{INSERT INTO diag_plc_sensorik_OG (sense_tmp_stairs, tmp_bath, sense_lux_stairs, tmp_child_east, tmp_DistributionBoxOg, tmp_child_west) VALUES (?, ?, ?, ?, ?, ?)});
				$sth->execute($value_hash{sense_tmp_stairs}, $value_hash{tmp_bath}, $value_hash{sense_lux_stairs}, $value_hash{tmp_child_east}, $value_hash{tmp_DistributionBoxOg}, $value_hash{tmp_child_west});
				$sth->finish;
			}
			elsif($submodule eq "PLC_sensor_EG"){
				my $sth = $dbh->prepare(q{INSERT INTO diag_plc_sensorik_EG (temperature_floor_ug, humidity_floor_ug, CH0_kitchen, CH1_office, CH2_IBS, CH3_dungeon) VALUES (?, ?, ?, ?, ?, ?)});
				$sth->execute($value_hash{tfu}, $value_hash{hfu}, $value_hash{tch0}, $value_hash{tch1}, $value_hash{tch2}, $value_hash{tch3});
				$sth->finish;
			}
		}	
		else{
			my $sth = $dbh->prepare(q{INSERT INTO diagnostic_message (plc_time, source_port, source_plc, module, submodule, type, value) VALUES (?,?,?,?,?,?,?)});
			$sth->execute($plc_timestamp, $source_port, $source_plc, $module, $submodule, $type, $value);
			$sth->finish;
			
			if($type eq 'AktorEvent'){
				my $sth = $dbh->prepare(q{INSERT INTO diag_event_aktor (plc_time, source_port, source_plc, module, submodule, type, value) VALUES (?,?,?,?,?,?,?)});
				$sth->execute($plc_timestamp, $source_port, $source_plc, $module, $submodule, $type, $value);
				$sth->finish;
			}	
		}
	} or do {
		if($DBG){
			my $e = $@;
			msg("#####################################", "logger_DB");
			msg("error logger_DB; diagnostic_DBG: $e\n", "logger_DB");
			msg("#####################################", "logger_DB");
			msg( "error logger_DB; diagnostic_DBG: $e\n"); 
		}
	}
}


#my $dbh = DBI->connect($DB_DSN, $DB_USER, $DB_PASSWD, {PrintError => 1, RaiseError => 0, AutoCommit => 1 }) or die "Fehler bei Datenbankverbindung: $!";  


#sub disconnect{ $dbh->disconnect; }

#sub get_test{    
#    my $sth = $dbh->prepare(q{SELECT * FROM test WHERE ind = ?}) or die $DBI::errstr;
#    $sth->execute("3") or die $DBI::errstr;
#    if(my $zeile = $sth->fetchrow_hashref()){
#      return $zeile->{testds};
#    }  
#    $sth->finish;
#}

sub read_config_file{
	my $conf_file = shift;
	
	if(!defined($conf_file)){msg("call read_config_file with no param: conf_file","");}
	open (my $handle, '<', $conf_file) or die msg("Failed to open file: $!","");
	
	my $row_count = 0;
	while(<$handle>) { 
		$row_count++;
		chomp; 
		if($_=~"#"){;
			#msg("comment in config file (".$row_count."): " . $_);
		}else{
			my ($key,$id,$desc) = split(/:/, $_);
			if(defined($key)){
					if(defined($id)){ #key/value oder connection
						if(defined($desc)){
							if($key eq 'interface'){
								#mapping aktuatorID to aktuatorDescription
								$ID_Mapping{$id} = $desc;
							}
							else{msg("unknown keyword: " . $key,"")}
						}#else{msg("unknown desc at $conf_file line ".$row_count." key: " . $key);}
					}#else{msg("unknown id at $conf_file line ".$row_count." key: " . $key);}
			}#else{msg("unknown key at $conf_file line ".$row_count );} 
		}
	}
	close $handle;
	
	#for my $k (keys %ID_Mapping) { msg("ID_Mapping: " . $k . " : " . $ID_Mapping{$k})}
	#msg("done reading: $conf_file with %ID_Mapping elements");
}
sub read_config_DB{
	my $conf_file = shift;
	my %DBconnection;
	if(!defined($conf_file)){msg("call read_config_DB with no param: conf_file","");}
	open (my $handle, '<', $conf_file) or die msg("Failed to open file: $!","");
	
	while(<$handle>) { 
		chomp; 
		my ($key,$value) = split(/=>/, $_);
		
		if(defined($value)){ 
			$value	=~ s/\n//g; #remove /n/r
			$value 	=~ s/\s+//g; #trimm
			$DBconnection{$key} = $value;
		}		
	}
	close $handle;
	return %DBconnection;
	#for my $k (keys %ID_Mapping) { msg("ID_Mapping: " . $k . " : " . $ID_Mapping{$k})}
	#msg("done reading: $conf_file with %ID_Mapping elements");
}

1;