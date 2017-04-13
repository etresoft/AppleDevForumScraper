#!/usr/bin/env perl

use strict;

use JSON::PP;
use Getopt::Long;
use DBI;
use utf8;

my $connection;
my $user;
my $password;

GetOptions(
  'db=s' => \$connection,
  'user=s' => \$user,
  'password=s' => \$password
  );

my $db = DBI->connect($connection, $user, $password, { RaiseError => 1, PrintError => 0 });

# Setup the database.
setupdb();

my $insertPerson = 
  $db->prepare(
    'INSERT INTO people(id, name, title, company, active) VALUES (?, ?, ?, ?, ?)');

my $rowidForUrl = $db->prepare('select rowid from posts where url = ?');

my $insertPost = 
  $db->prepare(
    'INSERT INTO posts(id, name, published, title, url, json, summary) VALUES (?, ?, ?, ?, ?, ?, ?)');

my $updatePost = $db->prepare('UPDATE posts set html = ? where url = ?');

my $fixPublished = $db->prepare('UPDATE posts set published = ? where url = ?');

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
  
# Parse JSON input for Apple people.
sub parsePeople
  {
  my $json = shift;
  
  # Decode the JSON.
  my $data = decode_json $json;

  my $list = $data->{list};
  
  foreach my $person (@{$list})
    {
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
      
    eval
      {
      $insertPerson->execute(
        $id,
        $displayName, 
        $title, 
        $company, 
        ($enabled ? 'true' : 'false'));
      };

    getActivities($id, $displayName);
    }  
   
  return $data->{links}->{next};
  }
  
# Get a person's activities. 
sub getActivities
  {
  my $id = shift;
  my $displayName = shift;
  
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
    
    $nextURL = parseActivities($id, $displayName, $data);

    last
      if not $nextURL;
    }
  }

# Parse a person's activities.
sub parseActivities
  {
  my $personid = shift;
  my $displayName = shift;
  my $json = shift;
  
  # Decode the JSON.
  my $data = decode_json $json;

  my $list = $data->{list};
  
  foreach my $item (@{$list})
    {
    next
      if not $item->{url};

    my ($message) = $item->{url} =~ /#(\d+)$/;

    $message = scrapeMessage($item->{url})
      if not $message;

    my $id = "https://forums.developer.apple.com/api/core/v3/messages/$message";

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

    my $author = $item->{actor}->{displayName};
    
    eval
      {
      $rowidForUrl->execute($item->{url});

      my ($rowid) = $rowidForUrl->fetchrow;

      if($rowid > 0)
        {
        $fixPublished->execute($item->{published}, $item->{url});
        }
      else
        {
        eval
          {
          $insertPost->execute(
            $personid, 
            $displayName,
            $item->{published}, 
            $item->{title}, 
            $item->{url}, 
            "json/$message.json",
            $summary);

          $rowid = $db->sqlite_last_insert_rowid();
          my $htmlid = "html/$rowid.html";

          $updatePost->execute($htmlid, $item->{url});
          };
        }

      my $htmlid = "html/$rowid.html";
        
      if(!-e $htmlid)
        {
        print "Saving $id\n";

        getMessage(
          $htmlid, 
          $id, 
          $message,
          $item->{url}, 
          $item->{published}, 
          $displayName, 
          $item->{title});
        };
      };
    }  
    
  return $data->{links}->{next};
  }
  
# Get the message id from a thread.
sub scrapeMessage
  {
  my $url = shift;

  my ($thread) = $url =~ m|/thread/(\d+)$|;

  my $html = `curl -s "$url"`;

  my ($message) = $html =~ m|action="/post.jspa\?container=\d+\&containerType=14\&thread=$thread\&message=(\d+)\&reply=true"|gsm;
  
  return $message;
  }

# Get the HTML content for a post.
sub getMessage
  {
  my $htmlid = shift;
  my $id = shift;
  my $message = shift;
  my $url = shift;
  my $date = shift;
  my $author = shift;
  my $title = shift;
  
  my $json = `curl -s "$id"`;

  # Toss the "throw 'allowIllegalResourceCall is false.';" line.
  $json = substr($json, 44);
  
  my $data = decode_json $json;
  
  my $content = $data->{content}->{text};

  $content =~ s/<body>(.*)<\/body>/$1/;
  
  mkdir "html";
  open(OUT, ">$htmlid");
  binmode(OUT, ":utf8");

  my $html =<<EOS;
<!DOCTYPE html>
<html>
  <head>
    <title>$title</title>
    <style>
      .date,
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
        <td class="date">Date:</td>
        <td>$date</td>
      </tr>
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

  mkdir "json";
  open(JSON, ">json/$message.json");
  binmode(JSON, ":utf8");

  print JSON $json;
  
  close(JSON);
  }

# Setup the database.
sub setupdb
  {
  my $createPeople = << 'EOS';
create table if not exists people
  (
  id text,
  name text,
  title text,
  company text,
  active text
  )
EOS

  $db->do($createPeople);

  my $createPeopleIdIndex = << 'EOS';
create unique index if not exists people_id_index on people (id);
EOS

  $db->do($createPeopleIdIndex);

  my $createPeopleNameIndex = << 'EOS';
create index if not exists people_name_index on people (name);
EOS

  $db->do($createPeopleNameIndex);

  my $createPosts = << 'EOS';
create table if not exists posts
  (
  id text,
  name text,
  published text,
  title text,
  url text,
  json text,
  summary text,
  html text
  )
EOS

  $db->do($createPosts);

  my $createPostsIndex = << 'EOS';
create unique index if not exists posts_index on posts (url);
EOS

  $db->do($createPostsIndex);
  }

sub usage
  {
  return << 'EOS';
Usage: scrapePeople.pl [options...]
  where [options...] are:
    db = DBI database connection string
    user = Database user 
    password = Database password
EOS
  }
