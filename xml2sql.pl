#!/usr/bin/perl

use strict;

use Getopt::Long;
use XML::Parser::Expat;
use DBI;

my $connection;
my $user;
my $password;

GetOptions(
  'db=s' => \$connection,
  'user=s' => \$user,
  'password=s' => \$password
  );

my $input = shift;

die usage()
  if !-f $input;

# Create an Expat stream parser.
my $parser = new XML::Parser::Expat(Style => 'Stream');

# Keep track of title, url, and text.
my $state =
  {
  person => undef,
  post => undef,
  emitText => undef,
  text => undef
  };
  
# Setup the parser.
$parser->setHandlers(
  Start => \&start,
  End => \&end,
  Char => \&text
  );

my $db = DBI->connect($connection, $user, $password, { RaiseError => 1, PrintError => 0 });

# Setup the database.
setupdb();

my %lookup =
  (
  'adminfromnull' => 239641,
  'Maddy_024' => 301308,
  'DankDev' => 433808,
  'bharathrv' => 325236,
  'bcallaha' => 20069,
  'bunnyfromcupertino' => 103519,
  'ChrisLattner' => 17064,
  'clarkcox3' => 16567,
  'custapple' => 399602,
  'dkaleta' => 278878,
  'vespucci' => 11274,
  'SoundOfMind' => 26380,
  'gc.' => 2017,
  'Gopichandrashekhar' => 289394,
  'Mr. GAO' => 2090,
  'Kung Fu Kitty' => 2104,
  'HughJeffreys' => 266361,
  'jacktaylor' => 386492,
  'jacobrj' => 270158,
  'jgreg' => 157634,
  'eskimo' => 2006,
  'grzywacz' => 18091,
  'joshk' => 23636,
  'TidBits' => 21137,
  '4k4' => 365464,
  'kem' => 23701,
  'LiamRodda' => 289709,
  'Malonicus' => 2086,
  'Mattrab' => 20286,
  'matts' => 23657,
  'myke' => 244230,
  'Liamvilar' => 378974,
  'NicolasKadri' => 219034,
  'Sergeant_Nerf' => 90953,
  'pdm' => 2013,
  'Bobjt' => 2022,
  'SPi01' => 285127,
  '_neo42' => 191928,
  'tylerf' => 355161,
  'dudney' => 25946
  );

my $insertPerson = 
  $db->prepare(
    "INSERT INTO people(id, name, title, company, active) VALUES (?, ?, ?, ?, ?)");
my $insertPost = 
  $db->prepare(
    "INSERT INTO posts(id, name, published, title, url, summary, html) VALUES (?, ?, ?, ?, ?, ?, ?)");

# Fire it up!
$parser->parsefile($input);

$db->disconnect;

# Handle a start element.
sub start
  {
  my $expat = shift;
  my $element = shift;
  my %attributes = @_;
 
  # Capture text for the name.
  if($element eq 'name')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the title.
  if($element eq 'title')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the company.
  if($element eq 'company')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the active.
  if($element eq 'active')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the publish date.
  elsif($element eq 'published')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the url.
  elsif($element eq 'url')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the summary.
  elsif($element eq 'summary')
    {
    $state->{emitText} = 1;
    }

  # Capture text for the html.
  elsif($element eq 'html')
    {
    $state->{emitText} = 1;
    }

  # Start capturing a post.
  elsif($element eq 'post')
    {
    $state->{post} = {};
    }

  # Start capturing a person.
  elsif($element eq 'person')
    {
    $state->{person} = {};
    }
  }
  
# Handle an end element.
sub end
  {
  my $expat = shift;
  my $element = shift;

  $state->{text} =~ s/\s*(.+)\s*/$1/;

  if($state->{post})
    {
    if($element eq 'published')
      {
      $state->{post}->{name} = $state->{text};
      }
    elsif($element eq 'title')
      {
      $state->{post}->{title} = $state->{text};
      }
    elsif($element eq 'url')
      {
      $state->{post}->{url} = $state->{text};
      }
    elsif($element eq 'summary')
      {
      $state->{post}->{summary} = $state->{text};
      }
    elsif($element eq 'html')
      {
      $state->{post}->{html} = $state->{text};
      }
    elsif($element eq 'post')
      {
      eval
        {
        $insertPost->execute(
          $lookup{$state->{person}->{name}},
          $state->{person}->{name}, 
          $state->{post}->{published}, 
          $state->{post}->{title}, 
          $state->{post}->{url}, 
          $state->{post}->{summary},
          $state->{post}->{html});
        };

      $state->{post} = undef;
      }
    }
  else
    {
    if($element eq 'name')
      {
      $state->{person}->{name} = $state->{text};
      }
    elsif($element eq 'title')
      {
      $state->{person}->{title} = $state->{text};
      }
    elsif($element eq 'company')
      {
      $state->{person}->{company} = $state->{text};
      }
    elsif($element eq 'active')
      {
      $state->{person}->{active} = $state->{text};
      }
    elsif($element eq 'person')
      {
      eval
        {
        $insertPerson->execute(
          $lookup{$state->{person}->{name}},
          $state->{person}->{name}, 
          $state->{person}->{title}, 
          $state->{person}->{company}, 
          $state->{person}->{active});
        };

      $state->{person} = undef;
      }
    }

  # I must be done.
  $state->{emitText} = 0;
  $state->{text} = undef;
  }
  
# Handle a text node.
sub text
  {
  my $expat = shift;
  my $string = shift;

  $state->{text} = ($state->{text} || '') . $string;
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
Usage: xml2sql.pl <xml file to convert> [options...]
  where [options...] are:
    db = DBI database connection string
    user = Database user 
    password = Database password
EOS
  }
