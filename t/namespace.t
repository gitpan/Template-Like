use Test::More tests => 2;
use CGI;

BEGIN { use_ok('Template::Like') };

my $q = CGI->new('hoge=foo');
my $params = $q->Vars;
my $t = Template::Like->new( NAMESPACE => { "CGI" => { params => $params } } );
my $input  = "[% CGI.params.hoge %]";
my $result = "foo";
my $output;
$t->process(\$input, {}, \$output);
is($result, $output, $input);
