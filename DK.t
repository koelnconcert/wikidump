#!/usr/bin/perl
use strict;
use utf8;
use Test::More tests => 295;
use DK;
use MockWikiPage;
use Data::Dumper;
use Class::Inspector;

#
# Tests
#

sub test_standard {
  found("1.1.2000");
  found("1.1.99");
  found("1.01.2000");
  found("01.01.2000");
  found("01.01. 2000");
  found("01. 01.2000");
  found("01. 01. 2000");
  found("01.&nbsp;01. 2000");
  found("01. 01.&nbsp;2000");
  found("01.01.[[2000");

  notfound("1.1.999");

  notfound(".1.1.2000");
  notfound("1.1.2000.1");
}

sub test_iso {
  found("2000-01-01");
  found("2000-1-01");
  found("2000-01-1");
  notfound("99-01-01");
  #TODO [2000]-01-01 ?

  notfound("2000-01-01-");
  notfound("-2000-01-01");
}

sub test_iso_context {
  notfound("ISO2000-01-01");
  notfound("ISO 2000-01-01");
  notfound("CAS 2000-01-01");
  notfound("DIN 2000-01-01");
  notfound("VDE 2000-01-01");
  notfound("EN 2000-01-01");
  notfound("EC 2000-01-01");
  notfound("Euronorm 2000-01-01");
  notfound("EN&nbsp;60204-1:2007-08-01");
  notfound("ÖNORM A 8010:2010-07-15");
  notfound("RVS 01.01.01");
  found("iso 2000-01-01", "2000-01-01");

  notfound("ISO 9_chars 2000-01-01");
  found("ISO 10_chars 2000-01-01", "2000-01-01");
}

sub test_plausible {
  found("1.1.2000");
  notfound("0.1.2000");
  notfound("32.1.2000");
  notfound("1.0.2000");
  notfound("1.13.2000");
  notfound("1.1.2101");
}

sub test_monthnames {
  my @months = qw(
    Januar Jänner Jan Jan.
    Februar Feb Feb.
    April Apr Apr.
    März Mär Mär.
    Mai
    Juni Jun Jun.
    Juli Jul Jul.
    August Aug Aug.
    September Sep Sep.
    Oktober Okt Okt.
    November Nov Nov.
    Dezember Dez Dez.
  );

  found("01. $_ 2000") for (@months);

  found("01. januar 2000");
  found("01&nbsp;Jan [[2000");
}

sub test_ignore_regions {
  notfound("<!-- 1.1.2000 -->");
  found("<!-- 1.1.2000 --> 2.2.2002", "2.2.2002");

  notfound("<span style='display:none'>1.1.2000</span>");
  found("<span style='display:none'>1.1.2000</span> 2.2.2002", "2.2.2002");

  notfound("{{Chartplatzierungen}}1.1.2000</div>");
  found("{{Chartplatzierungen}}1.1.2000</div>2.2.2002", "2.2.2002");

  notfound("{{ChartplatzierungenX}}1.1.2000</div>");
  found("{{ChartplatzierungenX}}1.1.2000</div>2.2.2002", "2.2.2002");

  notfound("<source>1.1.2000</source>");
  found("<source>1.1.2000</source>2.2.2002", "2.2.2002");

  notfound("{{DEFAULTSORT:1.1.2000}}");
  found("{{DEFAULTSORT:1.1.2000}}2.2.2002", "2.2.2002");

  notfound("{{SORTIERUNG:1.1.2000}}");
  found("{{SORTIERUNG:1.1.2000}}2.2.2002", "2.2.2002");

  notfound("{{PND 1.1.2000}}");
  found("{{PND 1.1.2000}}2.2.2002", "2.2.2002");

  notfound("{{DOI 1.1.2000}}");
  found("{{DOI 1.1.2000}}2.2.2002", "2.2.2002");

  notfound("<code> foo 1.1.2000 bar </code>");
  notfound("<syntaxhighlight lang='perl'> foo 1.1.2000 bar </syntaxhighlight>");
}

sub test_namespace {
  my $match = "01.01.2000";
  my $page = MockWikiPage->new($match);
  my @founds;

  $page->{namespace} = "";
  @founds = DK::check($page);
  ok(scalar @founds == 1, "article namespace");

  $page->{namespace} = "WP";
  @founds = DK::check($page);
  ok(scalar @founds == 0, "other namespace");
}

sub test_wikilink {
    notfound("[[Foobar am 1.1.2000]]");
    found("[[Foobar am 1.1.2000]] 2.2.2002", "2.2.2002");
    notfound("[[:en:Foo am 1.1.2000 bar]]");
    notfound("[[Foobar#1.1.2000]]");
    found("[[Foobar am 1.1.2000|foo 2.2.2002]]", "2.2.2002");
    found("[[01. Januar]] [[2000]]", "01. Januar]] [[2000");
}

sub test_url {
  notfound("http://example.com/2000-01-01");
  notfound("https://example.com/2000-01-01");
  found("http://example.com/ 2000-01-01", "2000-01-01");
  found("example.com/2000-01-01", "2000-01-01");
  notfound("[//example.com/2000-01-01");

  secfound("2000-01-01 (http-label)] foobar", "2000-01-01");
  found("2000-01-01 (non-http-label)]] foobar", "2000-01-01");
}

sub test_table {
  notfound("=2000-01-01");
  notfound("= ('2000-01-01')");

  found("| foo 2000-01-01 bar |", "2000-01-01");
  notfound("|2000-01-01");
  notfound("|''2000-01-01");
  notfound("| ('2000-01-01')");
  notfound("2000-01-01|");
  notfound("2000-01-01') |");
  notfound("|<small>1.1.2000");
  notfound('|<small style="color:dimgray;">31.08.2019</small>');
  notfound("1.1.2000</small>|");
  notfound("|<s>So, 15.3.20</s>|");
  notfound("| <kbd>17.06.2007– 19.08.2007</kbd> |");
  notfound("|{{SortKey|2007-06-14}}14.07.2007");
  notfound('|{{0}}24.06.1970');
  found('|{{0AnotherTemplateStartingWith0}}24.06.1970', '24.06.1970');

  notfound("!! 2000-01-01");
  notfound("foo !! 2000-01-01");
  notfound("\n! 2000-01-01");
  found("foo ! 2000-01-01", "2000-01-01");
  notfound("2000-01-01 !!");
  notfound("2000-01-01 \n!");
  found("2000-01-01 !", "2000-01-01");

  notfound("||foo 05.09.2001 – 19:00||");
  notfound("||29 – 05.09.2001 bar||");
  found("||foo 05.09.2001 bar||", "05.09.2001");

  notfound("|  &nbsp; 16.03.97 &nbsp; |");
  notfound("| ZDF: '''17.01.1982''', 19:30 Uhr |");

  found("http://example.com?n=1 1.1.2020 foo", "1.1.2020");
  found("== Überschrift == \n 1.1.90", "1.1.90");
}

sub test_ref {
  secfound("01.01.2000 </ref>", "01.01.2000");
  found("01.01.2000<ref>foobar</ref>", "01.01.2000");

  notfound("<ref name='foo 01.01.2000 bar'>");
  found("<ref name='foobar'>01.01.2000", "01.01.2000");

  notfound("<ref name = 'foo 01.01.2000 bar'>");
  notfound("<ref NAME=\"foo 01.01.2000 bar\">");
  notfound('<ref group="Anm." name="01.01.2000">');

  secfound("{{Zitat|foo<ref>01.01.2000</ref>}}", "01.01.2000");
}

sub test_files_at_end_of_line_or_parameter {
  my @exts = qw(jpeg jpg gif svg png ogg ogv pdf webm tif tiff);

  notfound("2000-01-01.$_|") for @exts;

  found("2002-02-02 foo|2000-01-01.jpg|", "2002-02-02");

  notfound("2000-01-01.jpg\n");
  found("2000-01-01.ext\n", "2000-01-01");
  found("2002-02-02\n2000-01-01.jpg\n", "2002-02-02");

  found("2000-01-01.jpg", "2000-01-01");
}

sub test_software_version {
  my @words = (qw(version kernel linux release versionsnummer), "mac os", "os x");

  for my $word (@words) {
    notfound("$word 2000-01-01");
    notfound("[[$word]]: 2000-01-01");
  }
  found("foobar: 2000-01-01", "2000-01-01");
  notfound("s3c-linux-2.6.21 foo");
}

sub test_chapter {
  my @words = qw(kap. kapitel abs. absatz abschnitt abschnitte paragraph § lemma satz theorem tagesordnungspunkt nr. inventarnummer bauwerks-nr. definition);

  for my $word (@words) {
    notfound(", $word 1.1.99");
  }
  notfound(", KaPITel 1.1.99");
  notfound(", kapitel&nbsp;1.1.99");
  # TODO get rid of \W in regexp

  notfound(" System-Nr. ''01.01.01");
  notfound("in der unbenannten Gruppe ''25.01.04'' zu finden");
}

sub test_notalone {
  found("01-02.01.2000", "02.01.2000");
  notfound("01.01.2000er-Zweig");
  notfound("2000-01-01-rc1");
  notfound("2000-01-01-12");
  notfound("Mo. 01.01. 12:00");
}

sub test_param_detection_styled {
  found('{{foobar|foo 1.1.2000 bar}}', '1.1.2000');
  notfound('{{foobar|*1.1.2000*}}');
  notfound('{{foobar|1.1.2000}}');
  notfound("{{foobar|''1.1.2000''}}");
  notfound("{{foobar|'''1.1.2000'''}}");
  notfound('{{foobar|(1.1.2000)}}');
}

sub test_param_detection_start_end {
  found('{{foobar|foo 1.1.2000 bar}}', '1.1.2000');
  notfound('{{foobar|param=1.1.2000}}');
  notfound('{{foobar|1.1.2000}}');
  notfound('|1.1.2000|');
  notfound('{{foobar|1.1.2000|baz}}');
  notfound('{{foobar|param=1.1.2000|baz}}');
  notfound('{{foobar|baz|1.1.2000}}');
  notfound('{{foobar|foo 1.1.2000|baz}}');
  notfound('{{foobar|foo 1.1.2000}}');
  notfound('{{foobar|1.1.2000 bar}}');
  notfound('{{foobar|baz|1.1.2000 bar}}');
  notfound('|foo 1.1.2000<ref>bar</ref>|');
  notfound('|foo 1.1.2000<ref group="bar" /> |');
}

sub test_param_detection_complex {
  notfound("{{Zitat|foo [[Lemma|Schaf]] 1.1.2000 baz }}");
  notfound("{{Zitat|one={{bar}}|text=foo 1.1.2000 baz }}");
  notfound("{{Zitat|one={{bar|{{baz}}}}|text=foo 1.1.2000 baz }}");
  notfound("{{Zitat|one=<ref>foo</ref>|text=foo 1.1.2000 baz }}");
  notfound("{{Zitat|one=<ref>foo<!-- bar --></ref>|text=foo 1.1.2000 baz }}");
  notfound("{{Zitat|one=<ref>foo<br /></ref>|text=foo 1.1.2000 baz }}");
}

sub test_special_params {
  notfound("{{internetquelle|titel=foo 1.1.2000 bar}}");
  notfound("{{internetquelle|titelerg=foo 1.1.2000 bar}}");
  notfound("{{Internetquelle|zitat= foo 1.1.2000 bar}}");
  found("{{internetquelle|comment=foo 1.1.2000 bar}}", "1.1.2000");
  found("{{internetquelle|foo 1.1.2000 bar}}", "1.1.2000");
  notfound("{{cite web|title=foo 1.1.2000 bar}}");
  notfound("{{literatur|titel=foo 1.1.2000 bar}}");
  notfound("{{literatur|titelerg=foo 1.1.2000 bar}}");
  notfound("{{literatur|originaltitel=foo 1.1.2000 bar}}");
  notfound("{{zitat-de|text=foo 1.1.2000 bar}}");
  notfound("{{zitat|text=foo 1.1.2000 bar}}");
  notfound("{{zitat|text=foo|quelle=foo 1.1.2000 bar}}");
  notfound("{{zitat|foo 1.1.2000 bar}}");
  TODO : {
    local $TODO = "third unnamed parameter";
    notfound("{{zitat|foo 1.1.2000 bar|Max|foo 1.1.2000 bar}}");
  }
  found("{{zitat|foo 1.1.2000 bar|foo 2.2.2002 bar}}", "2.2.2002");
  notfound("{{Inschrift|foo 1.1.2000 bar}}");
  notfound("{{Inschrift|Block=1|Text=foo 1.1.2000 bar}}");
  notfound('{{"|text=foo 1.1.2000 bar}}');
  notfound('{{"|foo 1.1.2000 bar}}');
  notfound('{{"-fr|text=foo 1.1.2000 bar}}');
  notfound('DOI=foo_1.1.2000_bar}');
  found('DOI=foo_1.1.2000_bar}2.2.2002', "2.2.2002");
  notfound('{{Weblink ohne Linktext|Hinweis=Kein Zugriff am 2013-06-09 13:19}}');
  notfound('{{Salzburger Nachrichten|ks250800_25.01.2013_41-44836397}}');
  notfound('{{BAnz|AT 10.03.2014 B3}}');
  notfound('{{Wikisource|Artikel 01.01.2000 foo|Text|lang=de}}');
  found('{{Wikisource|Artikel|Text 01.01.2000 foo|lang=de}}', "01.01.2000");
  notfound('[[doi:10.5072/foo-01.01.2000]]');
  notfound('{{Infobox Fluss| PEGEL1=Pfaffenhofen/14.9/505/1.10/11.02.1932/2.48/4.49/29.0/74.6/14.04.1994
              | QUELLSCHÜTTUNG=.042 / 14.07.2002 / / .187 / / 1.623 / 21.08.2005 / }}');
  notfound('{{Infobox Fluss
              | NAME= Schwarza
              | NACHWEIS-EINZUGSGEBIET= {{GeoQuelle|DE-TH|GKZ}}
              | PEGEL1= Schwarza/5/151/0.17/09.01.1954/0.525/2.35/18.4/46.8/13.04.1994 }}');
  notfound('{{SortKey|!2000-01-01}}');
  notfound("{{Infobox Chemikalie|CAS=foobar viel Text \n * 2000-01-01 <small>Name</small>");
  notfound("{{cite journal|doi=10.5072/foobar/01.01.2000|title=Title 2000-01-01}}");
  notfound("{{doi|10.5072/foo/01.01.2000}}");
  notfound("{{Infobox Burg |Bild = Foo 2013-01-21 42.JPG}}");
  notfound('data-sort-value="1966-01-15"');
  notfound('{{foo|datei=foo 2000-01-01 bar}}');
  notfound('{{Infobox Software|AktuelleVersion=foo 1.1.2000 bar
                              |AktuelleVorabVersion= bar 2.2.2002 bar}}');
  notfound('{{Commonscat|foo 2000-01-01 bar|}}');
  notfound('{{Exzellent|01. August 2018|179607316}}');
  notfound('{{Lesenswert|01. August 2018|179607316}}');
  notfound('{{Informativ|01. August 2018|179607316}}');
  notfound('{{Infobox Rechtsakt (EU)| Fundstelle = ABl. L 309 vom 25.11.2005, S. 9–12 }}');
  notfound('{{lückenhaft|Australien schaltet zum 31.12.2017 ab.}}');
  notfound('{{Lückenhaft|1=Leider ist es noch sehr Lückenhaft, Stand: 03. Dezember 2014 (CET)|2=In diesem Abschnitt}}');
  notfound('{{überarbeiten|grund=in 1.1.18 wird}}');
  notfound('{{belege fehlen|01. August 2018}}');
  notfound('{{LAGIS|ref=nein|DB=OL|ID=15259|titel=Beerfelden, Stadtgemeinde (1.7.1971-31.12.2017), Odenwaldkreis}}');
  notfound('{{Veraltet|<Bezug>|wurde mit 31.3.2016 eingestellt.|seit=2016}}');
  notfound('{{Internetquelle|datum=05. Februar 2015|zugriff=03. April 2017}}');
  notfound('{{Literatur|Zitat=foo 1.1.2000 bar}}');
  notfound('{{OneLegResult|6=Di 24.10.2006, 19:15}}');
  notfound('{{Turnierplan32 | RD1 = Runde 2 - 01.04.2018 <br />best of 11 legs');
  notfound('{{DatumZelle|09. Juli 1946}}');
}

sub test_special {
  notfound("Gemeinden 1994 und ihre Veränderungen seit 01.01.1948 in den neuen Ländern");
  found("Gemeinden FOOBAR und ihre Veränderungen seit 01.01.1948 in FOOBAR", "01.01.1948");

  TODO : {
    local $TODO = "bug: 'and' instead of 'or'";
    found("Gemeinden FOOBAR und ihre Veränderungen seit 01.01.1948 in den neuen Ländern", "01.01.1948");
    found("Gemeinden 1994 und ihre Veränderungen seit 01.01.1948 in FOOBAR", "01.01.1948");
  }

  notfound("Kultusministerium 25.02.2016 Drucksache 6/4829");
  notfound("Staatskanzlei und Ministerium für Kultur 08.03.2019 Drucksache 7/4067");
  notfound("Gebietsänderungen vom 01. Januar bis 31. Dezember 2010");
  found("01. Januar bis 31. Dezember 2010", "01. Januar");
}

sub test_other {
  notfound("1.1.2000 <!-- comment (mostly 'sic!') -->");
  found("1.1.2000 foobar <!-- comment -->", "1.1.2000");
}

#
# Utils
#

sub secfound {
  found(@_, 1);
}

sub found {
  my ($context, $match, $secondary) = @_;
  $match = $match || $context;
  $secondary = $secondary || 0;
  my $page = MockWikiPage->new($context);
  my @founds = DK::check($page);
  my $ok = scalar @founds == 1
	  && $founds[0]->{match} eq $match
	  && $founds[0]->{secondary_flag} eq $secondary;

  my $flag = $secondary ? "2" : "=";
  my $msg="finding '$match' in '$context'";
  $msg .= " as secondary" if $secondary ;

  ok($ok, "$flag $context") or diag("failed $msg \n" . Dumper \@founds);
}

sub notfound {
  my ($match) = @_;
  my $page = MockWikiPage->new($match);
  my @founds = DK::check($page);
  my $ok = scalar @founds == 0;
  ok($ok, "! " . $match) or diag("unexspected match in '$match'\n" . Dumper \@founds);
}

sub run_tests() {
  my $methods = Class::Inspector->methods("main", "expanded");
  for my $method (@$methods) {
    my (undef, undef, $name, $sub) = @$method;
	if ($name =~ /^test_/) {
	  note $name;
	  &$sub();
	}
  }
  done_testing();
}

run_tests();
