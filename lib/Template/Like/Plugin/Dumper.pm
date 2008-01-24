package Template::Like::Plugin::Dumper;

use strict;
use Data::Dumper;

my @DUMPER_ARGS = qw/
  Indent
  Pad
  Varname
  Purity
  Useqq
  Terse
  Freezer
  Toaster
  Deepcopy
  Quotekeys
  Bless
  Maxdepth
/;

#=====================================================================
# new
#---------------------------------------------------------------------
# - API
# <% USE Dumper %>
# <% Dumper.dump(variable) %>
#---------------------------------------------------------------------
# - args
# $params    ... PARAMS ( HASHREF )
#---------------------------------------------------------------------
# - returns
# Template::Like::Plugin::Dumper Object.
#---------------------------------------------------------------------
# - Example
# <% USE Dumper %>
# <% Dumper.dump(variable) %>
#=====================================================================
sub new {
  my $class   = shift;
  my $context = shift;
  my $params  =     ref $_[0] ? $_[0] : 
                defined $_[0] ? {@_}  : undef;
  
  if (defined $params) {
    no strict 'refs';
    my $val;
    for my $arg (@DUMPER_ARGS) {
      if (defined ($val = $params->{ lc $arg }) or defined ($val = $params->{ $arg })) {
        ${"Data\::Dumper\::$arg"} = $val;
      }
    }
  }
  
  return bless { _CONTEXT => $context, params => $params }, $class;
}



#=====================================================================
# dump
#---------------------------------------------------------------------
# - API
# 
#---------------------------------------------------------------------
# - args
# 
#---------------------------------------------------------------------
# - returns
# 
#---------------------------------------------------------------------
# - Example
# <% Dumper.dump(variable) %>
#=====================================================================
sub dump {
  my $self = shift;
  
  return Dumper @_;
}

#=====================================================================
# dump_html
#---------------------------------------------------------------------
# - API
# 
#---------------------------------------------------------------------
# - args
# 
#---------------------------------------------------------------------
# - returns
# 
#---------------------------------------------------------------------
# - Example
# <% Dumper.dump_html(variable) %>
#=====================================================================
sub dump_html {
  my $self = shift;
  
  my $data = $self->dump(@_);
  
  return $self->{'_CONTEXT'}->filter('html_line_break',
    $self->{'_CONTEXT'}->filter('html', $data)
  );
}

1;