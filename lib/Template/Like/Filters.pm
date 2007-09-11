package Template::Like::Filters;

use strict;

sub new { bless {}, $_[0]; }

sub format {
  my ( $self, $text, $format ) = @_;
  
  if ( $text=~/\x0D|\x0A/ ) {
    $text=~s/((?:(?!\x0D|\x0A).)+)/sprintf($format, $1)/eg;
    return $text;
  } else {
    return sprintf $format, $text;
  }
}

sub html {
  my ( $self, $text ) = @_;
  return undef unless defined $text;
  $text =~ s{&}{&amp;}gso;
  $text =~ s{<}{&lt;}gso;
  $text =~ s{>}{&gt;}gso;
  $text =~ s{"}{&quot;}gso;
  return $text;
}

sub html_line_break {
  my ( $self, $text ) = @_;
  return undef unless defined $text;
  $text =~s/(\x0D\x0A|\x0A)/<br \/>$1/g;
  return $text;
}

sub uri {
  my ( $self, $text ) = @_;
  $text =~ s/(\W)/'%' . unpack('H2', $1)/eg;
  return $text;
}

sub truncate {
  my ( $self, $text, $length ) = @_;
  return undef if $length=~/\D/;
  return $text if length($text) <= $length;
  return substr($text, 0, $length) if $length < 4;
  return substr($text, 0, ($length - 3)) . '...';
}

sub repeat {
  my ( $self, $text, $iterations ) = @_;
  return undef if $iterations=~/\D/ || $iterations < 1;
  return $text x $iterations;
}

sub remove {
  my ( $self, $text, $string ) = @_;
  $text=~s/$string//g;
  return $text;
}

sub replace {
  my ( $self, $text, $search, $replace ) = @_;
  $text=~s/$search/$replace/g;
  return $text;
}

1;
