#!/usr/local/bin/perl
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
use warnings;
use File::Path qw(make_path);
use Fcntl qw(:flock SEEK_END);
use Data::Dumper;
use Storable qw(store retrieve freeze thaw dclone);

my $config = '/tmp/meraki_snmp.conf';

# Get our configuration information
if (my $err = SUB_ReadCfg($config)) {
    print(STDERR $err, "\n");
    exit(1);
}

my $debug            = $CFG::meraki{'options'}{'debug'};
my $usedumper        = $CFG::meraki{'options'}{'usedumper'};
my $tree             = $CFG::meraki{'options'}{'tree'};
my $mib_dir          = $CFG::meraki{'setup'}{'mib_dir'};
my $org              = '';
for my $k ( keys %{$CFG::meraki{'organization'}} ) { $org = $k };
my @networks         = keys %{$CFG::meraki{'organization'}{$org}{'network'}};
my @hostnames        = ();
for my $network (@networks) { for my $host ( keys %{$CFG::meraki{'organization'}{$org}{'network'}{$network}} ) { push(@hostnames, $host) if ( $host !~ /^network_snmp/ && $CFG::meraki{'organization'}{$org}{'network'}{$network}{$host} ) } };
my $hostname         = '';
$hostname         = join('|', @hostnames);
my $org_comm_v2c     = '';
$org_comm_v2c     = $CFG::meraki{'organization'}{$org}{'org_snmp_comm_v2c'} if ( $CFG::meraki{'organization'}{$org}{'org_snmp_enabled'} );
my @network_snmp_comm_v2c = ();
for my $network (@networks) { push(@network_snmp_comm_v2c, "$network,$CFG::meraki{'organization'}{$org}{'network'}{$network}{'network_snmp_comm_v2c'}") if ( $CFG::meraki{'organization'}{$org}{'network'}{$network}{'network_snmp_enabled'} ) };
my $network_comm_v2c = join(',', @network_snmp_comm_v2c);
my $base_dir         = $CFG::meraki{'setup'}{'base_dir'};
my $storable_dir     = "$base_dir/$CFG::meraki{'setup'}{'storable_dir'}";
my $comm2file        = "$base_dir/$CFG::meraki{'setup'}{'comm2file'}";
my $logging          = $CFG::meraki{'setup'}{'log'}{'logging'};
my $logging_dir      = "$base_dir/$CFG::meraki{'setup'}{'log'}{'logging_dir'}";
my $logging_file     = "$logging_dir/$CFG::meraki{'setup'}{'log'}{'logging_file'}";

# Do not change these variables
my $cnt = 0; 
my $outputfound = 0; # 0 = False, 1 = True 
my $storable_file = 0;

# Hash Reference of Current Values polled (slurped from storage file).
my $href_curr = {};
# Hash Reference of Previous Values polled (slurped from storage file).
my $href_prev = {};
# Hash Reference of differences between the Current Values and Previous Values polled (slurped from storage file).
my $href_diff = {};



# Function to append to a log file and acquire a lock on the file
# This should be replaced with Log4perl when Log4perl becomes available on the systems
sub SUB_appendLogs {
    my $timedate = localtime;  
    my $log_msg = shift;
    my $FATAL_VARS_MISSING = 0;
    if ( $log_msg =~ /FATAL_VARS_MISSING/ )
    {
      $log_msg =~ s/FATAL_VARS_MISSING//g;
      $FATAL_VARS_MISSING = 1;
    }
    if ( $logging )
    {
      open LOG_FILE, "+>>", $logging_file or warn "WARN: Cannot open logging file \"$logging_file\". :: $!"; 
      flock (LOG_FILE, LOCK_EX) or warn "WARN: Cannot lock logging file: \"$logging_file\", failed to log $log_msg :: $!";
  
      # After lock, move cursor to end of file, not really needed since we are appending, but better safe than sorry
      seek (LOG_FILE, 0, SEEK_END) or warn "WARN: Cannot seek in logging file: \"$logging_file\". File updated before we did. :: $!";
      print LOG_FILE "$timedate $org_comm_v2c $log_msg\n" if ( ! $ARGV[2] );
      print "$timedate $org_comm_v2c $log_msg\n" if ( $debug || $log_msg =~ /FATAL/ || $FATAL_VARS_MISSING );
      flock (LOG_FILE, LOCK_UN) or warn "WARN: Cannot unlock logging file: \"$logging_file\". :: $!";
      close LOG_FILE;
    }
}

# Read a configuration file
#   The arg can be a relative or full path, or
#   it can be a file located somewhere in @INC.
sub SUB_ReadCfg
{
    my $file = $_[0];

    our $err;

    {   # Put config data into a separate namespace
        package CFG;

        # Process the contents of the config file
        my $rc = do($file);

        # Check for errors
        if ($@) {
            $::err = "ERROR: Failure compiling '$file' - $@";
        } elsif (! defined($rc)) {
            $::err = "ERROR: Failure reading '$file' - $!";
        } elsif (! $rc) {
            $::err = "ERROR: Failure processing '$file'";
        }
    }

    return ($err);
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
SUB_mkdir($base_dir);
SUB_mkdir($storable_dir);
SUB_mkdir($logging_dir);


#if ( ! $ARGV[0] || ! $ARGV[1] )
if ( ! length($hostname) || ! length($org_comm_v2c) )
{
  my $marker = "#" x 52;
  SUB_appendLogs("FATAL_VARS_MISSING$marker");
  SUB_appendLogs("FATAL_VARS_MISSING# ERROR: No Hostname was provided! #") if ( ! $hostname );
  SUB_appendLogs("FATAL_VARS_MISSING# ERROR: No SNMPv2c Community String was provided! #") if ( ! $org_comm_v2c );
  SUB_appendLogs("FATAL_VARS_MISSING$marker");
  SUB_appendLogs("FATAL_VARS_MISSING");
  SUB_appendLogs("FATAL_VARS_MISSINGProvided:");
  SUB_appendLogs("FATAL_VARS_MISSING          Hostname(s): $hostname");
  SUB_appendLogs("FATAL_VARS_MISSING          Community:   $org_comm_v2c");
  SUB_appendLogs("FATAL_VARS_MISSING");
  SUB_appendLogs("FATAL_VARS_MISSINGSyntax: $0 <HOSTNAME> <SNMP Read-Only Community String>");
  SUB_appendLogs("FATAL_VARS_MISSING");
  SUB_appendLogs("FATAL_VARS_MISSINGNote: The Hostname must match exactly to the name configured in the Meraki Dashbaord");
  exit 1;
}


# Log variables used and their values
SUB_appendLogs("Variable Values :: Debug: \"$debug\", UseDumper: \"$usedumper\", Tree: \"$tree\", Hostname(s): \"$hostname\", Org Communities: \"$org_comm_v2c\", Network-Wide Communities: \"$network_comm_v2c\", BaseDir: \"$base_dir\", StorableDir: \"$storable_dir\", Comm2File: \"$comm2file\", Logging: \"$logging\", LoggingDir: \"$logging_dir\", LoggingFile: \"$logging_file\"");

# If the comm2file does not exist then create it, even if it is empty we can then populate it later
if ( ! -f $comm2file )
{
  open my $comm2file_fh, ">>$comm2file" or die SUB_appendLogs("FATAL: Cannot create comm2file file: \"$comm2file\" :: $!");
  if ( -f $comm2file )
  {
    SUB_appendLogs("Created comm2file file: \"$comm2file\".");
  }
}

# Check the comm2file_fh for the community string to determine the filename holding the last polled data
open my $comm2file_fh, "$comm2file" or die SUB_appendLogs("FATAL: Cannot open comm2file file: \"$comm2file\" :: $!");
while (<$comm2file_fh>)
{
  if ( /^$org_comm_v2c = / )
  {
    (undef, $storable_file)  = split(/ = /, $_);
    chomp($storable_file);
    SUB_appendLogs("Community \"$org_comm_v2c\" matched in file \"$comm2file\". Using Storable file \"$storable_file\".");
  }
  $cnt++;
}
close $comm2file_fh;

SUB_appendLogs("NOTICE: Community \"$org_comm_v2c\" NOT matched in file \"$comm2file\".") if ( ! $storable_file );

# Write to comm2file_fh with the reference to the new filename
if ( ! -f $storable_file && ! $storable_file )
{
  my $new_storable_file = "$storable_dir/$cnt" . "_storable.data";
  open my $comm2file_fh, ">>$comm2file" or die SUB_appendLogs("FATAL: Cannot open comm2file file \"$comm2file\" :: $!");
    print $comm2file_fh "$org_comm_v2c = $new_storable_file\n";
  close $comm2file_fh;
  $storable_file = $new_storable_file;
  SUB_appendLogs("Assigned SNMP Community \"$org_comm_v2c\" to Storable file \"$storable_file\" in comm2file file: \"$comm2file\".");
}


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

if ( -f $storable_file )
{
  $href_prev = retrieve($storable_file) or SUB_appendLogs("WARN: Cannot open storable file: \"$storable_file\" :: $!");
  SUB_appendLogs("Retrieved previous collection of values from storable file: \"$storable_file\".");
}
else
{
  SUB_appendLogs("NOTICE: Storable file: \"$storable_file\" does not exist and NO previously collected values available.");
}

SUB_appendLogs("Performing snmpwalk of \"snmp.meraki.com:16100\" using SNMPv2c community string of \"$org_comm_v2c\"");
SUB_appendLogs("Running SNMPWALK: \"snmpwalk -v2c -c $org_comm_v2c -Ob -M $mib_dir -m +MERAKI-CLOUD-CONTROLLER-MIB snmp.meraki.com:16100 .1 |\"");
open(SNMPWALK, "snmpwalk -v2c -c $org_comm_v2c -Ob -M $mib_dir -m +MERAKI-CLOUD-CONTROLLER-MIB snmp.meraki.com:16100 .1 |") or die SUB_appendLogs("FATAL: Cannot to run snmpwalk! :: $!");

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
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devName'} = $devName;
  }
  elsif ( $line =~ /devNetworkName/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devNetworkName\.//g;
    my ($oid_piece, $devNetworkName) = split(/ = STRING: /, $tmpname);
    my ($NetworkName,undef) = split(/ - /, $devNetworkName);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devNetworkName'}->{$devNetworkName} = $devNetworkName;
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'NetworkName'} = $NetworkName;
  }
  elsif ( $line =~ /devInterfaceIndex/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceIndex\.//g;
    my ($oid_piece, $devInterfaceIndex) = split(/ = INTEGER: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.+)/);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndexes'}}, $devInterfaceIndex);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceName'} = '';
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceSentPkts'} = '';
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceRecvPkts'} = '';
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceSentBytes'} = '';
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$devInterfaceIndex}->{'devInterfaceRecvBytes'} = '';
  }
  elsif ( $line =~ /devInterfaceName/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceName\.//g;
    my ($oid_piece, $devInterfaceName) = split(/ = STRING: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.+)/);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceName'} = $devInterfaceName;
  }
  elsif ( $line =~ /devInterfaceSentPkts/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceSentPkts\.//g;
    my ($oid_piece, $devInterfaceSentPkts) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.+)/);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceSentPkts'} = $devInterfaceSentPkts;
  }
  elsif ( $line =~ /devInterfaceRecvPkts/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceRecvPkts\.//g;
    my ($oid_piece, $devInterfaceRecvPkts) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.+)/);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceRecvPkts'} = $devInterfaceRecvPkts;
  }
  elsif ( $line =~ /devInterfaceSentBytes/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceSentBytes\.//g;
    my ($oid_piece, $devInterfaceSentBytes) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.+)/);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceSentBytes'} = $devInterfaceSentBytes;
  }
  elsif ( $line =~ /devInterfaceRecvBytes/ )
  {
    my $tmpname = $line;
    $tmpname =~ s/.*devInterfaceRecvBytes\.//g;
    my ($oid_piece, $devInterfaceRecvBytes) = split(/ = Counter32: /, $tmpname);
    ($oid_piece,$InterfaceIndex) = ($oid_piece =~ /(.*)\.(.+)/);
    push(@{$href_curr->{$org_comm_v2c}->{$oid_piece}->{'original_lines'}}, $line);
    $href_curr->{$org_comm_v2c}->{$oid_piece}->{'devInterfaceIndex'}->{$InterfaceIndex}->{'devInterfaceRecvBytes'} = $devInterfaceRecvBytes;
  }
}

if ( $usedumper )
{
  print Dumper($href_curr);
}

# Copy href_curr to href_diff
$href_diff = $href_curr;

for my $oid ( sort keys %{$href_curr->{$org_comm_v2c}} )
{
  my $devName = $hostname; # Assign the devName to be the same as the hostname to account for when the device has yet to be named through the dashboard. Otherwise it is blank
  my $network = '';
  $devName = $href_curr->{$org_comm_v2c}->{$oid}->{'devName'} if ( $href_curr->{$org_comm_v2c}->{$oid}->{'devName'} );
  $network = $href_curr->{$org_comm_v2c}->{$oid}->{'NetworkName'} if ($href_curr->{$org_comm_v2c}->{$oid}->{'NetworkName'} );
  if ( $href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'} )
  {
    if ( $tree )
    {
      $outputfound = 1 if ( $tree );
      $devName =~ s/\s+/-/g; # Remove spaces and replace with dashes
      $network =~ s/\s+/-/g; # Remove spaces and replace with dashes
      # Never prints to Log if $tree
      print "$network\n  - $devName\n";
    }
    for my $ii ( sort {$a <=> $b} @{$href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndexes'}})
    {
      my $InterfaceName = $href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceName'};
      my $CURR_InterfaceSentPkts = $href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'};
      my $CURR_InterfaceRecvPkts = $href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'};
      my $CURR_InterfaceSentBytes = $href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'};
      my $CURR_InterfaceRecvBytes = $href_curr->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'};

      # Default DIFF to CURR
      my $DIFF_InterfaceSentPkts = $CURR_InterfaceSentPkts;
      my $DIFF_InterfaceRecvPkts = $CURR_InterfaceRecvPkts;
      my $DIFF_InterfaceSentBytes = $CURR_InterfaceSentBytes;
      my $DIFF_InterfaceRecvBytes = $CURR_InterfaceRecvBytes;

      # Check if there is a previous hash value and if so update DIFF_ with the difference between the CURR and PREV
      if ( $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'} )
      {
        my $PREV_InterfaceSentPkts = $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'};
        $DIFF_InterfaceSentPkts -= $PREV_InterfaceSentPkts if ( $CURR_InterfaceSentPkts >= $PREV_InterfaceSentPkts );
        $href_diff->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentPkts'} = $DIFF_InterfaceSentPkts; 
      }
      if ( $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'} )
      {
        my $PREV_InterfaceRecvPkts = $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'};
        $DIFF_InterfaceRecvPkts -= $PREV_InterfaceRecvPkts if ( $CURR_InterfaceRecvPkts >= $PREV_InterfaceRecvPkts );
        $href_diff->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvPkts'} = $DIFF_InterfaceRecvPkts; 
      }
      if ( $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'} )
      {
        my $PREV_InterfaceSentBytes = $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'};
        $DIFF_InterfaceSentBytes -= $PREV_InterfaceSentBytes if ( $CURR_InterfaceSentBytes >= $PREV_InterfaceSentBytes );
        $href_diff->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceSentBytes'} = $DIFF_InterfaceSentBytes; 
      }
      if ( $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'} )
      {
        my $PREV_InterfaceRecvBytes = $href_prev->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'};
        $DIFF_InterfaceRecvBytes -= $PREV_InterfaceRecvBytes if ( $CURR_InterfaceRecvBytes >= $PREV_InterfaceRecvBytes );
        $href_diff->{$org_comm_v2c}->{$oid}->{'devInterfaceIndex'}->{$ii}->{'devInterfaceRecvBytes'} = $DIFF_InterfaceRecvBytes; 
      }

      if ( ! $tree && $devName =~ /$hostname/ ) 
      {
        $devName =~ s/\s+/-/g;
        $network =~ s/\s+/-/g;
        $outputfound = 1;
        #print "$network,$devName,$InterfaceName,$DIFF_InterfaceSentPkts,$DIFF_InterfaceRecvPkts,$DIFF_InterfaceSentBytes,$DIFF_InterfaceRecvBytes\n";
        #print "/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_PACKETS -s $network:$devName:$InterfaceName -t SentPkts -v $DIFF_InterfaceSentPkts -i 300\n";
        SUB_appendLogs("/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_PACKETS -s $network:$devName:$InterfaceName -t SentPkts -v $DIFF_InterfaceSentPkts -i 300");
        #print "/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_PACKETS -s $network:$devName:$InterfaceName -t RecvPkts -v $DIFF_InterfaceRecvPkts -i 300\n";
        SUB_appendLogs("/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_PACKETS -s $network:$devName:$InterfaceName -t RecvPkts -v $DIFF_InterfaceRecvPkts -i 300");
        #print "/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_TRAFFIC -s $network:$devName:$InterfaceName -t SentBytes -v $DIFF_InterfaceSentBytes -i 300\n";
        SUB_appendLogs("/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_TRAFFIC -s $network:$devName:$InterfaceName -t SentBytes -v $DIFF_InterfaceSentBytes -i 300");
        #print "/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_TRAFFIC -s $network:$devName:$InterfaceName -t RecvBytes -v $DIFF_InterfaceRecvBytes -i 300\n";
        SUB_appendLogs("/opt/nimsoft/bin/nimqos -q QOS_INTERFACE_TRAFFIC -s $network:$devName:$InterfaceName -t RecvBytes -v $DIFF_InterfaceRecvBytes -i 300");
      }
      elsif ( $tree )
      {
        # Never prints to Log if $tree
        print "    - $InterfaceName\n      - $DIFF_InterfaceSentPkts\n      - $DIFF_InterfaceRecvPkts\n      - $DIFF_InterfaceSentBytes\n      - $DIFF_InterfaceRecvBytes\n";
      }
    }
  }
  else
  {
  }
}
SUB_appendLogs("NOTICE: No interface counters found for Hostname: \"$hostname\"!") if ( ! $outputfound );

# Save for reference on next poll
store($href_curr, $storable_file) or die SUB_appendLogs("FATAL: Cannot to open storable file \"$storable_file\" :: $!");
SUB_appendLogs("Saved current collection of values to storable file: \"$storable_file\".");
print "\n" if ( $debug );

close SNMPWALK;
