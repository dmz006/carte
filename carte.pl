#!/usr/bin/perl
#
# David M. Zendzian dmz@dmzs.com
# 2002-07-21 - v0.9
# 2002-09-17 - v0.9rc1
#
# http://carte.dmzs.com/index.html
#
# carte.pl [-h] [-t] [-d] [-s] [-o] [-m] [-y <opacity>] [-p <destpath>] -i <infile> 
#   -i <scanfile>: input file from netstumbler text output (required)
#   -p <datapath>: where to store datafiles, default /tmp/ 
#   -y <opacity>: Set the opacity of the overlay images. Default 60 
#   -t: Do not download terraserver map (offline and already have maps)
#       otherwise: Save terraserver map as <datapath>/<mac>/terramap.png
#   -s: create simple signal 'dots' overlay image: <datapath>/<mac>/overlay-circle.png & merge with terramap for map-circle.png
#   -o: create SNR Overlay image: <datapath>/<mac>/overlay-idw.png & merge with terramap for map-idw.png
#   -m: Do not merge overlay with terramap
#   -d: debug
#   -h: this page
#
#    requires Image::Magick from ftp://ftp.wizards.dupont.com/pub/ImageMagick/
#    requires Image::Grab from http://mah.everybody.org/hacks/perl/Image-Grab/ and cpan
#
# will parse <infile> which should be a NetStumbler text export with GPS scan info of the format:
# Latitude      Longitude       ( SSID )        Type    ( BSSID )       Time (GMT)      [ SNR Sig Noise ]       # ( Name )      Flags   Channelbits     BcnIntvl
#
# This data will be pushed into WarDrive hash
# Work will be done per each MAC
# Find center Latitude/Longitude
# Grab 3x3 image map from acme.com:
#   www.acme.com/mapper/save.cgi?lat=<lat>&long=<W?-|><long>&scale=11&theme=Image&width=3&height=3&dot=No
# create overlay of all Sig found for MAC
# merge overlay with acme/terraserver image
# goto next MAC group
# -- 
#    Known Problems:
#    	If Network Name is blank or has spaces then the split will break, bad regex :/
#    	doesn't test input file for escapes in mac which would cause outputfile to be able to be written anywhere (don't run as root!)
#    	Terraserver images are a little out of date (not much I can do about this, but if you know your area it might help :/
#    	  I will get to overlaying over streetmap @ future point
#    	Acme mapper for some reason doesn't grab the image you request, but one a little offset :/
#
#    TODO:
#       provide gtk interface
#       create user defined image scale map
#       create animated view of idw-overlay creation
#       perldoc
#       inline::c optimizations
#    
# (C) 2002, DMZS, Inc -- info@dmzs.com
#
# (BSD License)
# Copyright (c) 2002, David M. Zendzian/DMZ Service, Inc.
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are
# met:
#
# Redistributions of source code must retain the above copyright
# notice, this list of conditions and the following disclaimer. 
# Redistributions in binary form must reproduce the above copyright
# notice, this list of conditions and the following disclaimer in the
# documentation and/or other materials provided with the
# distribution. 
#
# Neither the name of DMZ Services, Inc  nor the names of its
# contributors may be used to endorse or promote products derived
# from this software without specific prior written permission. 
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT
# HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS
# OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED
# TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY
# AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER
# OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
# INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
# DAMAGES (INCLUDING, BUT NOT LIMITED TO,
# PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS
# OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
# HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
# WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
# WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# p.s. If you are out to make $$ off this endevor, please consider dropping dmz@dmzs.com a note so we can participate (:
#
# Greets & thanks go out to:
# --------------------------
# Tony <tony [at] berkeleywireless [dot] net> -- for getting me into this!
# Glenn [at] netmud [dot] com for the insite needed to make lat/long/pixel conversion work and allowing me to browse some of his code (see next line)
#   Contains portions (some modified) of Copyright 2002 (see below), Netmud, LLC.  All rights reserved: (getPixelWeight_Trivial distance_cmp getPixel getLatLong)
# W. Slavin <afr [at] netstumbler [dot] com> -- for making netstumbler & all of this possible
# Jeffrey A. Poskanzer <jeff [at] acme [dot] com> -- for such an awsome wrapper for terraserver & assistance with rad to deg conversion
# Mike Kershaw <dragorn [at] nerv-un [dot] net> -- for kismit & code that helped me understand what i was doing with deg to rad conversion :)
# Peter <shipley [at] dis [dot] org> -- for the wireless insight & views into other ways of mapping wireless networks
# Change [at] dmzs [dot] com -- for letting me borrow hardware, FIRE & being a general good human being
# tvsg [dot] org people for helping get my academic spirit flowing again
# Whole crew at W-F-B for listening to these crazy ideas
# My wife for letting me work too much
#
# NetMud License (getPixelWeight_Trivial distance_cmp getPixel getLatLong)
# Copyright (c) 2002 Netmud, LLC.  All rights reserved.
# #
# # Redistribution and use in source and binary forms, with or without
# # modification, are permitted provided that the following conditions
# # are met:
# # 1. Redistributions of source code must retain the above copyright
# #    notice, this list of conditions and the following disclaimer.
# # 2. Redistributions in binary form must reproduce the above copyright
# #    notice, this list of conditions and the following disclaimer in the
# #    documentation and/or other materials provided with the distribution.
# # 3. All advertising materials mentioning features or use of this software
# #    must display the following acknowledgement:
# #	This product includes software developed by Netmud, LLC
# # 4. The name of Netmud, LLC may not be used to endorse or promote products 
# #	derived from this software without specific prior written permission.
# #
# # PORTIONS OF THIS SOFTWARE IS PROVIDED BY NETMUD ``AS IS'' AND ANY EXPRESS OR IMPLIED 
# # WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
# # MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.  IN 
# # NO EVENT SHALL NETMUD OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, 
# # INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT 
# # NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
# # DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY 
# # THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT 
# # (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF 
# # THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
#
# # Questions?  Email me at: glenn@netmud.com
#
#

use Getopt::Std;
use Image::Grab;
use Image::Magick;
use Data::Dumper;
#use Curses;

#initscr();
&getopts('dhstmoy:p:i:');
use vars qw($opt_d,$opt_h,$opt_m,$opt_s,$opt_t,$opt_o,$opt_p,$opt_i,$opt_y,$datapath,$overlay_idw,$overlay_circle,$get_terra,$debug,$logfiledata);

# need to sync this with the size that terraserver returns and make cmd line variable
my $IMAGEWIDTH=600;
my $get_terra = 1;
my $merge_map = 1;

if (!$opt_i || $opt_h) { help(); }
if (!$opt_p) { $datapath = "/tmp/"; } else { $datapath = $opt_p; mkdir "$datapath" if !stat "$datapath"; }
if (!$opt_y) { $opacity=60; } else { $opacity=$opt_y; }
if ($opt_m) { $merge_map = 0; }
if ($opt_o) { $overlay_idw = 1; }
if ($opt_s) { $overlay_circle = 1; }
if ($opt_t) { $get_terra = 0; }
if ($opt_d) { $debug = 1; }

&ScanInputLog($opt_i);

my ($filename) = $opt_i;
my (@data, $mac, $ssid, $time, $tz, $lat_1, $lat, $long_1, $long, $type, $srn, $sig, $noise, $flags, $channelbits,
    $max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong, $terraservermap, $map_circle, $map_idw, $long_width, $lat_height);
my %nodes_latlong = ( );
my %nodes = ( );
my $image_width = $IMAGEWIDTH;        # pixels
my $image_height = $image_width;      # the code assumes the image is square

banner("Processing",$filename) if $debug;

# For each mac address, process the datapoints
foreach $mac (sort keys %logfiledata) {
  banner("$mac",$filename) if $debug;
  mkdir "$datapath/$mac" if !stat "$datapath/$mac";

  ($max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong) = findmaxmin_latlong($mac);

  ($min_lat, $max_lat, $min_long, $max_long) = process_datapoints($mac, $max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong);

  $terraservermap=$datapath."/".$mac."/terramap.png";
  get_terramap($maplat,$maplong, $mac, $terraservermap) if $get_terra;

  ($map_circle) = create_overlay_circle($mac, $terraservermap, $min_long, $min_lat) if $overlay_circle;

  ($map_idw) = create_overlay_idw($mac, $terraservermap, $max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong) if $overlay_idw;
}
banner("Processing Done",$filename) if $debug;
#endwin();
  

#end of program logic
# -------------------------------------------------------------------------------------------
# Subroutines

# Print Help
sub help {
  print("usage: ./carte.pl <options> -i <scanfile>\n");
  print("Available Options\n");
  print("\t-i <scanfile>: input file from netstumbler text output (required) \n");
  print("\t-p <datapath>: where to store datafiles, default /tmp/ \n");
  print("\t-y <opacity>: Set the opacity of the overlay images. Default 60 \n");
  print("\t-t: Do not download terraserver map (offline and already have maps)\n");
  print("\t    otherwise: Save terraserver map as <datapath>/<mac>/terramap.png\n");
  print("\t-s: create simple signal 'dots' overlay image: <datapath>/<mac>/overlay-circle.png & merge with terramap for map-circle.png\n");
  print("\t-o: create SNR Overlay image: <datapath>/<mac>/overlay-idw.png & merge with terramap for map-idw.png\n");
  print("\t-m: Do not merge overlay with terramap\n");
  print("\t-d: debug\n");
  print("\t-h: this page\n");
  exit(0);
}

# Print banner
sub banner {
  my($banner_type, $banner_info) = @_;
  #clear();
  #refresh();
  print("\n#####################################################################\n");
  print("#######       $banner_type | $banner_info \n");
  print("#####################################################################\n\n");
}

sub ScanInputLog {
  my ($filename) = @_;
  my ($data, $counter, $lat_1,$lat,$long_1,$long,$ssid,$type,$mac,$time,$srn,$sig,$noise,$flags,$channelbits);

  banner("Parsing",$filename) if $debug;
  open(INPUTLOG, $filename) or die "Unable to open $filename $!\n";

  while (<INPUTLOG>) {
    # skip any lines that start with #
    next if /^#/;
    # use an array slice to select fields we want
    # note: this needs to be cleaned up & done better. If you have a ( ) with nothing for SSID or somewhere it expects info, it will cause all kinds of wierdness
    ($lat_1, $lat, $long_1, $long, $ssid, $type, $mac, $time, $tz, $srn, $sig, $noise, $name, $flags, $channelbits, $bcnintvl) = split(/[\s\ \[\]\(\)\#]+/); 
    
    # skip any lines with lat and long of 0
    next if (($lat==0) && ($long==0));

    # change : to - for mac address
    $mac =~ s/:/-/g;
    
    ##print("$lat_1, $lat, $long_1, $long, $ssid, $type, $mac, $time, $tz, $srn, $sig, $noise, $name, $flags, $channelbits\n") if $debug;

    # push value into hash $logfiledata{mac}=({ssid, time, $tz, lat_1, lat, long_1, long, type, srn, sig, noise, flags, channelbits}, ...)
    $data = {SSID=>$ssid, TIME=>$time, TZ=>$tz, LAT1=>$lat_1, LAT=>$lat, LONG1=>$long_1, LONG=>$long, TYPE=>$type, SRN=>$srn, SIG=>$sig, NOISE=>$noise, FLAGS=>$flags, CHANNELBITS=>$channelbits};

    push (@{$logfiledata{"$mac"}},$data);
    
    ##banner("Dumping Logfiledata",$mac) if $debug;
    ##print Dumper @{$logfiledata{"$mac"}};
    ##banner("Done Dumping Logfiledata",$mac) if $debug;
  }
  close (INPUTLOG);
  banner("Parsing Complete",$filename) if $debug;
}

sub findmaxmin_latlong {
  my ($mac) = @_;
  my ($key, $data, $lat_1, $lat, $long_1, $long,
         $max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong);

  banner("Finding Max & Min",$mac) if $debug;

  my $min_lat = 360;      # Assume the extremes
  my $min_long = 360;
  my $max_lat = -360;
  my $max_long = -360;

  $numcoords = 0;

  #
  # find max/min lat & long to get center of map needed
  print ("coord#\t| lat_1\t| lat\t\t| long_1| long\n") if $debug;

  foreach $data (@{$logfiledata{"$mac"}}) {
    $lat_1 = $data->{LAT1};
    $lat = $data->{LAT};
    $long_1 = $data->{LONG1};
    $long = $data->{LONG};

    $numcoords++;

    # Determine if lat/long is max/min. 
    $lat *= -1 if $lat_1 eq "S";
    $long *= -1 if $long_1 eq "W";
    $min_lat = $lat if ($lat < $min_lat);
    $min_long = $long if ($long < $min_long);
    $max_lat = $lat if ($lat > $min_lat);
    $max_long = $long if ($long > $max_long);
    print ("$numcoords\t| $lat_1\t| $lat\t| $long_1\t| $long\n") if $debug;
  }

  # find center of coordinates 
  $maplat = $max_lat - (($max_lat - $min_lat) / 2);
  $maplong = $max_long - (($max_long - $min_long) / 2);

  print ("\nmaplat=$maplat\t| maplong=$maplong\t| max_lat=$max_lat\t| min_lat=$min_lat\t| max_long=$max_long\t| min_long=$min_long\n") if $debug;
  print ("data range: $min_lat,$min_long-$max_lat,$max_long\n") if $debug;
  banner("Finding Max & Min complete",$mac) if $debug;
  return($max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong);
}

sub get_terramap {
    my ($maplat,$maplong,$mac,$terraservermap) = @_;
    my ($url, $pic);

    # get map from acme and save under $datapath/$mac-terramap.png
    banner("Getting acme/terraserver map for ",$mac) if $debug;
    $url = "http://www.acme.com/mapper/save.cgi?lat=".$maplat."&long=".$maplong."&scale=10&theme=Image&width=3&height=3&dot=No";
    print ("URL\t| $url\n\n") if $debug;
    $pic = new Image::Grab;
    $pic->regexp('.*save_image\.cgi.*');
    $pic->search_url($url);
    $pic->grab;
    
    # Now to save the image to disk
    # should just convert blob over to imagemagic image and pass back...
    # probably don't need to convert to png, but for alpha channel...
    open(IMAGE, ">terramap.jpg"); # || die "terramap.jpg: $!";
    binmode IMAGE; 
    print IMAGE $pic->image;
    close IMAGE;
    $terramap = new Image::Magick;
    $terramap->Read("terramap.jpg");
    $terramap->Write($terraservermap);
    unlink("terramap.jpg");
    print("Filename\t| $terraservermap\n") if $debug;
    banner("Done Getting acme/terraserver map for ",$mac) if $debug;
}
    
# Convert lat/long to nearest pixel x/y
sub getPixel
{
  my ($lat, $long, $min_long, $min_lat, $long_width, $lat_height, $image_width, $image_height) = @_;
  my $x = ($long - $min_long) * ($image_width / $long_width);
  my $y = $image_height - ($lat - $min_lat) * ($image_height / $lat_height);
  return (int($x), int($y));
}

sub process_datapoints {
  my ($mac, $max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong) = @_;
  my (@data, $ssid, $time, $tz, $lat_1, $lat, $long_1, $long, $type, $srn, $sig, $noise, $flags, $channelbits);

  banner("Processing datapoints, creating data hashes for overlays",$mac);
  # Plot imagepoints
  $numcoords=0;

  # Save the highest signal recorded at this lat/long, if there
  # are multiple:
  foreach $data (@{$logfiledata{"$mac"}}) {
    $lat_1 = $data->{LAT1};
    $lat = $data->{LAT};
    $long_1 = $data->{LONG1};
    $long = $data->{LONG};
    $srn = $data->{SRN};
    $numcoords++;
    $lat *= -1 if $lat_1 eq "S";
    $long *= -1 if $long_1 eq "W";
    my $latlong = $lat . "," . $long;
   
    if ( (! $nodes_latlong{$latlong}) || ($nodes_latlong{$latlong} < $srn) ) {
      $nodes_latlong{$latlong} = $srn;
    }
    print ("$numcoords\t| $lat_1\t| $lat\t| $long_1\t| $long\n") if $debug;
  }
 
  $long_width = ($max_long - $min_long) * 3.0;
  $lat_height = ($max_lat - $min_lat) * 3.0;

  print ("\nmin=$min_lat\t| min_long=$min_long\t| | max_lat=$max_lat\t| max_long=$max_long\n") if $debug;
  print ("data range: $min_lat,$min_long-$max_lat,$max_long\n") if $debug;
  print ("original width * 3=$long_width, height * 3=$lat_height\n") if $debug;

  # Adjust the lat/long range to be square (max of width & height):
  if ($long_width > $lat_height) {
    $lat_height = $long_width;
  } else {
    $long_width = $lat_height;
  }
  print ("adjusted width=$long_width, height=$lat_height\n") if $debug;

  # Adjust the data range to cover twice the area:
  my $middle_lat = ($min_lat + $max_lat) / 2.0;
  my $middle_long = ($min_long + $max_long) / 2.0;
  print ("middle_lat=$middle_lat, middle_long=$middle_long\n") if $debug;
  $min_lat = $middle_lat - ($lat_height / 2.0);
  $min_long = $middle_long - ($long_width / 2.0);
  $max_lat = $min_lat + $lat_height;
  $max_long = $min_long + $long_width;
  my $degrees_per_pixel = $long_width / $image_width;
  if (!$degrees_per_pixel) {
    print("Not enough data");
    return(0);
  }
  print ("one pixel is ", $degrees_per_pixel, " degrees of longitude.\n") if $debug;

  # Convert the 'nodes_latlong' hash from lat/long to x/y:
  foreach my $key (keys(%nodes_latlong)) {
    my ($lat, $long) = split(',', $key);
    my ($x, $y) = getPixel($lat, $long, $min_long, $min_lat, $long_width, $lat_height, $image_width, $image_height);
    my $xy = $x . "," . $y;
    $nodes{$key} = $nodes_latlong{$key};    # just copy the data
    print ("xy=$xy\t| $nodes{$key}\n") if $debug;
  }
  banner("Done processing datapoints for overlays",$mac);
  return($min_lat,$max_lat,$min_long,$max_long);
}

sub create_overlay_circle {
  my ($mac, $terraservermap, $min_long, $min_lat) = @_;

  # Plot scan into image and save as $mac/overlay.png
  banner("Creating Simple-Circle Overlay Image",$mac) if $debug;

  # Create overlay image and have background be uniform grey with opacity channel set
  my $plotcircle = Image::Magick->new(size=>"${image_width}x${image_height}");
  my $g = 255 - $opacity/100 * 255;
  my $bgcolor = sprintf "#%02x%02x%02x%02x", $g,$g,$g,$g;
  $plotcircle->Read("xc:$bgcolor");

  # Plot Each signal onto overlay image
  foreach my $key (keys(%nodes_latlong)) {
    my ($lat, $long) = split(',', $key);
    my ($x, $y) = getPixel($lat, $long, $min_long, $min_lat, $long_width, $lat_height, $image_width, $image_height);
    my $right = 5 + $x;
    my $weight = $nodes_latlong{$key};
    my $color = 'red';
    if ($weight > 25) {
      $color = 'green';
      $right += 20;
    } elsif ($weight > 18) {
      $color = 'green';
      $right += 20;
    } elsif ($weight > 12) {
      $color = 'yellow';
      $right += 12;
    } elsif ($weight > 4) {
      $color = 'red';
      $right += 5;
    } elsif ($weight > 1) {
      $color = 'black';
      $right += 2;
    } else {
    }
    $plotcircle->Draw( primitive=>'circle', fill=>$color, stroke=>$color, strokewidth=>1, points => "$x,$y $right,$y");
    print ("Draw( fill=>$color, stroke=>$color, strokewidth=>1, primitive => 'circle', points => $x,$y $right,$y weight=$weight\n") if $debug;
  }
 
  # Create transparancy mask and add to overlay
  my $mask = Image::Magick->new(size=>"${image_width}x${image_height}");
  my $g = 255 - $opacity/100 * 255;
  my $color = sprintf "#%02x%02x%02x", $g,$g,$g;
  $mask->Read("xc:$color");
  my $cur_mask = $plotcircle->Clone();
  $cur_mask->Channel('Matte');
  $rc = $mask->Composite(image => $cur_mask, compose => 'Plus');
  warn $rc if $rc;
  $rc = $plotcircle->Composite(image => $mask, compose => 'ReplaceMatte');
  warn $rc if $rc;

  # Write out the created overlay
  my $plotimage = $datapath."/".$mac."/overlay-circle.png";
  $plotcircle->Write($plotimage);
  print("\nFilename\t| $plotimage") if $debug;

  # Merge overlay with terramapfile
  if ($merge_map) {
    my $map_circle = Image::Magick->new();
    $map_circle->Read($terraservermap);
    $rc = $map_circle->Composite(image => $plotcircle, compose => 'Over');
    warn $rc if $rc;

    # Write out the terramap with simple circles overlayed
    my $mapimage = $datapath."/".$mac."/map-circle.png";
    $map_circle->Write($mapimage);
    print("\nFilename\t| $mapimage") if $debug;
  }
  banner("Done Creating Simple Image",$mac) if $debug;
  return($map_circle);
}

# Convert pixel x/y to lat/long
# # The way this works now returns the lat/long of the "top left" of the pixel.
# # XXX Maybe it should return the lat/long at the center instead.
sub getLatLong
{
  my ($x, $y, $max_lat, $min_long, $lat_height, $long_width, $image_height, $image_width) = @_;
  my $lat = $max_lat - ($y * $lat_height / $image_height);
  my $long = $min_long + ($x * $long_width / $image_width);
  ##print ("x=$x, y=$y, max_lat=$max_lat, min_long=$min_long, lat_height=$lat_height, long_width=$long_width, image_height=$image_height, image_width=$image_width, lat=$lat, long=$long\n");
  return ($lat, $long);
}

my $sort_lat = 0;
my $sort_long = 0;
sub distance_cmp
{
  my ($lat1, $long1) = split(',', $a);
  my ($lat2, $long2) = split(',', $b);
  my $dist1 = (($lat1 - $sort_lat)**2) + (($long1 - $sort_long)**2);
  my $dist2 = (($lat2 - $sort_lat)**2) + (($long2 - $sort_long)**2);
  return $dist1 <=> $dist2;
}

# Inline::C ??
# 2002/07/28 - Removed all code that was mentioned as not needed - DMZ
sub getPixelWeight_Trivial
{
  my ($x, $y, $max_lat, $min_long, $lat_height, $long_width, $image_height, $image_width, %nodes) = @_;
  my ($pix_lat, $pix_long) = getLatLong($x, $y, $max_lat, $min_long, $lat_height, $long_width, $image_height, $image_width);
  my $weight = 0;         # What we're returning
  my $weightcap = 0;      # The highest weight actually seen.  We never return a value greater than this (because signal isn't cumulative).
  my @nodekeys = keys(%nodes);

  ##print ("x=$x, y=$y, max_lat=$max_lat, min_long=$min_long, latheight=$lat_height, longwidth=$long_width, imageheight=$image_height, imagewidth=$image_width\n");
  ##print ("x=$x, y=$y, pix_lat=$pix_lat, pix_long=$pix_long\n");

  # Sort the node keys by distance to this point:
  $sort_lat = $pix_lat;
  $sort_long = $pix_long;
  my @sortedkeys = sort distance_cmp @nodekeys;
  # Only use the N closest nodes: 
  # XXX This may break for data sets with less than 6 points:
  foreach my $i (0..6) {
    my $key = $sortedkeys[$i];
    my ($i_lat, $i_long) = split(',', $key);
    my $dist_i = ((($i_lat - $pix_lat)**2) + (($i_long - $pix_long)**2));
    ##print ("ilat=$i_lat\t| plat=$pix_lat\t| ilong=$i_long\t| plong=$pix_long\t| dist=$dist_i\n") if $debug;

    # Where did 0.000000025197117696 come from?  Great question!
    # Let me know if you figure it out!  I just screwed around
    # until I was happy with the output I was getting.
    # Maybe it's some kind of mapping between pixels & lat/long
    # (and should really relate to $degrees_per_pixel)
    $dist_i = (0.000000025197117696) / ($dist_i) unless ($dist_i eq 0);
    my $tempweight = $dist_i * $nodes{$key};
    $weightcap = $nodes{$key} if ($nodes{$key} > $weightcap);
    ##print ("dist=$dist_i\t| tempweight=$tempweight\t| weight=$nodes{$key}\t| W=$weight\n") if $debug;
    if ($tempweight > 0.000001) {
      # If the weight is close enough to 0, don't bother counting this data point.  (hack)
      $weight += $tempweight;
    }
  }
  $weight = $weightcap if ($weight > $weightcap); # Cap at weightcap
  #print ("Weight\t| $weight\n") if $debug;
  return ($weight);
}

sub create_overlay_idw {
  my ($mac, $terraservermap, $max_lat, $min_lat, $max_long, $min_long, $maplat, $maplong) = @_;
  my (@data, $ssid, $time, $tz, $lat_1, $lat, $long_1, $long, $type, $srn, $sig, $noise, $flags, $channelbits);
  my @weights = ();       		# One per pixel
  my $minweight = 999999999;
  my $maxweight = 0;
  my $weightsum = 0;
    
  # Loop through all the pixels in the output and calculate the weight for each:
  foreach my $x_pix (0..$image_width) {
    foreach my $y_pix (0..$image_height) {
      $weights[$x_pix][$y_pix] = getPixelWeight_Trivial($x_pix, $y_pix, $max_lat, $min_long, $lat_height, $long_width, $image_height, $image_width, %nodes); 
      $minweight = $weights[$x_pix][$y_pix] if ($weights[$x_pix][$y_pix] < $minweight);
      print ("for $x_pix, $y_pix, weight=$weights[$x_pix][$y_pix], minweight=$minweight\n") if (($x_pix eq $y_pix) && $debug);
      #print ("for $x_pix, $y_pix, weight=$weights[$x_pix][$y_pix], minweight=$minweight\n") if $debug;
    }
  }
  
  # Create overlay image and have background be uniform grey with opacity channel set
  my $plotidw = Image::Magick->new(size=>"${image_width}x${image_height}");
  my $g = 255 - $opacity/100 * 255;
  my $bgcolor = sprintf "#%02x%02x%02x%02x", $g,$g,$g,$g;
  $plotidw->Read("xc:$bgcolor");

  print ("Generating overlay image:\n") if $debug;
  # The colors used here are just what I liked.  Tweak 'em, make 'em configurable, whatever:
  foreach my $x_pix (0..$image_width) {
    foreach my $y_pix (0..$image_height) {
      my $weight = $weights[$x_pix][$y_pix];
      my $red = $g;
      my $green = $g;
      my $blue = $g;
      if ($weight > 25) {
        $red = 100; #int(128 * $weight);
        $green = 133;
        $blue = 142;
      } elsif ($weight > 18) {
        $red = 122;
        $green = 165; #int(128 * ($weight + 0.4));
        $blue = 128;
      } elsif ($weight > 12) {
        $red = 168;
        $green = 181; #int(128 * ($weight + 0.4));
        $blue = 112;
      } elsif ($weight > 4) {
        $red = 183;
        $green = 162;
        $blue = 71;
      } elsif ($weight > 1) {
        $red = 172;
        $green = 152;
        $blue = 119;
      } else {
        $red = $green = $blue = $g;
      }
      my $colorstring = sprintf("#%02x%02x%02x%02x", $red, $green, $blue, $g);
      if (length($colorstring) > 9) {
        print ("red=$red, green=$green, blue=$blue, weight=$weight\n") if $debug;
      }
      $plotidw->Set("Pixel[$x_pix,$y_pix]"=>$colorstring);
      print ("x=$x_pix,y=$y_pix\t| colorstring = $colorstring\n") if ($debug && ($x_pix eq $y_pix));
    }
  }

  # Create transparancy mask and add to overlay
  my $mask = Image::Magick->new(size=>"${image_width}x${image_height}");
  my $g = 255 - $opacity/100 * 255;
  my $color = sprintf "#%02x%02x%02x", $g,$g,$g;
  $mask->Read("xc:$color");
  my $cur_mask = $plotidw->Clone();
  $cur_mask->Channel('Matte');
  $rc = $mask->Composite(image => $cur_mask, compose => 'Plus');
  warn $rc if $rc;
  $rc = $plotidw->Composite(image => $mask, compose => 'ReplaceMatte');
  warn $rc if $rc;

  # Write out the created overlay
  my $plotimage = $datapath."/".$mac."/overlay-idw.png";
  $plotidw->Write($plotimage);
  print("\nFilename\t| $plotimage") if $debug;

  # Merge overlay with terramapfile
  if ($merge_map) {
    my $map_idw = Image::Magick->new();
    $map_idw->Read($terraservermap);
    $rc = $map_idw->Composite(image => $plotidw, compose => 'Over');
    warn $rc if $rc;
    my $mapimage = $datapath."/".$mac."/map-idw.png";
    $map_idw->Write($mapimage);

    # Write out the terramap with idw overlayed
    print("\nFilename\t| $mapimage") if $debug;
  }

  banner("Done Creating Overlay Image",$mac) if $debug;
  return($map_idw) if $merge_map;
}

