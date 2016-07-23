#!/usr/bin/perl -i
use strict;
use warnings;

# Always helpful
use Math::Round;
use POSIX qw[ceil floor];
use List::Util qw[min max];
use constant PI    => 4 * atan2(1, 1);

##########
# SETUP
# this contains the default settings, no need to change them here,
# you can change them in the comments of your start- or end-gcode
##########

# printing parameters
my %parameters=();

# default wave parameters
$parameters{"wave_amplitude"}=2.0; # [mm] the maximum amplitude of the wavyness
$parameters{"wave_length"}=20.0; # [mm] the half wave length in xy direction of the waves
$parameters{"wave_length_2"}=200.0; # [mm] the half wave length in xy direction of the waves
$parameters{"wave_in"}=0.4; # [mm] the z-position where it starts getting wavy, should be somewhere above the first layer
$parameters{"wave_out"}=30.0; # [mm] the z-position where it stops beeing wavy
$parameters{"wave_ramp"}=10; # [mm] the length of the transition between not wavy at all and maximum wavyness
$parameters{"wave_max_segment_length"}=1.0; # [mm] max. length of the wave segments, smaller values give a better approximation
$parameters{"wave_digits"}=4; # [1] accuracy of output g-code
$parameters{"bed_center_x"}=0; # [mm] x-position of bed center / where Slic3r centers the objects
$parameters{"bed_center_y"}=0; # [mm] y-position of bed center / where Slic3r centers the objects
$parameters{"wave_function"}="wave"; # can be "wave", "wing" or any Perl function that returns a numeric value.

# gcode inputBuffer
my @inputBuffer=();
my @outputBuffer=();

# gcode simple tracking
my $gcodeX=0;
my $gcodeY=0;
my $gcodeZ=0;
my $gcodeE=0;
my $gcodeF=4500;
my $lastGcodeX=$gcodeX;
my $lastGcodeY=$gcodeY;
my $lastGcodeZ=$gcodeZ;
my $lastGcodeE=$gcodeE;
my $lastGcodeF=$gcodeF;

# state variables, keeping track of what we're doing
my $start=0; # is set to 1 after ; start of print
my $end=0; # is set to 1 before ; end of print

##########
# INITIALIZE
# if you want to initialize variables based on printing parameters, do it here, all printing parameters are available in $parameters
##########

sub init{
	#for(my $i=0;$i<$parameters{"extruders"};$i++){
	#}
}

##########
# MATH
# We need a bit of math for our non-planar layer FDM. Calculating extrusions,
# distances, segmenting moves. We have to define this math here so that we
# can use it later in the PROCESSING part.
##########

# calculating distances in R3
sub dist3
{
	my $x1 = $_[0],	my $y1 = $_[1],	my $z1 = $_[2],	my $x2 = $_[3],	my $y2 = $_[4], my $z2;
	return sqrt(($x2-$x1)**2 + ($y2-$y1)**2 + ($z2-$z1)**2);
}

# calculating distances in R2
sub dist2
{
	my $x1 = $_[0],	my $y1 = $_[1],	my $x2 = $_[2],	my $y2 = $_[3];
	return sqrt(($x2-$x1)**2 + ($y2-$y1)**2);
}

# calculating distances in R1
sub dist1
{
	my $s1 = $_[0],	my $s2 = $_[1];
	return abs($s2-$s1);
}

# round and trim
sub digitize
{
	my $num=$_[0], my $digits=$_[1];
	my $factor=10**$digits;
	return (round($num*$factor))/$factor;
}

# calculating the transition factor as a function of the current z-coordinate, returns a value between 0.0 and 1.0, depending on how much displacement shall be applied in calculate_z_displacement.
sub calculate_ramps{
	my $z=$_[0];

	my $rampA = max( min( ($z-$parameters{"wave_in"}) / $parameters{"wave_ramp"} , 1.0 ) , 0.0 );
	my $rampB = 1.0 - max( min( ($z-$parameters{"wave_out"}+$parameters{"wave_ramp"})/$parameters{"wave_ramp"} , 1.0 ) , 0.0 );

	return $rampA * $rampB;
}

# calculating the z-displacement
sub calculate_z_displacement
{
	my $x = $_[0], my $y = $_[1], my $z = $_[2];
	my $ramps = calculate_ramps($z);

	my $zOffset=0.0;

	# I added two preconfigured displacement functions ("wave" and "wing") along with a freely configurable one (using eval -_-). This is a little messy.
	if((exists $parameters{"wave_function"}) && ($parameters{"wave_function"} eq "wave")){
		#print("; wave found\n");
		$zOffset = 0.0 - $parameters{"wave_amplitude"}/2.0 + $parameters{"wave_amplitude"}/4.0*sin(($x-$parameters{"bed_center_x"})*2*PI/$parameters{"wave_length"}) + $parameters{"wave_amplitude"}/4.0*sin(($y-$parameters{"bed_center_y"})*2*PI/$parameters{"wave_length"});
	}elsif((exists $parameters{"wave_function"}) && ($parameters{"wave_function"} eq "wing")){
		#if(($x-$parameters{"bed_center_x"})>-$parameters{"wave_length"}/2 && ($x-$parameters{"bed_center_x"})<$parameters{"wave_length"}/2){
			$zOffset = -$parameters{"wave_amplitude"}/2.0 + ( $parameters{"wave_amplitude"} * sin( ( ($x-$parameters{"bed_center_x"})*sqrt(PI)/$parameters{"wave_length"}-sqrt(PI)/2.0 )**2 ) ) * ( 1.0 + 0.5*cos(($y-$parameters{"bed_center_y"}-$parameters{"wave_length_2"}/4.0)*2*PI/$parameters{"wave_length_2"}) );
		#}
	}elsif(exists $parameters{"wave_function"}){
		$zOffset = eval($parameters{"wave_function"});
	}else{
		#print("; nothing found\n");
	}

	$zOffset *= $ramps;
	return $zOffset;
}

# approximating the extrusion multiplier to compensate for the transitions from zero displacement to full displacement (or other layer-height-differentials, depending on how you calculate_z_displacement)
sub calculate_extrusion_multiplier
{
	my $x=$_[0], my $y=$_[1], my $z=$_[2];

	my $ramps = calculate_ramps($z);
	my $this = calculate_z_displacement($x, $y, $z);
	my $last = calculate_z_displacement($x, $y, $z-$parameters{"layer_height"});
	return 1.0+($this-$last)/$parameters{"layer_height"};
}

# chopping a g-code move into smaller segments and displacing these
sub displace_move
{
	my $thisLine= $_[0], my $X = $_[1],	my $Y = $_[2],	my $Z = $_[3],	my $E = $_[4],	my $F = $_[5], my $verbose = $_[6];

	# we don't need to displace anything below the in-point and above the out-point
	if($gcodeZ>=$parameters{"wave_in"} && $gcodeZ<=$parameters{"wave_out"}){

		# getting a complete set of coordinates
		my $x = $X || $lastGcodeX;
		my $y = $Y || $lastGcodeY;
		my $z = $Z || $lastGcodeZ;
		my $e = $E || $lastGcodeE;
		my $f = $F || $lastGcodeF;

		# calculating the distance of the move
		my $distance=dist2($lastGcodeX, $lastGcodeY, $x, $y);

		# determining how many segments we need to stay below $parameters{"wave_max_segment_length"}
		# cannot be below 1, since at least 1 segment is required for a move to happen
		my $segments=max(ceil($distance/$parameters{"wave_max_segment_length"}), 1);

		# the chunk of gcode we're about to generate
		my $gcode = " ; displaced move start ($segments segments)\n";

		# interating over the segments and generating the new gcode
		for (my $k=0; $k<$segments; $k++) {
			# calculating the end point of this segment (including z, without displacment)
			my $segmentX=$lastGcodeX+($k+1)*($x-$lastGcodeX)/$segments;
			my $segmentY=$lastGcodeY+($k+1)*($y-$lastGcodeY)/$segments;
			my $segmentZ=$lastGcodeZ+($k+1)*($z-$lastGcodeZ)/$segments;
			# calculating the feedrate at the end of this segment (this value isn't used, useful for other gcode flavors)
			#my $segmentF=$lastGcodeF+($k+1)*($f-$lastGcodeF)/$segments;
			# calculating how much to extrude in this segment
			my $segmentE=$gcodeE/$segments; # only relative extrusion
			# applying the extrusion multiplier based on the undisplaced z-position of this segment
			$segmentE*=calculate_extrusion_multiplier($segmentX,$segmentY,$segmentZ);
			# displacing the z-position of this segment
			$segmentZ+=calculate_z_displacement($segmentX,$segmentY,$segmentZ);

			# generating the gcode. adresses that have not been specified are omitted (except for Z)
			$gcode .= "G1";
			$gcode .= " X".digitize($segmentX, $parameters{"wave_digits"}) if defined $X;
			$gcode .= " Y".digitize($segmentY, $parameters{"wave_digits"}) if defined $Y;
			$gcode .= " Z".digitize($segmentZ, $parameters{"wave_digits"});
			$gcode .= " E".digitize($segmentE, $parameters{"wave_digits"}) if defined $E;
			$gcode .= " F".$F if defined $F;
			$gcode .= " ; segment $k\n";
		}
		$gcode .= " ; displaced move end\n";
		return $gcode;
	}else{
		return $thisLine;
	}
}



##########
# PROCESSING
# here you can define what you want to do with your G-Code
# Typically, you have $X, $Y, $Z, $E and $F (numeric values) and $thisLine (plain G-Code) available.
# If you activate "verbose G-Code" in Slic3r's output options, you'll also get the verbose comment in $verbose.
##########

sub process_start_gcode
{
	my $thisLine=$_[0];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub	process_end_gcode
{
	my $thisLine=$_[0];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub process_tool_change
{
	my $thisLine=$_[0],	my $T=$_[1], my $verbose=$_[2];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub process_comment
{
	my $thisLine=$_[0], my $C=$_[1], my $verbose=$_[2];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub process_layer_change
{
	my $thisLine=$_[0],	my $Z=$_[1], my $verbose=$_[2];
	# add code here or just return $thisLine;
	return displace_move($thisLine, my $X, my $Y, $Z, my $E, my $F, $verbose);
}

sub process_retraction_move
{
	my $thisLine=$_[0], my $E=$_[1], my $F=$_[2], my $verbose=$_[3];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub process_printing_move
{
	my $thisLine=$_[0], my $X = $_[1], my $Y = $_[2], my $Z = $_[3], my $E = $_[4], my $F = $_[5], my $verbose=$_[6];
	# add code here or just return $thisLine;
	return displace_move($thisLine, $X, $Y, $Z, $E, $F, $verbose);
}

sub process_travel_move
{
	my $thisLine=$_[0], my $X=$_[1], my $Y=$_[2], my $Z=$_[3], my $F=$_[4], my $verbose=$_[5];
	# add code here or just return $thisLine;
	return displace_move($thisLine, $X, $Y, $Z, my $E, $F, $verbose);
}

sub process_absolute_extrusion
{
	my $thisLine=$_[0], my $verbose=$_[1];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub process_relative_extrusion
{
	my $thisLine=$_[0], my $verbose=$_[1];
	# add code here or just return $thisLine;
	return $thisLine;
}

sub process_other
{
	my $thisLine=$_[0], my $verbose=$_[1];
	# add code here or just return $thisLine;
	return $thisLine;
}

##########
# FILTER THE G-CODE
# here the G-code is filtered and the processing routines are called
##########

sub filter_print_gcode
{
	my $thisLine=$_[0];
	if($thisLine=~/^\h*;(.*?)\h*/){
		# ;: lines that only contain comments
		my $C=$1; # the comment
		return process_comment($thisLine,$C);
	}elsif ($thisLine=~/^T(\d)(\h*;\h*([\h\w_-]*)\h*)?/){
		# T: tool changes
		my $T=$1; # the tool number
		return process_tool_change($thisLine,$T);
	}elsif($thisLine=~/^G[01](\h+X(-?\d*\.?\d+))?(\h+Y(-?\d*\.?\d+))?(\h+Z(-?\d*\.?\d+))?(\h+E(-?\d*\.?\d+))?(\h+F(\d*\.?\d+))?(\h*;\h*([\h\w_-]*)\h*)?/){
		# G0 and G1 moves
		my $X=$2, my $Y=$4,	my $Z=$6, my $E=$8,	my $F=$10, my $verbose=$12;

		# tracking
		$lastGcodeX=$gcodeX;
		$lastGcodeY=$gcodeY;
		$lastGcodeZ=$gcodeZ;
		$lastGcodeE=$gcodeE;
		$lastGcodeF=$gcodeF;
		$gcodeX = $X || $gcodeX;
		$gcodeY = $Y || $gcodeY;
		$gcodeZ = $Z || $gcodeZ;
		$gcodeE = $E || $gcodeE;
		$gcodeF = $F || $gcodeF;

		# regular moves and z-moves
		if($E){
			# seen E
			if($X || $Y || $Z){
				# seen X,Y or Z
				return process_printing_move($thisLine, $X, $Y, $Z, $E, $F, $verbose);
			}else{
				# seen E, but not X, Y or Z
				return process_retraction_move($thisLine, $E, $F, $verbose);
			}
		}else{
			# not seen E
			if($Z && !($X || $Y)){
				# seen Z, but not X or Y
				return process_layer_change($thisLine, $Z, $F, $verbose);
			}else{
				# seen X or Y (and possibly also Z)
				return process_travel_move($thisLine, $X, $Y, $Z, $F, $verbose);
			}
		}

	}elsif($thisLine=~/^G92(\h+X(-?\d*\.?\d+))?(\h*Y(-?\d*\.?\d+))?(\h+Z(-?\d*\.?\d+))?(\h+E(-?\d*\.?\d+))?(\h*;\h*([\h\w_-]*)\h*)?/){
		# G92: touching of axis
		my $X=$2,	my $Y=$4, my $Z=$6, my $E=$8, my $verbose=$10;
		return process_touch_off($thisLine, $X, $Y, $Z, $E, $verbose);
	}elsif($thisLine=~/^M82(\h*;\h*([\h\w_-]*)\h*)?/){
		my $verbose=$2;
		return process_absolute_extrusion($thisLine, $verbose);
	}elsif($thisLine=~/^M83(\h*;\h*([\h\w_-]*)\h*)?/){
		my $verbose=$2;
		return process_relative_extrusion($thisLine, $verbose);
	}elsif($thisLine=~/^; end of print/){
		$end=1;
	}else{
		my $verbose;
		if($thisLine=~/.*(\h*;\h*([\h\w_-]*?)\h*)?/){
			$verbose=$2;
		}
		# all the other gcodes, such as temperature changes, fan on/off, acceleration
		return process_other($thisLine, $verbose);
	}
}

sub filter_parameters
{
	# collecting parameters from G-code comments
	if($_[0] =~ /^\h*;\h*([\w_-]*)\h*=\h*(\d*\.?\d+)\h*$/){
		# all numeric variables are saved as such
		my $key=$1;
		my $value = $2*1.0;
		unless($value==0 && exists $parameters{$key}){
			$parameters{$key}=$value;
		}
		#print("; $key is numeric\n");
	}elsif($_[0] =~ /^\h*;\h*bed_shape\h*=\h*((\d*)x(\d*))\h*,\h*((\d*)x(\d*))\h*,\h*((\d*)x(\d*))\h*,\h*((\d*)x(\d*))\h*/){
		# all other variables (alphanumeric, arrays, etc) are saved as strings
		my $w=$8;
		my $h=$9;
		$parameters{"bed_width"}=$w*1.0;# if defined $w;
		$parameters{"bed_depth"}=$h*1.0;# if defined $h;
		$parameters{"bed_center_x"}=$w/2.0;# if defined $w;
		$parameters{"bed_center_y"}=$h/2.0;# if defined $h;
		#print("; bed_shape is bed\n");
	}elsif($_[0] =~ /^\h*;\h*([\h\w_-]*?)\h*=\h*(.*)\h*/){
		# all other variables (alphanumeric, arrays, etc) are saved as strings
		my $key=$1;
		my $value = $2;
		$parameters{$key}=$value;
	  #print("; $key is alphanumeric\n");
	}
}


sub print_parameters
{
	# this prints out all available parameters into the G-Code as comments
	print "; GCODE POST-PROCESSING PARAMETERS:\n\n";
	print "; OS: $^O\n\n";
	print "; Environment Variables:\n";
	foreach (sort keys %ENV) {
		print "; *$_*  =  *$ENV{$_}*\n";
	}
	print "\n";
	print "; Slic3r Script Variables:\n";
	foreach (sort keys %parameters) {
		print "; *$_*  =  *$parameters{$_}*\n";
	}
	print "\n";
}

sub process_buffer
{
	# applying all modifications to the G-Code
	foreach my $thisLine (@inputBuffer) {

		# start/end conditions
		if($thisLine=~/^; start of print/){
			$start=1;
		}elsif($thisLine=~/^; end of print/){
			$end=1;
		}

		# processing
		if($start==0){
			push(@outputBuffer,process_start_gcode($thisLine));
		}elsif($end==1){
			push(@outputBuffer,process_end_gcode($thisLine));
		}else{
			push(@outputBuffer,filter_print_gcode($thisLine));
		}
	}
}

sub print_buffer
{
	foreach my $outputLine (@outputBuffer) {
		print $outputLine;
	}
}

##########
# MAIN LOOP
##########

# Creating a backup file for windows
if($^O=~/^MSWin/){
	$^I = '.bak';
}

while (my $thisLine=<>) {
	filter_parameters($thisLine);
	push(@inputBuffer,$thisLine);
	if(eof){
		process_buffer();
		init();
		print_parameters();
		print_buffer();
	}
}
