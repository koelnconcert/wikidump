#!/usr/bin/perl
package MockWikiPage;
use strict;

sub new {
  my $class = shift;
  my ($text) = (@_);
  my $self = {};
  bless($self, $class);
  $self->{title} = "Foobar";
  $self->{text} = \$text;
  $self->{namespace} = '';
  return $self;
}

sub title {
  return shift->{namespace};
}

sub namespace {
  return shift->{namespace};
}

sub text {
  return shift->{text};
}

1;
