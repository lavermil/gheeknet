#!/usr/bin/perl
#Author: Lance Vermilion
#Purpose: Parse the output from a collection of SNMP info from the Meraki Cloud Controller

# Sample of Expected Data Returned
#MERAKI-CLOUD-CONTROLLER-MIB::devName.0.24.10.67.130.145 = STRING: Home-FW
#MERAKI-CLOUD-CONTROLLER-MIB::devNetworkName.0.24.10.67.130.145 = STRING: Test-Meraki - appliance
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceIndex.0.24.10.67.130.145.0 = INTEGER: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceIndex.0.24.10.67.130.145.1 = INTEGER: 1
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceIndex.0.24.10.67.130.145.2 = INTEGER: 2
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceIndex.0.24.10.67.130.145.3 = INTEGER: 3
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceIndex.0.24.10.67.130.145.4 = INTEGER: 4
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceName.0.24.10.67.130.145.0 = STRING: wan1
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceName.0.24.10.67.130.145.1 = STRING: lan1
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceName.0.24.10.67.130.145.2 = STRING: lan2
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceName.0.24.10.67.130.145.3 = STRING: lan3
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceName.0.24.10.67.130.145.4 = STRING: lan4
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentPkts.0.24.10.67.130.145.0 = Counter32: 44391002
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentPkts.0.24.10.67.130.145.1 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentPkts.0.24.10.67.130.145.2 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentPkts.0.24.10.67.130.145.3 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentPkts.0.24.10.67.130.145.4 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvPkts.0.24.10.67.130.145.0 = Counter32: 29458512
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvPkts.0.24.10.67.130.145.1 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvPkts.0.24.10.67.130.145.2 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvPkts.0.24.10.67.130.145.3 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvPkts.0.24.10.67.130.145.4 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentBytes.0.24.10.67.130.145.0 = Counter32: 1159648430
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentBytes.0.24.10.67.130.145.1 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentBytes.0.24.10.67.130.145.2 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentBytes.0.24.10.67.130.145.3 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceSentBytes.0.24.10.67.130.145.4 = Counter32: 742385204
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvBytes.0.24.10.67.130.145.0 = Counter32: 2021640796
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvBytes.0.24.10.67.130.145.1 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvBytes.0.24.10.67.130.145.2 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvBytes.0.24.10.67.130.145.3 = Counter32: 0
#MERAKI-CLOUD-CONTROLLER-MIB::devInterfaceRecvBytes.0.24.10.67.130.145.4 = Counter32: 1354890845

use strict;
use File::Path qw(make_path);
use Data::Dumper;
use Storable qw(store retrieve freeze thaw dclone);

my $debug = 1; # 0 = False, 1 = True 
my $usedumper = 0; # 0 = False, 1 = True 
my $tree = 0; # 0 = False, 1 = True 
my $outputfound = 0; # 0 = False, 1 = True 
my $comm_v2c = $ARGV[0];
my $comm2file_dir = '/tmp/meraki';
my $storable_dir = "$comm2file_dir/storable";
my $storable_file = 0;
my $cnt = 0;
my $comm2file = "$comm2file_dir/comm2file.db";

if ( ! $ARGV[0] )
{
  print "\n";
  print "#" x 52 . "\n";
  print "# ERROR: No SNMPv2c Community String was provided! #\n";
  print "#" x 52 . "\n";
  print "\n";
  print "Syntax: $0 <SNMP Read-Only Community String>\n\n";
  exit 1;
}

# Function to create directories (similar to mkdir -p)
sub SUB_mkdir
{
  my $check_dir = shift;
  # Make sure the directory exists and create it if it doesn't exist
  if ( ! -d $check_dir )
  {
    make_path $check_dir, { mode => 0755, error => \my $err };
    if ( @$err)
    {
      for my $diag (@$err) 
      {
        my ($file, $message) = %$diag;
        if ($file eq '') 
        {
            print "general error: $message\n";
        }
        else 
        {
            print "specific error: $file: $message\n";
        }
      }
      return @$err;
    }
  }
}

# Check if the following directories are created, if they are not then create them.
SUB_mkdir($comm2file_dir);
SUB_mkdir($storable_dir);

# If the comm2file does not exist then create it, even if it is empty we can then populate it later
open my $comm2file_fh, ">>$comm2file" or die "Can't open file: $comm2file : $!\n" if ( ! -f $comm2file );

# Check the comm2file_fh for the community string to determine the filename holding the last polled data
open my $comm2file_fh, "$comm2file" or die "Can't open file: $comm2file : $!\n";
while (<$comm2file_fh>)
{
  if ( /$comm_v2c/ )
  {
    (undef, $storable_file)  = split(/ = /, $_);
    chomp($storable_file);
  }
  $cnt++;
}
close $comm2file_fh;

# Write to comm2file_fh with the reference to the new filename
if ( ! -f $storable_file )
{
  my $new_storable_file = "$storable_dir/$cnt" . "_storable.db";
  open my $comm2file_fh, ">>$comm2file" or die "Can't open file: $comm2file : $!\n";
    print $comm2file_fh "$comm_v2c = $new_storable_file\n";
  close $comm2file_fh;
  $storable_file = $new_storable_file;
}

print "Performing snmpwalk of \"snmp.meraki.com:16100\" using SNMPv2c community string of \"$comm_v2c\"\n" if ( $debug );
open(SNMPWALK, "snmpwalk -v2c -c $comm_v2c -Ob -M +. -m +MERAKI-CLOUD-CONTROLLER-MIB snmp.meraki.com:16100 .1 |") or die "Failed to run snmpwalk! :: $!\n";

# Hash Reference of Current Values polled (slurped from storage file).
my $href_curr = {};

# Hash Reference of Previous Values polled (slurped from storage file).
my $href_prev = {};

# Hash Reference of differences between the Current Values and Previous Values polled (slurped from storage file).
my $href_diff = {};


# Store all values in a file because we have to know three things.
# 1. Previous values polled
# 2. Current values polled
# 3. Difference between current values polled and prevvious values polled
#   a. if current valued polled are larger than the previous values polled then subtract
#   b. if current valued polled are smaller than the previous values polled then use the current values because the counter has rolled
#     - Cavaet is we don't know what the numeric value is when the counter rolls over for everything. If it is a 32bit integer we know that
#       or if it is a 64 bit integer we know that. Since the Meraki controller MIB does not provide access to the device uptime we have to
#       assume the device has rebooted and start counting over. At a later date we can consider polling the device for its uptime 
#       (which currently is stored in date format and not timestamp/timeticks).

$href_prev = retrieve($storable_file) or die "Can't open '$storable_file' :$!\n" if ( -f $storable_file );


# Used to test against static set of data in a file. Content in the file should come from the 
# output of the open(SNMPWALK... line above. If you uncomment the lines below comment the 
# op(SNMPWALK... lines.
#my @arr = `cat /tmp/meraki_snmp.log`;
#for my $line (@arr)

for my $line (<SNMPWALK>)
{
  chomp($line);
  my $InterfaceIndex = '';
  if ( $line =~ /devName/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devName\.//g;
    my ($oid_piece, $devName) = split(/ = STRING: /, $tmpname);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devName'} = $devName;
  }
  elsif ( $line =~ /devNetworkName/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devNetworkName\.//g;
    my ($oid_piece, $devNetworkName) = split(/ = STRING: /, $tmpname);
    my ($NetworkName,undef) = split(/ - /, $devNetworkName);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devNetworkName'}->{$devNetworkName} = $devNetworkName;
    $href_curr->{$comm_v2c}->{$oid_piece}->{'NetworkName'} = $NetworkName;
  }
  elsif ( $line =~ /devInterfaceIndex/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceIndex\.//g;
    my ($oid_piece, $devInterfaceIndex) = split(/ = INTEGER: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.?)/);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndexes'}}, $devInterfaceIndex);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceName'} = '';
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceSentPkts'} = '';
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceRecvPkts'} = '';
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceSentBytes'} = '';
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceRecvBytes'} = '';
  }
  elsif ( $line =~ /devInterfaceName/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceName\.//g;
    my ($oid_piece, $devInterfaceName) = split(/ = STRING: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.?)/);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceName'} = $devInterfaceName;
  }
  elsif ( $line =~ /devInterfaceSentPkts/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceSentPkts\.//g;
    my ($oid_piece, $devInterfaceSentPkts) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.?)/);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceSentPkts'} = $devInterfaceSentPkts;
  }
  elsif ( $line =~ /devInterfaceRecvPkts/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceRecvPkts\.//g;
    my ($oid_piece, $devInterfaceRecvPkts) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.?)/);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceRecvPkts'} = $devInterfaceRecvPkts;
  }
  elsif ( $line =~ /devInterfaceSentBytes/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceSentBytes\.//g;
    my ($oid_piece, $devInterfaceSentBytes) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.?)/);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceSentBytes'} = $devInterfaceSentBytes;
  }
  elsif ( $line =~ /devInterfaceRecvBytes/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceRecvBytes\.//g;
    my ($oid_piece, $devInterfaceRecvBytes) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.?)/);
    push(@{$href_curr->{$comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceRecvBytes'} = $devInterfaceRecvBytes;
  }
}

if ( $usedumper )
{
  print Dumper($href_curr);
}

# Copy href_curr to href_diff
$href_diff = $href_curr;

print "\n";
print "#" x 10 . "\n";
print "# Output #\n";
print "#" x 10 . "\n";
for my $oid ( sort keys %{$href_curr->{$comm_v2c}} )
{
  my $hostname = $href_curr->{$comm_v2c}->{$oid}->{'devName'};
  my $network = $href_curr->{$comm_v2c}->{$oid}->{'NetworkName'};
  if ( $href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndex'} )
  {
    $outputfound = 1;
    print "$network\n  - $hostname\n" if ( $tree );
    for my $ii (@{$href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndexes'}})
    {
      my $InterfaceName = $href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceName'};
      my $CURR_InterfaceSentPkts = $href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'};
      my $CURR_InterfaceRecvPkts = $href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'};
      my $CURR_InterfaceSentBytes = $href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'};
      my $CURR_InterfaceRecvBytes = $href_curr->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'};

      # Default DIFF to CURR
      my $DIFF_InterfaceSentPkts = $CURR_InterfaceSentPkts;
      my $DIFF_InterfaceRecvPkts = $CURR_InterfaceRecvPkts;
      my $DIFF_InterfaceSentBytes = $CURR_InterfaceSentBytes;
      my $DIFF_InterfaceRecvBytes = $CURR_InterfaceRecvBytes;

      # Check if there is a previous hash value and if so update DIFF_ with the difference between the CURR and PREV
      if ( $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'} )
      {
        my $PREV_InterfaceSentPkts = $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'};
        $DIFF_InterfaceSentPkts -= $CURR_InterfaceSentPkts if ( $CURR_InterfaceSentPkts >= $PREV_InterfaceSentPkts );
        $href_diff->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'} = $DIFF_InterfaceSentPkts; 
      }
      if ( $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'} )
      {
        my $PREV_InterfaceRecvPkts = $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'};
        $DIFF_InterfaceRecvPkts -= $CURR_InterfaceRecvPkts if ( $CURR_InterfaceRecvPkts >= $PREV_InterfaceRecvPkts );
        $href_diff->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'} = $DIFF_InterfaceRecvPkts; 
      }
      if ( $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'} )
      {
        my $PREV_InterfaceSentBytes = $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'};
        $DIFF_InterfaceSentBytes -= $CURR_InterfaceSentBytes if ( $CURR_InterfaceSentBytes >= $PREV_InterfaceSentBytes );
        $href_diff->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'} = $DIFF_InterfaceSentBytes; 
      }
      if ( $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'} )
      {
        my $PREV_InterfaceRecvBytes = $href_prev->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'};
        $DIFF_InterfaceRecvBytes -= $CURR_InterfaceRecvBytes if ( $CURR_InterfaceRecvBytes >= $PREV_InterfaceRecvBytes );
        $href_diff->{$comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'} = $DIFF_InterfaceRecvBytes; 
      }


      if ( ! $tree ) 
      {
        print "$network,$hostname,$InterfaceName,$DIFF_InterfaceSentPkts,$DIFF_InterfaceRecvPkts,$DIFF_InterfaceSentBytes,$DIFF_InterfaceRecvBytes\n";
      }
      else
      {
        print "    - $InterfaceName\n      - $DIFF_InterfaceSentPkts\n      - $DIFF_InterfaceRecvPkts\n      - $DIFF_InterfaceSentBytes\n      - $DIFF_InterfaceRecvBytes\n";
      }
    }
  }
  else
  {
  }
}
print "No Output!\n" if ( ! $outputfound );
print "\n";

# Save for reference on next poll
store($href_curr, $storable_file) or die "Can't open '$storable_file' :$!\n";
