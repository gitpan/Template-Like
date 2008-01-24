package Template::Like::Processor;

use Template::Like::Stash;
use Template::Like::Filters;
use Template::Like::VMethods;

use constant TAG_STYLE_SET => {
  template1 => ['[\\[%]%', '%[\\]%]'],
  template  => ['\\[%',   '%\\]'],
  metatext  => ['%%',   '%%'],
  star      => ['\\[\\*',   '\\*\\]'],
  php       => ['<\\?',   '\\?>'],
  asp       => ['<%',   '%>'],
  mason     => ['<%',   '>'],
  html      => ['<!--', '-->']
};

# CHOMP constants for PRE_CHOMP and POST_CHOMP
use constant CHOMP_NONE      => 0; # do not remove whitespace
use constant CHOMP_ALL       => 1; # remove whitespace up to newline
use constant CHOMP_ONE       => 1; # new name for CHOMP_ALL
use constant CHOMP_COLLAPSE  => 2; # collapse whitespace to a single space
use constant CHOMP_GREEDY    => 3; # remove all whitespace including newlines

# code set.
my $codeSet = {
  IF           => 'if ( %s ) {',
  IF_POST      => '}',
  UNLESS       => 'unless ( %s ) {',
  UNLESS_POST  => '}',
  ELSIF        => 'elsif ( %s ) {',
  ELSIF_POST   => '}',
  ELSE         => 'else {',
  ELSE_POST    => '}',
  END          => '%s',
  FILTER       => '{ my $filterOffset = length $output;',
  FILTER_POST  => 'substr($output, $filterOffset) = $self->filter(%s, substr($output, $filterOffset)); };',
  DUMMY        => "\$output.= %s;\n=pod",
  DUMMY_POST   => "\n=cut\n",
  INSERT       => '$output.= $self->insert(%s);',
  INCLUDE      => '$output.= $self->include(%s);',
  PROCESS      => '$output.= $self->process(%s);',
  GET          => '$output.= %s;',
  SET          => '%s;',
  USE          => '$self->plugin_use(\'%s\', %s);',
  CALL         => '%s;',
  PRE_SPACE    => '$output.= "%s" unless $self->PRE_CHOMP;',
  POST_SPACE   => '$output.= "%s" unless $self->POST_CHOMP;',
  FOREACH      => 'for ( to_array( %s ) ) {
  local $stash->{\'%s\'} = $_;',
  FOREACH_POST => '}',
  WHILE        => '{
  my $wc = 0;
  while ( %s ) {
    die "while " . $self->WHILE_LIMIT . " over."
      if $self->WHILE_LIMIT && $self->WHILE_LIMIT < ++$wc;',
  WHILE_POST   => "} }",
  TEXT         => '$output.= \'%s\';'
};

#=====================================================================
# new
#---------------------------------------------------------------------
# - API
# $processor = Template::Like::Processor->new( $init_option, $params, $option );
#---------------------------------------------------------------------
# - args
# $init_option ... 
# $params      ... PARAMS ( HASHREF )
# $option      ... 
#---------------------------------------------------------------------
# - returns
# $processor ... Template::Like::Processor Object.
#---------------------------------------------------------------------
# - Example
# $processor = Template::Like::Processor->new( $init_option, $params, $option );
#=====================================================================
sub new {
  my $class = shift;
  my $init_option = shift;
  my $params = shift;
  my $option = shift;
  
  my $self = bless {
    OPTION => {
      INCLUDE_PATH       => [],
      OUTPUT_PATH        => undef,
      ABSOLUTE           => undef,
      RELATIVE           => undef,
      TAG_STYLE          => 'template',
      START_TAG          => undef,
      END_TAG            => undef,
      FILTERS            => {},
      LOAD_FILTERS       => [],
      NAMESPACE          => {},
      CONSTANTS          => undef,
      CONSTANT_NAMESPACE => 'constants',
      STASH              => undef,
      DEBUG              => undef,
      PLUGIN_BASE        => [],
      PRE_CHOMP          => undef,
      POST_CHOMP         => undef,
      WHILE_LIMIT        => 1000
    }
  }, $class;
  
  # ---------- marge option ------------------------------------------
  
  @{ $self->{'OPTION'} }{ keys %{ $init_option } } = values %{ $init_option };
  
  @{ $self->{'OPTION'} }{ keys %{ $option } } = values %{ $option };
  
  for my $key ( ('INCLUDE_PATH', 'LOAD_FILTERS', 'PLUGIN_BASE') ) {
    unless ( UNIVERSAL::isa($self->{'OPTION'}->{ $key }, 'ARRAY') ) {
      $self->{'OPTION'}->{ $key } = [ $self->{'OPTION'}->{ $key } ];
    }
  }
  
  push @{ $self->{'OPTION'}->{'INCLUDE_PATH'} }, File::Spec->curdir();
  
  push @{ $self->{'OPTION'}->{'LOAD_FILTERS'} }, Template::Like::Filters->new;
  
  push @{ $self->{'OPTION'}->{'PLUGIN_BASE'} }, 'Template::Like::Plugin';
  
  if ( not UNIVERSAL::isa($self->{'OPTION'}->{'STASH'}, 'Template::Like::Stash') ) {
    $self->{'OPTION'}->{'STASH'} = Template::Like::Stash->new;
  }
  
  if ( not $self->START_TAG ) {
    $self->{'OPTION'}->{'START_TAG'} = TAG_STYLE_SET->{ $self->TAG_STYLE }->[0];
  }
  
  if ( not $self->END_TAG ) {
    $self->{'OPTION'}->{'END_TAG'} = TAG_STYLE_SET->{ $self->TAG_STYLE }->[1];
  }
  
  # ---------- init stash --------------------------------------------
  
  $self->{'STASH'} = $self->{'OPTION'}->{'STASH'};
  
  $self->stash->update( $params );
  
  $self->stash->update( $self->NAMESPACE );
  
  $self->stash->set( $self->CONSTANT_NAMESPACE, $self->CONSTANTS );
  
  return $self;
}



#=====================================================================
# clone
#---------------------------------------------------------------------
# - API
# $processor = $processor->clone;
#---------------------------------------------------------------------
# - args
# none
#---------------------------------------------------------------------
# - returns
# $processor ... this clone object.
#---------------------------------------------------------------------
# - Example
# use lexical stash.
# $processor->clone->process($input);
#=====================================================================
sub clone {
  my $self = shift;
  
  my $clone = bless { %{ $self } }, 'Template::Like::Processor';
  
  $clone->{'STASH'} = $self->stash->clone;
  
  return $clone;
}



#=====================================================================
# process
#---------------------------------------------------------------------
# - API
# $buffer = $processor->process( $input );
#---------------------------------------------------------------------
# - args
# $input ... 
#---------------------------------------------------------------------
# - returns
# $buffer ... String.
#---------------------------------------------------------------------
# - Example
# $buffer = $processor->process( $input );
#=====================================================================
sub process {
  my $self  = shift;
  
  return $self->execute( $self->compile( $self->load( @_ ) ) );
}



#=====================================================================
# load
#---------------------------------------------------------------------
# - API
# $text_ref = $processor->load( $input );
#---------------------------------------------------------------------
# - args
# $input ... 
#---------------------------------------------------------------------
# - returns
# $text_ref ... Template Text.
#---------------------------------------------------------------------
# - Example
# $text_ref = $processor->load( $input );
#=====================================================================
sub load {
  my $self = shift;
  my $data = shift;
  
  # data is filename
  if ( !ref $data ) {
    
    my $filename = $data;
    
    $filename=~s|/{2,}|/|g;
    
    if ( not $self->RELATIVE ) {
      if ( $filename=~/(?:^|\/)\.+\// ) {
        die "[$filename]: relative paths are not allowed (set RELATIVE option) ";
      }
    }
    
    if ( not $self->ABSOLUTE ) {
      if ( File::Spec->file_name_is_absolute($filename) ) {
        die "[$filename]: absolute paths are not allowed (set ABSOLUTE option)";
      }
    }
    
    my $filepath;
    
    if ( File::Spec->file_name_is_absolute($filename) ) {
      $filepath = $filename if -f $filename;
    } else {
      for my $dir ( $self->INCLUDE_PATH ) {
        if (-f File::Spec->catfile( $dir, $filename )) {
          $filepath = File::Spec->catfile( $dir, $filename );
          last;
        }
      }
    }
    
    die "file not found. filename is [$filename] include_path is ["
      . join(',', $self->INCLUDE_PATH)
      . "]" if not $filepath;
    
    die "file open endless loop [$filepath]" if ( exists $self->{'OPEND'}->{ $filepath } && $self->{'OPEND'}->{ $filepath } > 10 );
    
    $self->{'OPEND'}->{ $filepath }++;
    
    my $fh = IO::File->new($filepath) or die "file open failure [$filepath]";
    
    my $input = join '', <$fh>;
    $fh->close;
    return \$input;
  }
  
  elsif ( UNIVERSAL::isa($data, "SCALAR") ) {
    return \do{ my $str = $$data };
  }
  
  elsif ( UNIVERSAL::isa($data, "ARRAY") ) {
    return \do{ my $str = join '', @{$data} };
  }
  
  elsif ( UNIVERSAL::isa($data, "GLOB") ) {
    return \do{ my $str = join '', <$data> };
  }
}



#=====================================================================
# compile
#---------------------------------------------------------------------
# - API
# $code = $processor->compile( $text_ref );
#---------------------------------------------------------------------
# - args
# $text_ref ... Template Text Reference.
#---------------------------------------------------------------------
# - returns
# $code ... Perl code.
#---------------------------------------------------------------------
# - Example
# $code = $processor->compile( $text_ref );
#=====================================================================
sub compile {
  my $self = shift;
  my $text_ref = shift;
  
  my $start = $self->START_TAG;
  my $end   = $self->END_TAG;
  
  my @endTask;
  my $code = '';
  
  my $appendSet = sub {
    my $directive = shift;
    my $directive_post = $directive . '_POST';
    my $format = $codeSet->{ $directive };
    $code.= '  ' x scalar( @endTask );
    $code.= sprintf $format, @_;
    $code.= "\n";
    
    if ( exists $codeSet->{ $directive_post } ) {
      push @endTask, sprintf($codeSet->{ $directive_post }, @_);
    }
  };
  
  my $escapeQuote = sub {
    my $str = shift;
    $str=~s/\'/\\\'/g;
    return $str;
  };
  
  while ( $$text_ref=~ s/^(.*?)(?:$start([-=~+]?)(.*?)([-=~+]?)$end)//sx ) {
    
    my ($text, $pre_chomp, $ele, $post_chomp) = ($1, $2, $3, $4);
    
    $text = '' unless defined $text;
    $ele  = '' unless defined $ele;
    $pre_chomp ||= $self->PRE_CHOMP || 0;
    $post_chomp ||= $self->POST_CHOMP || 0;
    $pre_chomp =~ tr/-=~+/1230/;
    $post_chomp =~ tr/-=~+/1230/;
    
    if ($pre_chomp == CHOMP_ALL) { 
        $text =~ s{ (\n|^) [^\S\n]* \z }{}mx;
    } elsif ($pre_chomp == CHOMP_COLLAPSE) { 
        $text =~ s{ (\s+) \z }{ }x;
    } elsif ($pre_chomp == CHOMP_GREEDY) { 
        $text =~ s{ (\s+) \z }{}x;
    }
    
    if ($post_chomp == CHOMP_ALL) { 
      $$text_ref =~ s{ ^ ([^\S\n]* \n) }{}x;
    } elsif ($post_chomp == CHOMP_COLLAPSE) { 
      $$text_ref =~ s{ ^ (\s+) }{ }x;
    } elsif ($post_chomp == CHOMP_GREEDY) { 
      $$text_ref =~ s{ ^ (\s+) }{}x;
    }
    
    $appendSet->( 'TEXT', $escapeQuote->($text) ) if length $text;
    
    
    $ele=~s/^\s+//;
    $ele=~s/\s+$//;
    
    if ( length $ele ) {
      
      if ( $ele=~/^(CALL|GET|SET|IF|UNLESS|ELSIF|FILTER|INSERT|INCLUDE|DUMMY|PRE_SPACE|POST_SPACE)\s+(\S.*)$/sx ) {
        my $directive = $1;
        my $expression = $2;
        my $code = $self->expansion( $expression, $directive );
        
        $appendSet->( $directive, $code );
      }
      
      # USE
      elsif ( $ele=~/^USE\s+(\S.*)$/sx ) {
        
        my $directive = 'USE';
        my $text = $1;
        my $code = '';
        my $key  = '';
        
        # SET時のKEY指定有り
        if ( $text=~/^(\w+)\s*=\s*(.+)$/ ) {
          $key  = $1.'=';
          $text = $2;
        }
        
        # ARGUMENTS有り
        if ( $text=~/^([a-zA-Z0-9\.]+)\s*(\(.+\))/ ) {
          $text = $1;
          $code = $self->expansion( $2, 'GET' );
        }
        
        $appendSet->( $directive, $key.$text, $code );
      }
      
      # ELSE
      elsif ( $ele eq 'ELSE' ) {
        
        $appendSet->( 'END', ( pop @endTask ) );
        $appendSet->( $ele );
      }
      
      # END
      elsif ( $ele eq 'END' ) {
        $appendSet->( $ele, ( pop @endTask ) );
      }
      
      # FOREACH
      elsif ( $ele=~/^FOREACH\s*(\w+)\s*(?:\=|IN)\s*(\S.*)\s*$/sx ) {
        $appendSet->( 'FOREACH', $self->expansion( $2, 'FOREACH' ), $1 );
      }
      
      # WHILE (?:(\w+)\s*\=\s*)?
      elsif ( $ele=~/^WHILE\s*(.*)\s*$/sx ) {
        $appendSet->( 'WHILE', $self->expansion( $1, 'WHILE' ) );
      }
      
      # OTHER
      else {
        $appendSet->( $self->expansion( $ele, 'GET', { get_directive => 1 } ) );
      }
    }
  }
  
  $appendSet->( 'TEXT', $escapeQuote->($$text_ref) ) if length $$text_ref;
  
  return "{\n$code}\n";
}

# The contents, possibly including any embedded template directives, are inserted intact.
sub insert {
  ${ shift->load(@_) };
}

# 
sub include {
  shift->clone->process(@_);
}

sub plugin_use {
  my $self = shift;
  my $key  = shift;
  my $plugin_name = $key;
  
  if ($key=~/(.*)=(.*)/){
    $key = $1;
    $plugin_name = $2;
  }
  
  for my $base ( $self->PLUGIN_BASE ) {
    
    my $plugin_class = $base.'::'.$plugin_name;
    
    # check class
    unless (UNIVERSAL::can($plugin_class, 'can')) {
      
      # load class
      eval "use $plugin_class;";
    }
    
    unless ($@) {
      
      # set instance
      $self->stash->set( $key, $plugin_class->new($self, @_) );
      return ;
    }
  }
  
  die $@;
}

#-----------------------------
# expansion
#-----------------------------
sub expansion {
  my $self       = shift;
  my $expression = shift;
  my $directive  = shift;
  my $option     = shift;
  
  if ( $directive =~/^(FILTER|INSERT|INCLUDE)$/ ) {
    if ( $expression!~/^\$/ ) {
      $expression=~s/\'/\\\'/g;
      return "'$expression'";
    }
  }
  
  my $token;
  my $code = '';
  my $codeOffset = 0;
  
  my $autoSemiColon = sub { if ($code=~s/([\)\"\'\d])(\s*)$/$1;$2/) { $codeOffset = length $code; } };
  
  while ($expression =~
    /
      # strip out any comments
      (\#[^\n]*)
     |
      # a quoted phrase matches in $3
      (["'])                       # $2 - opening quote, ' or "
      (                            # $3 - quoted text buffer
        (?:                        # repeat group (no backreference)
          \\\\                     # an escaped backslash \\
        | \\\2                     # an escaped quote \" or \' (match $1)
        | .                        # any other character
        | \n                       # \n
        )*?                        # non-greedy repeat
      )                            # end of $3
      \2                           # match opening quote
      |
        # an unquoted number matches in $4
        (-?\d+(?:\.\d+)?)          # numbers
      |
        # filename matches in $5
        ((?=.*\/)(?!.*\/$)(?:\S+))
      |
        # an identifier matches in $6
        \s*\|\s*([\w]+)\(          # variable identifier
      |
        # an identifier matches in $7
        \s*\|\s*([\w]+)            # variable identifier
      |
        # an identifier matches in $8
        ((?!\_)[\$\.]?\w+)\(       # variable identifier
      |
        # an identifier matches in $9
        ((?!\_)[\$\.]?\w+)\s*\=\s+ # variable identifier
      |
        # an identifier matches in $10
        ((?!\_)[\$\.]?\w+)         # variable identifier
      |
        # an unquoted word or symbol matches in $11
        (   [(){}\[\]:;,\/\\]      # misc parenthesis and symbols
        |   [+\-*]                 # math operations
        |   \$\{?                  # dollar with option left brace
        |   !=                     # like 'ne'
        |   ==                     # like 'eq'
        |   =>                     # like '='
        |   [=!<>]?= | [!<>]       # equality tests
        |   &&? | \|\|?            # boolean ops
        |   \.\.?                  # n..n sequence
        |   \S+                    # something unquoted
        |   \s+                    # something unquoted
        )                          # end of $10
    /gmxo) {
    
    if (defined ($token = $3)) {
      $code.= $2 . $token . $2;
    }
    
    elsif (defined ($token = $4)) {
      $code.= $token;
    }
    
    elsif (defined ($token = $5)) {
      $token=~s/\'/\\\'/g;
      $code.= "'$token'";
    }
    
    elsif (defined ($token = $6)) {
      $code = sprintf q{$self->filter('%s', %s, }, $token, $code;
    }
    
    elsif (defined ($token = $7)) {
      $code = sprintf q{$self->filter('%s', %s)}, $token, $code;
    }
    
    elsif (defined ($token = $8)) {
      
      # method after dot.
      if ( $token=~/^\./ && $code=~/\)$/ ) {
        $token = substr($token, 1);
        substr($code, $codeOffset) = 
          '$stash->next(' . substr($code, $codeOffset) . ", '$token', ";
      }
      
      # first dollar.
      elsif ( $token=~/^\$(.*)$/ ) {
        $autoSemiColon->();
        $code.= "\$stash->get('$1', ";
      }
      
      # first dot.
      elsif ( $token=~/^\.(.*)$/ ) {
        substr($code, $codeOffset) =
          '$stash->next(' . substr($code, $codeOffset) . ", '$1', ";
      }

      # directive which can omit the dollar.
      else {
        $autoSemiColon->();
        $code.= "\$stash->get('$token', ";
      }
    }
    
    elsif (defined ($token = $9)) {
      
      $directive = 'SET';
      
      # method after dot.
      if ( $token=~/^\./ && $code=~/\)$/ ) {
        $token = substr($token, 1);
        $code.= "->{'$token'} =";
        $codeOffset = length $code;
      }
      
      # first dollar.
      elsif ( $token=~/^\$(.*)$/ ) {
        $autoSemiColon->();
        $code.= "\$stash->{'$1'} =";
        $codeOffset = length $code;
      }
      
      # first dot.
      elsif ( $token=~/^\.(.*)$/ ) {
        $code.= "->{'$1'} =";
        $codeOffset = length $code;
      }
      
      else {
        $autoSemiColon->();
        $code.= "\$stash->{'$token'} =";
        $codeOffset = length $code;
      }
    }
    
    elsif (defined ($token = $10)) {
      
      # method after dot.
      if ( $token=~/^\./ && $code=~/\)$/ ) {
        $token = substr($token, 1);
        substr($code, $codeOffset) =
          '$stash->next(' . substr($code, $codeOffset) . ", '$token')";
      }
      
      # first dollar.
      elsif ( $token=~/^\$(.*)$/ ) {
        $autoSemiColon->();
        $code.= "\$stash->get('$1')";
      }
      
      # first dot.
      elsif ( $token=~/^\.(.*)$/ ) {
        substr($code, $codeOffset) =
          '$stash->next(' . substr($code, $codeOffset) . ", '$1')";
      }
      
      else {
        $autoSemiColon->();
        $code.= "\$stash->get('$token')";
      }
    }
    
    elsif (defined ($token = $11)) {
      if ( $token eq '==' ) {
        $code.= ' eq ';
      } elsif ( $token eq '!=' ) {
        $code.= ' ne ';
      } elsif ( $token eq '_' ) {
        $code.= '.';
      } else {
        $code.= $token;
      }
    }
    
#    warn $token if $self->DEBUG;
  }
  
  
  return ( $directive, $code ) if $option->{'get_directive'};
  return $code;
}



#=====================================================================
# filter
#---------------------------------------------------------------------
# - API
# $buffer = $processor->filter( $name, $buffer, @ARGS... );
#---------------------------------------------------------------------
# - args
# $name ... Filter Name.
#---------------------------------------------------------------------
# - returns
# $buffer ... buffer.
#---------------------------------------------------------------------
# - Example
# $buffer = $processor->filter( $name );
#=====================================================================
sub filter {
  my $self = shift;
  my $name = shift;
  
  if ( exists $self->FILTERS->{ $name } ) {
    return $self->FILTERS->{ $name }->( @_ );
  }
  
  for my $filter ( $self->LOAD_FILTERS ) {
    if ( UNIVERSAL::can($filter, $name) ) {
      return $filter->$name( @_ );
    }
  }
  
  die "not defined filter [$name].";
}



#=====================================================================
# execute
#---------------------------------------------------------------------
# - API
# $buffer = $processor->execute( $code );
#---------------------------------------------------------------------
# - args
# $code ... Perl code.
#---------------------------------------------------------------------
# - returns
# $buffer ... buffer.
#---------------------------------------------------------------------
# - Example
# $buffer = $processor->execute( $code );
#=====================================================================
sub execute {
  my $self = shift;
  my $code = shift;
  
  my $output = '';
  my $stash = $self->stash;
  
  warn $code if $self->DEBUG;
  
  eval $code;
  die $@ if $@;
  
  return $output;
}

#=====================================================================
# filalize
#---------------------------------------------------------------------
# - API
# $processor->finalize( $buffer, $output );
#---------------------------------------------------------------------
# - args
# $buffer ... Perl code.
# $output ... Perl code.
#---------------------------------------------------------------------
# - returns
# none.
#---------------------------------------------------------------------
# - Example
# $processor->finalize( $buffer, $output );
#=====================================================================
sub finalize {
  my $self   = shift;
  my $buffer = shift;
  my $output = shift;
  
  if ( ref $output ) {
    
    if ( UNIVERSAL::isa($output, 'SCALAR') ) {
      ${ $output }.= $buffer;
    }
    
    elsif ( UNIVERSAL::isa($output, 'ARRAY') ) {
      push @{ $output }, $buffer;
    }
    
    elsif ( UNIVERSAL::isa($output, 'CODE') ) {
      $output->($buffer);
    }
    
    # filehandle
    elsif ( UNIVERSAL::isa($output, 'GLOB') ) {
      print $output $buffer;
    }
    
    # Apache::Request, Apache2::Request ...
    elsif ( UNIVERSAL::can($output, 'print') ) {
      $output->print($buffer);
    }
    
    else {
      die "no support output [$output]";
    }
  }
  
  # filename
  else {
    
    my $path =   $self->OUTPUT_PATH
               ? File::Spec->catfile( $self->OUTPUT_PATH, $output )
               : $output;
    
    my $mark = -f $path ? '+<' : '>';
    my $fh = new IO::File $mark.$path
      or $self->error("output file open failure [".$path."]");
    
    seek $fh, 0, 0;
    print $fh $buffer;
    truncate $fh, tell($fh);
    close $fh;
  }
}

sub to_array {
  return @{ $_[0] } if @_ == 1 && UNIVERSAL::isa($_[0], 'ARRAY');
  return @_;
}


#-----------------------------
# Accessors
#-----------------------------
sub stash  { $_[0]->{'STASH'};         }
sub error  { die @_; };

sub DEBUG              { $_[0]->{'OPTION'}->{'DEBUG'}              }
sub OUTPUT_PATH        { $_[0]->{'OPTION'}->{'OUTPUT_PATH'}        }
sub ABSOLUTE           { $_[0]->{'OPTION'}->{'ABSOLUTE'}           }
sub RELATIVE           { $_[0]->{'OPTION'}->{'RELATIVE'}           }
sub TAG_STYLE          { $_[0]->{'OPTION'}->{'TAG_STYLE'}          }
sub START_TAG          { $_[0]->{'OPTION'}->{'START_TAG'}          }
sub END_TAG            { $_[0]->{'OPTION'}->{'END_TAG'}            }
sub FILTERS            { $_[0]->{'OPTION'}->{'FILTERS'}            }
sub NAMESPACE          { $_[0]->{'OPTION'}->{'NAMESPACE'}          }
sub CONSTANTS          { $_[0]->{'OPTION'}->{'CONSTANTS'}          }
sub CONSTANT_NAMESPACE { $_[0]->{'OPTION'}->{'CONSTANT_NAMESPACE'} }
sub INCLUDE_PATH       { @{ $_[0]->{'OPTION'}->{'INCLUDE_PATH'} }  }
sub LOAD_FILTERS       { @{ $_[0]->{'OPTION'}->{'LOAD_FILTERS'} }  }
sub PLUGIN_BASE        { @{ $_[0]->{'OPTION'}->{'PLUGIN_BASE'} }   }
sub PRE_CHOMP          { $_[0]->{'OPTION'}->{'PRE_CHOMP'}          }
sub POST_CHOMP         { $_[0]->{'OPTION'}->{'POST_CHOMP'}         }
sub WHILE_LIMIT        { $_[0]->{'OPTION'}->{'WHILE_LIMIT'}        }

1;