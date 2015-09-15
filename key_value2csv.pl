#!/usr/bin/perl
#Author: Lance Vermilion
#Purpose: Parse sets of data (configuraiton files i.e .ini, etc) that are setup in a key value format.
#         This generally works well for ini files, script config files, network device outputs, etc.
#Demo: http://gheeknet.heliohost.org/cgi-bin/key_value2csv.pl
#Type: Perl/CGI
##############################
use strict;

use CGI qw(:all);
my $cgi = new CGI;
my $this_url = $cgi->url();
my $sectionregexkey = $cgi->param('sectionregexkey');
my $sectionregexdelimiter = $cgi->param('sectionregexdelimiter');
my $sectionregexvalue = $cgi->param('sectionregexvalue');
my $keyvalueregexkey = $cgi->param('keyvalueregexkey');
my $keyvalueregexdelimiter = $cgi->param('keyvalueregexdelimiter');
my $keyvalueregexvalue = $cgi->param('keyvalueregexvalue');
my $list = $cgi->param('list');
my @arr = split('\n', $list);


print "Content-type: text/html\n\n";
print <<EndOfHTML;
<html>
<head>
<title>Switch Template</title>
</head>
<body>
<FORM action="$this_url" method="POST">
<table border="1" bgcolor="#D3D3D3">
<tr><th>Section Regex Key</th><th>Section Regex Delimiter</th><th>Section Regex Value</th></tr>
<tr>
  <td><textarea rows="1" cols="60" name="sectionregexkey">^(start data chunk)</textarea></td>
  <td><textarea rows="1" cols="24" name="sectionregexdelimiter"> </textarea></td>
  <td><textarea rows="1" cols="60" name="sectionregexvalue">(.*)</textarea></td>
</tr>
<tr>
<tr><td colspan=3>&nbsp;</td></tr>
<tr><th>Key/Value Regex Key</th><th>Key/Value Regex Delimiter</th><th>Key/Value Regex Value</th></tr>
  <td><textarea rows="1" cols="60" name="keyvalueregexkey">^\\s+(.*)</textarea></td>
  <td><textarea rows="1" cols="24" name="keyvalueregexdelimiter"> </textarea></td>
  <td><textarea rows="1" cols="60" name="keyvalueregexvalue">(value\\d.*)</textarea></td>
</tr>
</table>
There must be two things to match on creating a key/value pair per section.
<ul>
<li>First match goes in the first set of parenthesis (aka Key).</li>
<li>Second match goes in the second set of parenthesis (aka Value).</li>
<li>Last there must be something used as a delimiter between the key and value.</li>
</ul>
<b>List of Key Value Pairs:</br></b> <textarea rows="10" cols="60" name="list">start data chunk abc
  key1 value1
  key2 value2
start data chunk def
  key2 value2
start data chunk ghi
  key1 value1
start data chunk jkl
  key1 value1
  key2 value2</textarea></br>
<input type="submit" value="Create CSV">
</FORM>
</br>
<hr>
EndOfHTML

chomp($list);
my $sectionregex = $sectionregexkey . $sectionregexdelimiter . $sectionregexvalue;
chomp($sectionregex);
my $keyvalueregex = $keyvalueregexkey . $keyvalueregexdelimiter . $keyvalueregexvalue;
chomp($keyvalueregex);

# Unique set of Keys
my $href_keys = {};
# List of Key1/Key2/Values in data provided
my $href_data = {};
# New list of Key/Values as an array
# If Key2 does not exist for Key1 it will be added as a blank values. This allows a proper CSV to be presented.
my $href_csv = {};
 
my $tmpkey = '';
 
for my $line (@arr)
{
  chomp($line);
  $line =~ s/\r//g; #Just in case you have CR
  $line =~ s/\n//g; #Just in case you have New Line / LF
  #if ( $line =~ /^(start data chunk) (.*)/ )
  if ( $line =~ /$sectionregex/ )
  {
    $tmpkey = $2;
    $href_keys->{$tmpkey}->{$1} = $2;
    $href_data->{$1} = '';
  }
  #if ( $line =~ /^\s+(.*) (value\d.*)/ )
  if ( $line =~ /$keyvalueregex/ )
  {
    $href_keys->{$tmpkey}->{$1} = $2;
    $href_data->{$1} = '';
  }
}
 
 
for my $href_data_k1 ( sort keys %$href_data )
{
  my $newkey = $href_data_k1;
  $newkey =~ s/$sectionregexkey/_$1/g;
  #$newkey =~ s/(start data chunk)/_$1/g;
  for my $href_keys_k1 ( sort keys %$href_keys )
  {
    my $val = '';
    $val = $href_keys->{$href_keys_k1}->{$href_data_k1} if ( $href_keys->{$href_keys_k1}->{$href_data_k1} );
    push(@{$href_csv->{$newkey}}, $val);
  }
}
 
print "<h3>Input Regex (not including the beginning and ending \")</h3>\n";
print "<b>Using Section Regex:</b> \"$sectionregex\"</br>\n";
print "<b>Using Key/Value Regex:</b> \"$keyvalueregex\"</br>\n";
print "<hr>\n";
print "<h3>CSV Format</h3>\n";
for my $href_csv_k1 ( sort keys %$href_csv )
{
  my $href_csv_newk1 = $href_csv_k1;
  $href_csv_newk1 =~ s/_//g;
  if ( @{$href_csv->{$href_csv_k1}} )
  {
    print "$href_csv_newk1,", join(",", @{$href_csv->{$href_csv_k1}}), "</br>\n";
  }
  else
  {
    print "No Data to print, check your REGEX!</br>\n";
  }
}

print "</body>\n";
print "</html>\n";
