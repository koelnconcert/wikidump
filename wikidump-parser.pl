#!/usr/bin/perl
use strict;
use Getopt::Std;
use Pod::Usage;
use XML::Parser;

getopts("hc:l:i:", \my %opts);

pod2usage(-verbose => 1) if $opts{h};
pod2usage unless @ARGV;

binmode(STDOUT, ":utf8");

my $show_context = $opts{c} || 30;
my $show_contextlines = $opts{l} || 0;
my $show_info = $opts{i} || 0;
my $count = 0;
my $modstr = $ARGV[0];
my $mod;
my $fileext;
if ($modstr eq "dk") {
  $mod = \&mod_datumsformat;
} else {
  pod2usage("no module selected");
}

#mod_selbstlinks($p, $title, $text);
#mod_plusdagger($p, $title, $text);

my $filename = $ARGV[1];
my $filesize = -s $filename;

my %found;
my %context;
my %info;

my $p = new XML::Parser();
$p->setHandlers(
  Start => \&handle_start,
  End   => \&handle_end,
  Char  => \&handle_text,
);
$p->parsefile($filename);


###########################################
sub main {
###########################################
  $count++;
  my($p, $title, $text) = @_;
  $text =~ s/\n//gm;

  &$mod($p, $title, $text);
  
  if ($count % 1000 == 0) {
    printf STDERR "%2.2f\%\n", $p->current_byte/$filesize*100;
    
  }
  if ($found{$title}){
    chomp $context{$title};
    output_one($title);
  }
}

###########################################
# Modules
###########################################

###########################################
sub mod_selbstlinks {
###########################################
  my($p, $title, $text) = @_;
  $_ = $text;
  while (/\[\[([^\]\|]+)(\||\]\])/) {
    if ($1 eq $title) {
      insert_found($title,$`,$&,$');
    }
    $_=$';
  }
}

###########################################
sub mod_datumsformat {
###########################################
  my($p, $title, $text) = @_;
  $_ = $text;

  s/== *(Literatur|Weblinks?|Quellen?|Bibliographie)(.*?)==(.*?)(?===|\[\[Kategorie|\{\{Personendaten|$)//sg; # Abschnitte entfernen
  s/\{\{Chartplatzierungen\}\}(.*?)<\/div>//sg; # chartboxen

  while (/(\d{1,2})\. ?(\d{1,2})\. ?(\d{2}(\d{2})?)/) {
    if ($' !~ /^\.?\d/ and   # nur drei Zahlengruppen
        $` !~ /\d\.?$/ and  
	$2 <= 12 and  # plausibles Datum 
	$2 >= 1 and  # plausibles Datum 
	$1 <= 31 and
	$1 >= 1 and
	$` !~ /http:\/\/\S*$/ and # link
	$' !~ /^ *<!-- ?sic/ and
        $' !~ /^ *\|/ and # parameter
        $' !~ /^[^\[\]]*\][^\]]+/ and # vermutlich http-link
	$' !~ /^[^<]*<\/(ref|small|gallery)>/ and # small- und ref-Tag
	$' !~ /^[^<]*\/>/ and # f�r <ref name="....." />
	$` !~ /<!--[^>]*$/ and # Kommentar
        $` !~ /\{\{PND[^\}]*$/s and # im PND Eintrag
        $` !~ /\[\[(Bild|Image):[^\]\|]*$/i # Bild-Wikilink
      ) {
      insert_found($title,$`,$&,$');
    }
    $_ = $';
  }
}

###########################################
sub mod_plusdagger {
###########################################
  my($p, $title, $text) = @_;
  $_ = $text;
  while (/[;,] ?\+ ?(\[\[)?\d{1,2}\./) {
    insert_found($title,$`,$&,$');
    $_ = $';
  }
}

###########################################
# Allgemeine Routinen
###########################################

###########################################
sub insert_found {
###########################################
  my($title, $before, $match, $after) = @_;
  $found{$title}++;
  $context{$title} .= substr($before,length($before)-$show_context,$show_context)
        	      .$match.substr($after,0,$show_context)."\n";
  if ($found{$title} <= $show_info || $show_info == -1) {
    $info{$title} .= ", $match";
  } elsif ($found{$title} == $show_info + 1 && $show_info != 0) {
    $info{$title} .= ", ...";
  }
}

###########################################
sub output_one {
###########################################
  my ($title) = @_;
  my $found = $found{$title};
  my $context = $context{$title};
  print "*[[$title]]";
  if ($info{$title}) {
    print $info{$title};
  }
  if ($found > $show_info) {
    print " ($found)";
  }
  print "\n";
  $| = 1;
  my $i = 0;
  foreach my $line (split /\n/, $context) {
    if ($i++ < $show_contextlines || $show_contextlines == -1) { 
      print "<nowiki>$line</nowiki><br/>\n"; 
    }
  }
}

###########################################
# Handler
###########################################

my $is_title;
my $title;
my $is_text;
my $text;

###########################################
sub handle_start {
###########################################
  my($p, $tag, %attrs) = @_;
  if ($tag eq 'title') { $is_title = 1; }
  if ($tag eq 'text') { $is_text = 1; $text="";}
}

###########################################
sub handle_end {
###########################################
  my($p, $tag) = @_;
  if ($tag eq 'text') { $is_text = 0; }
  if ($tag eq 'page' and $title !~ /:/) { 
    main($p,$title,$text); 
  }
}

##########################################
sub handle_text {
###########################################
  my($p, $cdata) = @_;
  if ($is_title) {
    $title = $cdata;
    $is_title = 0;
  } elsif ($is_text) {
    $text .= $cdata;
  }
}


__END__

=head1 NAME

wikidump-parser - Parse wikipedias xml-dump

=head1 SYNOPSIS

wikidump-parser [-h] [-i <#>] [-l <#>] [-c <#>] <mod> <xml-dump-file>

=head1 ARGUMENTS

  dk     # Datumskonvention (1.1.2000)

=head1 OPTIONS

  -i <#> # num. of occurences to be shown (0), -1=infty
  -l <#> # num. of context-lines to be shown (0), -1=infty;
  -l <#> # num. of context-chars to be shown before/after occurence (30)
  -h     # show help
