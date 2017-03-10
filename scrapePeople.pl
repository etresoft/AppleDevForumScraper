#!/usr/bin/env perl

use strict;
use JSON::PP;

# Build a starting URL.
my $peopleURL =
  "https://forums.developer.apple.com/api/core/v3/people"
  . "?sort=firstNameAsc"
  . "&fields=-resources"
  . "&filter=company%28Apple%29"
  . "&origin=unknown";

my $done = 0;

# Slurp in data instead of reading line by line.
local $/;

my $nextURL = $peopleURL;

print qq{<?xml-stylesheet href="people.xsl" type="text/xsl" ?>};

print "<people>\n";

while(!$done)
  {
  my $data = `curl -s "$nextURL"`;
  
  # Toss the "throw 'allowIllegalResourceCall is false.';" line.
  $data = substr($data, 44);
  
  # Open up the data and parse all the people. 
  $nextURL = parsePeople($data);
  
  last
    if not $nextURL;
  }
  
print "</people>\n";

# Parse JSON input for Apple people.
sub parsePeople
  {
  my $json = shift;
  
  # Decode the JSON.
  my $data = decode_json $json;

  my $list = $data->{list};
  
  foreach my $person (@{$list})
    {
    print "  <person>\n";
    my $id = $person->{id};
    my $displayName = $person->{displayName};
    
    my $enabled = $person->{jive}->{enabled};
    
    my $company = '';
    my $title = '';
    
    foreach my $item (@{$person->{jive}->{profile}})
      {
      if($item->{jive_label} eq 'Title')
        {
        $title = $item->{value};
        }        
      elsif($item->{jive_label} eq 'Company')
        {
        $company = $item->{value};
        }
      }
      
    print "    <name>$displayName</name>\n";
    
    print "    <title>$title</title>\n"
      if $title;
      
    print "    <company>$company</company>\n"
      if $company;
    
    printf("    <active>%s</active>\n", ($enabled ? 'true' : 'false'));
    
    getActivities($id);

    print "  </person>\n";
    }  
    
  return $data->{links}->{next};
  }
  
# Get a person's activities. 
sub getActivities
  {
  my $id = shift;
  
  my $url =
    "https://forums.developer.apple.com"
    . "/api/core/v3/people/$id/activities";
  
  my $nextURL = $url;
  
  my $done = 0;
  
  while(!$done)
    {
    my $data = `curl -s "$nextURL"`;
  
    # Toss the "throw 'allowIllegalResourceCall is false.';" line.
    $data = substr($data, 44);
    
    $nextURL = parseActivities($data);

    last
      if not $nextURL;
    }
  }

# Parse a person's activities.
sub parseActivities
  {
  my $json = shift;
  
  # Decode the JSON.
  my $data = decode_json $json;

  my $list = $data->{list};
  
  foreach my $item (@{$list})
    {
    my $id = $item->{object}->{id};
    my $summary = $item->{object}->{summary};
    
    # These entities aren't defined in XML.
    $summary =~ s/&nbsp;/\n/g;
    $summary =~ s/&rdquo;/”/g;
    $summary =~ s/&ldquo;/“/g;
    $summary =~ s/&rsquo;/’/g;
    $summary =~ s/&lsquo;/‘/g;
    $summary =~ s/&hellip;/…/g;
    $summary =~ s/&rbdquo;/„/g;

    # There might be more entities to worry about.

    my $url = $item->{url};
    my $title = $item->{title};
    my $author = $item->{actor}->{displayName};
    
    my $UUID = getMessage($id, $url, $author, $title);
    
    print "    <post>\n";
    print "      <title>$title</title>\n";
    print "      <url>$url</url>\n";
    
    print "      <summary>$summary</summary>\n";
    print "      <html>html/$UUID.html</html>\n";
    print "    </post>\n";
    }  
    
  return $data->{links}->{next};
  }
  
# Get the HTML content for a post.
sub getMessage
  {
  my $id = shift;
  my $url = shift;
  my $author = shift;
  my $title = shift;
  
  my $json = `curl -s "$id"`;

  # Toss the "throw 'allowIllegalResourceCall is false.';" line.
  $json = substr($json, 44);
  
  my $data = decode_json $json;
  
  my $content = $data->{content}->{text};

  my ($UUID) = $content =~ /\[DocumentBodyStart:(\S+)\]/;
  
  $content =~ s/<body>(.*)<\/body>/$1/;
  
  mkdir "html";
  open(OUT, ">html/$UUID.html");

  my $html =<<EOS;
<!DOCTYPE html>
<html>
  <head>
    <title>$title</title>
    <style>
      .author,
      .subject,
      .url
        {
        font-weight: bold;
        }
        
      #content
        {
        margin: 10px;
        }
    </style>
  </head>
  <body>
    <table>
      <tr>
        <td class="author">Author:</td>
        <td>$author</td>
      </tr>
      <tr>
        <td class="subject">Subject:</td>
        <td>$title</td>
      </tr>
      <tr>
        <td class="url">URL:</td>
        <td><a href="$url" target="_blank">$url</a></td>
      </tr>
    </table>
    </dl>
    <div id="content">
      $content
    </div>
  </body>
</html>
EOS

  print OUT $html;
  
  close(OUT);
  
  return $UUID;
  }