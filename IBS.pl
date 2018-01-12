#!/usr/bin/perl -w
use strict;
use Data::Dumper;

my $rcv_string = "weather_light_lux=   1.123000E+0*weather_rain=   0.000000E+0*weather_sun_east=   0.345000E+0*weather_sun_south=   0.555500E+0*weather_sun_west=   0.111100E+0*weather_temperatur=   2.000000E+0*weather_w";
my $str2="sense_lux_stairs=   2.600000E+1|sense_tmp_stairs=   2.104673E+1|tmp_bath=   2.180000E+1|tmp_child_east=   2.040000E+1|tmp_child_west=   2.050000E+1|tmp_DistributionBoxOg=   2.990000E+1|";

sub msg{
  my $msg = shift;
  print "$msg \n";
}


##############################################################################
################################## main ######################################
##############################################################################

msg( "========= start logger ===========");
msg( "str2: $str2");
msg( " DONE\n");

my @data_value_list_pipe = split /\|/, $str2;
print "data_value_list_pipe: @data_value_list_pipe \n";
foreach(@data_value_list_pipe){
	print "$_ \n";
}

print "HASH  \n";
#my $string = "1:one;2:two;3:three";
#my %hash = split /[;:]/, $string;
my %hash = split /[\|=]/, $str2;

print Dumper \%hash;


print "HASH foreach \n";
foreach my $key (keys %hash)
{
  print "$key equals $hash{$key} \n";
}


print "\nwith addition: \n";

foreach my $key (keys %hash)
{
  $hash{$key} = $hash{$key}+0;
  print "$key equals $hash{$key} \n";
}
msg( "\n\n============= start logger [DONE] ===============\n");
