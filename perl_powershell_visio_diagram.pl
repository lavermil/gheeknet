#!/usr/local/bin/perl
 
my $filename = $ARGV[0];
my @arr = do {
    open my $fh, "<", $filename
        or die "could not open $filename: $!";
    <$fh>;
};
 
my $hash = {};
my $save_location = 'c:';
 
# Where to place each diagram
# 0 = Each Diagram goes on new page
# 1 = Each Diagram goes in its own Visio file
my $newdocper = 0;
 
my $site = '';
my $site_clean = '';
my $cnt = 0;
for my $line (@arr)
{
  chomp($line);
  if ( $line =~ /label/ )
  {
    $site = '';
    (undef, $site) = split(/ = /, $line);
    $site_clean = $site;
    $site_clean =~ s/"//g;
    $site_clean =~ s/-/_/g;
    $site_clean =~ s/#/NUM/g;
    $site_clean =~ s/&/_/g;
    $site_clean =~ s/\(//g;
    $site_clean =~ s/\)//g;
    $site_clean =~ s/\//_/g;
    $site_clean =~ s/ /_/g;
    $site_clean =~ s/\./_/g;
  }
  else
  {
    $cnt++;
    my ($from, $to, $label, $linetype) = split(/,/, $line);
    my $to_clean = $to;
    $to_clean =~ s/"//g;
    $to_clean =~ s/-/_/g;
    $to_clean =~ s/#/NUM/g;
    $to_clean =~ s/&/_/g;
    $to_clean =~ s/\(//g;
    $to_clean =~ s/\)//g;
    $to_clean =~ s/\//_/g;
    $to_clean =~ s/ /_/g;
    $to_clean =~ s/\./_/g;
    my $to_normal = $to;
    my $from_clean = $from;
    $from_clean =~ s/"//g;
    $from_clean =~ s/-/_/g;
    $from_clean =~ s/#/NUM/g;
    $from_clean =~ s/&/_/g;
    $from_clean =~ s/\(//g;
    $from_clean =~ s/\)//g;
    $from_clean =~ s/\//_/g;
    $from_clean =~ s/ /_/g;
    $from_clean =~ s/\./_/g;
    my $from_normal = $from;
 
    # Build Node portion of hash
    $hash->{$site_clean}->{'nodes'}->{$from}->{'clean'} = $from_clean;
    $hash->{$site_clean}->{'nodes'}->{$from}->{'normal'} = $from_normal;
    $hash->{$site_clean}->{'nodes'}->{$to}->{'clean'} = $to_clean;
    $hash->{$site_clean}->{'nodes'}->{$to}->{'normal'} = $to_normal;
 
    # Build links portion of hash
    $hash->{$site_clean}->{'links'}->{$cnt}->{'from'} = $from_clean;
    $hash->{$site_clean}->{'links'}->{$cnt}->{'to'} = $to_clean;
    $hash->{$site_clean}->{'links'}->{$cnt}->{'label'} = $label;
    $hash->{$site_clean}->{'links'}->{$cnt}->{'linetype'} = $linetype;
     
  }
}
 
print "Set-StrictMode -Version 2\n";
print "\$ErrorActionPreference = \"Stop\"\n";
print "Import-Module Visio\n";
print "\$options = New-Object VisioAutomation.Models.DirectedGraph.MSAGLLayoutOptions\n";
print "\$d = New-VisioDirectedGraph\n";
print "\$app = New-Object -ComObject Visio.Application \n";
print "\$app.visible = \$true \n";
print "\$docs = \$app.Documents \n";
print "\$doc = \$docs.Add(\"DTLNET_U.vst\") \n";
print "\$pages = \$app.ActiveDocument.Pages \n";
print "\$page = \$pages.Item(1)\n";
print "\$stencil = \$app.Documents.Add(\"My_Network_Stencil_Pack.vss\")\n";
print "\$backgroundborder = \$stencil.Masters.Item(\"Background Border\")\n";
print "\$infobar = \$stencil.Masters.Item(\"Info Bar on Background\")\n";
print "\$page.Name = \"background\"\n";
print "\$page.AutoSize = \$false\n";
print "\$page.Background = \$true\n";
print "\$page.Document.PrintLandscape = \$true\n";
print "\$page.document.PrintFitOnPages = \$true\n";
print "\$bg = \$page.Drop(\$backgroundborder, 5.5, 4.25) \n";
print "\$bginfobar = \$page.Drop(\$infobar, 8.0646, 0.95) \n";
print "\$page.CenterDrawing\n";
print "if (-Not (Test-VisioApplication) ) \n";
print "{\n";
print "    Connect-VisioApplication\n";
print "}\n";
print "if (-Not (Test-VisioDocument) )\n";
print "{\n";
print "    Set-VisioDocument -Name Drawing1\n";
print "}\n";
print "Set-VisioPageCell -PageWidth 11.0 -PageHeight 8.5\n";
for my $sitekey ( sort keys %$hash )
{
  print "\$d = New-VisioDirectedGraph\n";
  #my $nodecnt = 1;
  #my @custprops = ();
  # Print out all Nodes per Site
  for my $node ( sort keys %{$hash->{$sitekey}->{'nodes'}} )
  {
    my $node_label = $hash->{$sitekey}->{'nodes'}->{$node}->{'normal'};
    my $node_name = $hash->{$sitekey}->{'nodes'}->{$node}->{'clean'};
    my $node_stencil = "BASIC_U.VSS";
    my $node_shape = "Rectangle";
    my $node_stencil_my = "My_Network_Stencil_Pack.vss";
    my $node_shape_l2switch = "Cisco L2 Switch DG";
    my $node_shape_l3switch = "Cisco L3 Switch DG";
    my $node_shape_rtr = "Cisco Router DG";
    my $node_shape_fw = "Cisco ASA 5500 Series DG";
    my $node_shape_cloud = "Cloud";
    my $node_shape_rectangle = "Rectangle DG";
    my $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil\", \"$node_shape\")\n";
    #my $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_rectangle\")\n";
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_cloud\")\n" if ( $node_name =~ /qmoe/i );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_l3switch\")\n" if ( $node_name =~ /3850/ );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_l3switch\")\n" if ( $node_name =~ /6500/ );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_l2switch\")\n" if ( $node_name =~ /as/ );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_rtr\")\n" if ( $node_name =~ /wr\d\d/i );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_rtr\")\n" if ( $node_name =~ /vrf_/i );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_rtr\")\n" if ( $node_name =~ /rt\d\d/i );
    $nodename = "\$$node_name = \$d.AddShape(\"$node_name\",\"$node_label\", \"$node_stencil_my\", \"$node_shape_fw\")\n" if ( $node_name =~ /fw\d\d/i );
    print $nodename;
  }
 
  for my $linknum ( sort keys %{$hash->{$sitekey}->{'links'}} )
  {
    # Print out all links per Site
    my $linknum_ = "C" . $linknum;
    my $from_ = $hash->{$sitekey}->{'links'}->{$linknum}->{'from'};
    my $to_ = $hash->{$sitekey}->{'links'}->{$linknum}->{'to'};
    my $label_ = $hash->{$sitekey}->{'links'}->{$linknum}->{'label'};
    my $linetype_ = $hash->{$sitekey}->{'links'}->{$linknum}->{'linetype'};
    print "\$d.AddConnection(\"$linknum_\",\$$from_,\$$to_,\"$linknum_\",\"$linetype_\")\n";
  }
  print "New-VisioDocument\n" if ( $newdocper );
  print "\$p = New-VisioPage -Name \"$sitekey\"  -Height 8.5 -Width 11\n" if ( ! $newdocper );
  print "\$d.Render(\$p,\$options)\n";
  print "\$shapes = Get-VisioShape *\n";
  print "\$rectids = \$shapes | where { \$_.NameU -like \"*rectangle*\"} | Select ID\n";
  print "if (\$rectids)\n";
  print "{\n";
  print "    Select-VisioShape \$rectids.ID\n";
  print "    Set-VisioShapeCell -Width 0.6049 -Height 0.475\n";
  print "    Set-VisioPageLayout -Orientation Landscape -BackgroundPage background\n";
  print "    Set-VisioPageCell -PageWidth 11.0 -PageHeight 8.5\n";
  print "}\n";
  print "Select-VisioShape None\n";
 
  print "Save-VisioDocument \"$save_location\\$sitekey.vsd\"\n" if ( $newdocper );
  print "\$od = Get-VisioDocument -ActiveDocument\n" if ( $newdocper );
  print "Close-VisioDocument -Documents \$od\n" if ( $newdocper );
}
