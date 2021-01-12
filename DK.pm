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
  s/<br *\/?>/ /sg;

  s/<span[^>]*display:none[^>]*>.*?<\/span>//sg; # display:none ignorieren

  s/\{\{ChartplatzierungenX?\}\}(.*?)<\/div>//sg; # chartboxen

  #ignore various tags
  s/<(source|code|syntaxhighlight).*?<\/\1>//sg;

  s/\{\{(DEFAULTSORT|SORTIERUNG):.*?\}\}//sg;

  # hack: GeoQuelle kommt innerhalb von Vorlage:Infobox Fluss vor
  # und verhindert das Ignorieren von späteren Parametern
  s/\{\{GeoQuelle\|.*?\}\}//isg;

  # todo:
  # Zitat-Vorlagen
  # "vermutlich http-link" überprüfen
  # Chartplatzierungen sieht komisch aus
  # Literatur/Weblinks/etc.-Abschnitte verbessern (auch "===")
  #   z.B. [[Alfred Philippson]]
  # {{Großes Bild}}
  # test iso Kontext unabhängig von Zeichen-Anzahl?!

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

  sub check_param {
    # parameter oder Tabelle, auch geklammert, kursiv, fett oder <small>
    my ($a, $b) = @_;
    my $begin_param = '[|=]|!!|\n!';
    my $end_param   = '[|}]|!!|\n!';
    my $ignore_chars = '\s\'\(\)\/0-9\-–;:.,+†*';
    my $ignore_strings = '&nbsp;|Uhr';
    my $ignore_tags = 'small|s|tt|kbd';
    my $ignore_templates = 'SortKey|0';
    my $ignore_before_param = 'https?:\/\/\S+|=';

    my $ignore = "
      ( [$ignore_chars]
      | $ignore_strings
      | </?($ignore_tags)[^>]*>
      | \\{\\{($ignore_templates)(?=[\}\|])[^}]*\\}\\}
      )*";

    my $match_begin_param = $b =~ /($begin_param) $ignore $/sx;
    my $match_before_param = $` =~ /($ignore_before_param)$/;

    my $match_end_param = $a =~ /^ $ignore ($end_param)/sx;

    return (
      d((!$match_begin_param or $match_before_param), "param-begin") and
      d(!$match_end_param, "param-end")
    );
  }

  sub vorlage {
    my ($b, $vorlage, $param) = @_;
    my $re = '\{\{('.$vorlage.')\|[^\}]*$';
    return d($b !~ /$re/si, "vorlage ($vorlage)");
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

    # remove complete <ref> in $after
    $a =~ s/<ref[ >].*?<\/ref>//sg;
    $a =~ s/<ref[^>]*\/>//sg;

    # remove complete templates, wikilinks and comments in $before
    my $bb = $b;
    $bb =~ s/<!--.*?-->//sg;

    $bb =~ s/\[\[[^\[\]]*\]\]//sg;
    while ($bb =~ s/\{\{[^\{\}]*\}\}//sg) {}

    $bb =~ s/<ref[^>]*\/>//sg; # ref-tags without content (like <ref group="foo"/>)
    while ($bb =~ s/<ref[^>]*>.*?<\/ref>//sg) {} # remove complete ref-tags
    $bb =~ s/.*(?:<ref)//sg; # ref-tag found
                             # -> must be inside due to prior removal of complete tags
                             #-> clear before

    return (
      d($month <= 12, "m>12") and  # plausibles Datum
      d($month >= 1, "m<1") and  # plausibles Datum
      d($day <= 31, "d>31") and
      d($day >= 1, "d<1") and
      d($year <= 2100, "y>2100") and
      d($b !~ /https?:\/\/\S*$/, "http-url") and # link
      d($b !~ /\[\/\/\S*$/, "url-without-protocol") and # link
      d($a !~ /^\s*<!--/, "comment") and # Kommentar danach
      ($no_check_param or check_param($a, $b)) and
      d($b !~ /\[\[[^\]\|]+$/, "wikilink") and
      e($a !~ /^[^\[\]]*\][^\]]+/s, "http-label") and # vermutlich http-link
      e($a !~ /^[^<]*<\/ref>/s, "ref") and # ref-tags
      d($b !~ /<ref\s+[^>]*$/i, "refparam") and # für <ref name="....." />
      d($b !~ /DOI=[^ \}\|]*$/s, "DOI-param") and # im PND Eintrag
      d($b !~ /\[\[doi:[^\]\|]*$/is, "DOI-link") and # im PND Eintrag
      d($a !~ /^[^|\n\[]*\.(jpe?g|gif|svg|png|ogg|ogv|pdf|webm|tiff?) *[|\n\]]/i, "filename") and
        # Zeilen/Parameter mit Bild-Endungen am Ende
      d($a !~ /^(-?[A-Z]|[\-:]\d(?!\d*\.\d))/i, "notalone") and # nicht "freistehend"
        # filtert "er-Zweig", "-rc1"," -12", aber nicht "-12.3.1999" oder ":00"
      d($b !~ /(version(snummer)?|kernel|linux|release|mac os|os x)(\]\])?[ :=\-]*$/i, "buzz") and
        # Buzz-Wort
      d($b !~ /\W(kap(itel|\.)?|abs(atz|\.)?|abschnitte?|paragraph|§|definition|lemma|satz|theorem|nr\.|gruppe|tagesordnungspunkt|\w*nummer)(\s|&nbsp;|')*$/i, "systematik") and
        # Systematik
      d($b !~ /(CAS|DIN|EN|VDE|ISO|EC|ÖNORM|RVS|Euronorm)(&nbsp;)?.{0,9}$/, "norm") and
      d(($b !~ /Gemeinden 1994 und ihre Veränderungen seit $/ and $m.$a !~ /^01.01.1948 in den neuen Ländern/), "Spezialfall: Gemeinden 1994") and
      d(($b !~ /Gebietsänderungen vom $/ and $m.$a !~ /^01. Januar bis 31. Dezember/), "Spezialfall: Gebietsänderungen") and
      d(($b !~ /Kultusministerium $/ and $m.$a !~ /^25.02.2016 Drucksache 6\/4829/), "Spezialfall: Denkmalverzeichnis Sachsen-Anhalt I") and
      d(($b !~ /Staatskanzlei und Ministerium für Kultur $/ and $m.$a !~ /^08.03.2019 Drucksache 7\/4067/), "Spezialfall: Denkmalverzeichnis Sachsen-Anhalt II") and
      d($b !~ /data-sort-value *= *["']$/, "data-sort-value") and
      vorlage_param($bb, '[a-z ]*', 'bild|datei|doi|zitat') and
      vorlage_param($bb, 'internetquelle', 'titel|titelerg|werk|zugriff|datum') and
      vorlage_param($bb, 'cite [a-z ]*', 'title') and
      vorlage_param($bb, 'weblink ohne linktext', 'hinweis') and
      vorlage_param($bb, 'literatur', 'titel|titelerg|originaltitel|sammelwerk|werkerg') and
      vorlage_param($bb, '("|zitat)(-\w*)?', 'text|quelle') and
      vorlage_param($bb, 'inschrift', 'text|umschrift') and
      vorlage_param($bb, 'infobox fluss', 'pegel[0-9]|quellschüttung') and
      vorlage_param($bb, 'infobox chemikalie', 'cas') and
      vorlage_param($bb, 'infobox software', 'aktuelle(vorab)?version') and
      vorlage_param($bb, 'infobox rechtsakt \(eu\)', 'fundstelle') and
      vorlage_param($bb, 'überarbeiten', 'grund') and
      vorlage_param($bb, 'lagis', 'titel') and
      vorlage_param($bb, 'onelegresult', '6') and
      vorlage_param_first_unnamed($bb, '("|zitat)(-\w*)?') and
      vorlage_param_first_unnamed($bb, 'inschrift') and
      vorlage_param_first_unnamed($bb, 'salzburger nachrichten') and
      vorlage_param_first_unnamed($bb, 'banz') and
      vorlage_param_first_unnamed($bb, 'wikisource') and
      vorlage_param_first_unnamed($bb, 'doi') and
      vorlage_param_first_unnamed($bb, 'commonscat') and
      vorlage($bb, "PND") and
      vorlage($bb, "DOI") and
      vorlage($bb, 'exzellent|lesenswert|informativ') and
      vorlage($bb, 'lückenhaft|belege|belege fehlen|veraltet') and
      vorlage($bb, "turnierplan.*") and
      vorlage($bb, "datumzelle|sortkey") and
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
      insert_found($`,$&,$') if _check($3, $2, $1, $`, $&, $');
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
