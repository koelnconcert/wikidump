package DK;
use strict;
use utf8;
use Data::Dumper;

my @founds;
my %dk_filter_stats;
my $dk_filter_stats = 0;
my $debug = 0;
my $secondary_flag = 0;

sub check {
  @founds = ();
  %dk_filter_stats = ();
  $dk_filter_stats = 0;
  $secondary_flag = 0;
  mod_datumsformat(@_);
  return @founds;
}

###########################################
# Konstanten
###########################################

my %monat_lang = (
  Januar => 1, "Jänner" => 1,
  Februar => 2,
  "März" => 3,
  April => 4,
  Mai => 5,
  Juni => 6,
  Juli => 7,
  August => 8,
  September => 9,
  Oktober => 10,
  November => 11,
  Dezember => 12);

my %monat;
while (my ($lang, $num) = each %monat_lang) {
  my $kurz = substr($lang,0,3);
  $monat{$lang} = $num;
  $monat{$kurz} = $num;
  $monat{$kurz."."} = $num;
}

###########################################
sub mod_datumsformat {
###########################################
  my($page, $mod) = (@_, "dk");
  return unless $page->namespace eq ''; # nur Artikel-Namensrausm

  $_ = ${$page->text};

  s/<!--.*?-->/<!-- -->/sg; # Kommentare leeren

  s/<span[^>]*display:none[^>]*>.*?<\/span>//sg; # display:none ignorieren

  s/\{\{ChartplatzierungenX?\}\}(.*?)<\/div>//sg; # chartboxen

  s/<source.*?<\/source>//sg; # source-Tag

  s/{{(DEFAULTSORT|SORTIERUNG):.*?}}//sg;

  # todo: 
  # Zitat-Vorlagen
  # "vermutlich http-link" überprüfen
  # Chartplatzierungen sieht komisch aus
  # Literatur/Weblinks/etc.-Abschnitte verbessern (auch "===")
  #   z.B. [[Alfred Philippson]]
  # {{Großes Bild}} 
  
  sub d {
    my ($bool, $text) = @_;
    $dk_filter_stats{$text}++ if !$bool;
    if ($debug) {
      print STDERR "  $text\n";
      print STDERR "    match\n" if !$bool;
    }
    return $bool;
  }

  sub e {
    my $bool = d(@_);
    $secondary_flag = 1 if !$bool;
    print STDERR "    secondary\n" if $debug and !$bool;
    return 1;
  }

  sub vorlage_param {
    my ($b, $vorlage, $param) = @_;
    my $re = '\{\{('.$vorlage.')(?![a-z])[^\}]*\|\s*('.$param.')\s*=[^|\}]*$';
    return d($b !~ /$re/si, "vorlage ($vorlage) param ($param)");
  }

  sub vorlage_param_first_unnamed {
    my ($b, $vorlage) = @_;
    my $re = '\{\{('.$vorlage.')(?![a-z])[^\}|]*\|[^|=\}]*$';
    return d($b !~ /$re/si, "vorlage ($vorlage) first unnamed param");
  }

  sub _check {
    my ($day, $month, $year, $before, $match, $after, $no_check_param) = @_;
    my ($a, $m, $b) = ($after, $match, $before);
    $dk_filter_stats++;

    print STDERR "check $match\n" if $debug;

    return (
      d($month <= 12, "m>12") and  # plausibles Datum 
      d($month >= 1, "m<1") and  # plausibles Datum 
      d($day <= 31, "d>31") and
      d($day >= 1, "d<1") and
      d($year <= 2100, "y>2100") and
      d($b !~ /https?:\/\/\S*$/, "http-url") and # link
      d($a !~ /^\s*<!--/, "comment") and # Kommentar danach
      ($no_check_param or (
        d($b !~ /[|=][\s'\(]*$/s, "param1") and 
         # parameter oder Tabelle, auch geklammert, kursiv oder fett
        d($a !~ /^[\s'\)]*\|/s, "param2") and 
          # parameter oder Tabelle, auch geklammert, kursiv oder fett
        1
      )) and
      e($a !~ /^[^\[\]]*\][^\]]+/s, "http-label") and # vermutlich http-link
      e($a !~ /^[^<]*<\/ref>/s, "ref") and # ref-tags
      d($b !~ /<ref\s+[^>]*$/i, "refparam") and # für <ref name="....." />
      d($b !~ /\{\{PND[^\}]*$/s, "PND") and # im PND Eintrag
      d($b !~ /\{\{DOI[^\}]*$/s, "DOI-vorlage") and # im PND Eintrag
      d($b !~ /DOI=[^ \}\|]*$/s, "DOI-param") and # im PND Eintrag
      d($b !~ /\[\[doi:[^\]\|]*$/is, "DOI-link") and # im PND Eintrag
      d($a !~ /^[^|\n\[]*\.(jpe?g|gif|svg|png|ogg|ogv|pdf) *[|\n\]]/i, "filename") and
        # Zeilen/Parameter mit Bild-Endungen am Ende
      d($a !~ /^(-?[A-Z]|-\d(?!\d*\.\d))/i, "notalone") and # nicht "freistehend"
        # filtert "er-Zweig", "-rc1"," -12", aber nicht "-12.3.1999"
      d($b !~ /(version|kernel|linux|mac os|os x)(\]\])?[ :=]*$/i, "buzz") and 
        # Buzz-Wort
      d($b !~ /\W(kap(itel|\.)?|abs(atz|\.)?|abschnitte?|paragraph|§|lemma|satz|theorem)(\s|&nbsp;)*$/i, "gliederung") and 
        # Gliederung
      d(($b !~ /Gemeinden 1994 und ihre Veränderungen seit $/ and $m.$a !~ /^01.01.1948 in den neuen Ländern/), "spezialfall") and # condition in parenthesis required, others use of unitializied value in d()
      vorlage_param($b, 'internetquelle', 'titel|titelerg') and
      vorlage_param($b, 'cite web', 'title') and
      vorlage_param($b, 'weblink ohne linktext', 'hinweis') and
      vorlage_param($b, 'literatur', 'titel|titelerg|originaltitel') and
      vorlage_param($b, '("|zitat)(-\w*)?', 'text') and
      vorlage_param($b, 'infobox fluss', 'pegel.*') and
      vorlage_param_first_unnamed($b, '("|zitat)(-\w*)?') and
      vorlage_param_first_unnamed($b, 'salzburger nachrichten') and
      vorlage_param_first_unnamed($b, 'banz') and
      vorlage_param_first_unnamed($b, 'wikisource') and
      1
    );
  }

  #
  # 1.2.1999, 01.02.99
  #

  if ($mod eq "dk") {
    while (/(?<![.0-9])(\d{1,2})\.(?:\ |&nbsp;)*(\d{1,2})\. # Tag und Monat
            (?:\]\])?(?:\ |&nbsp;)*(?:\[\[)? # Verlinkungen
	    (\d{2}(\d{2})?)(?!\.?\d) # Jahr
	   /gx ) {
      insert_found($`,$&,$') if _check($1, $2, $3, $`, $&, $');
    }
  }
  
  #
  # 1.02.799
  #

  if ($mod eq "dkyyy") {
    while (/(?<![.0-9])(\d{1,2})\.(?:\ |&nbsp;)*(\d{1,2})\. # Tag und Monat
            (?:\]\])?(?:\ |&nbsp;)*(?:\[\[)? # Verlinkungen
	    (\d{3})(?!\.?\d) # Jahr
	   /gx ) {
      if (_check($1, $2, $3, $`, $&, $') and
          $3 ne "000"
      ) {
        insert_found($`,$&,$');
      }	
    }
  }

  #
  # 1999-2-1, 1999-02-01
  #
  
  if ($mod eq "dk") {
    while (/(?<![\-0-9])(\d{4})-(\d{1,2})-(\d{1,2})(?![\-0-9])/g) {
      if (_check($3, $2, $1, $`, $&, $') and
          $` !~ /(CAS|DIN|EN|VDE|ISO|EC).{0,9}$/ 
      ) {
        insert_found($`,$&,$') 
      }
    }
  }

  #
  # 01. Februar 1999,  02. Apr. 2008, 03 Jan 2009
  #
 
  if ($mod eq "dk") {
    while (/\b(0\d)\.?(?:\ |&nbsp;)*([\w\.]+) # Tag und Monat
            (?:\]\])? 
	    (?:(?:\ |&nbsp;)*(?:\[\[)? 
	       (\d{4})(?!\d) # Jahr
	    )? # optional
	   /gx) {
      my $monat = $monat{ucfirst lc $2};
      if (defined $monat and
          _check($1, $monat, 2000, $`, $&, $', "no_check_param")
      ) {
        insert_found($`,$&,$');
      }
    }
  }

  #
  # 1. Januar 38
  #

  if ($mod eq "dkyy" and ! /[vn]\. (Chr\.|u\. Z)/ 
      and ! /Römische Kaiserzeit/
  ) {
    while (/\b(\d{1,2})\.\ *([\w\.]+)\ +'?(\d{2})(?![.:]?\d)/g) {
      if (defined $monat{$2} and
          $' !~ /^(\s*|&nbsp;)(°|%|mm|km|cm)/ and
	  $' !~ /^\?\?/ and # 19??
	  $' !~ /^,\d/ and
          $' !~ /^(\s*|&nbsp;)(\[\[)?((kilo|zenti|milli)?meter|(see)?meile
	         |uhr|mark|euro|prozent
		 |jahre|tage|stunden
		 |mann|schiffe)/ix and
          _check($1, $monat{$2}, 2000, $`, $&, $')
      ) {
        insert_found($`,$&,$');
      }
    }
  }

  #
  #  20er
  #
  
  if ($mod eq "dker" or
#      $mod eq "dk" or 
      0) {
    while (/(?<![\-0-9])([1-9]0er[-\ ]*Jahre)/g) {
      if ($' !~ /^.{0,30}(Jahrhundert|Jh)/) {
        $secondary_flag = $mod eq "dk";
        insert_found($`,$&,$');
      }	
    }
  }

}

###########################################
sub insert_found {
###########################################
  my($before, $match, $after) = @_;
  push @founds, {
    before => $before,
    match => $match,
    after => $after,
    secondary_flag => $secondary_flag
  };
  $secondary_flag = 0;
}

1;
