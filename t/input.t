use Test::More tests => 12;

BEGIN { use_ok('Template::Like') };

mkdir 'tmpl';

my $t = Template::Like->new;

my $input_grob;
my $input_filename = "tmpl/test001.html";
my $input_scalarref = q{<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=EUC-JP">
<link rel="stylesheet" href="default.css">
<title>TITLE</title>
</head>
<body>
<p>[% group %]</p>
</body>
</html>};

open TMPL, '>tmpl/test001.html';
print TMPL $input_scalarref;
close TMPL;

open TMPL, '>/tmp/test001.html';
print TMPL $input_scalarref;
close TMPL;

my $result = q{<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01//EN">
<html>
<head>
<meta http-equiv="Content-Type" content="text/html; charset=EUC-JP">
<link rel="stylesheet" href="default.css">
<title>TITLE</title>
</head>
<body>
<p>hoge foo bar</p>
</body>
</html>};

my $output1;
my $output2;
my $output3;
my $output4;
my $output5;
my $output6;
my $output7;
my $output8;
my $output9;
my $output0;

$t->process($input_filename, { group => "hoge foo bar" }, \$output1);
open $input_grob, $input_filename;
$t->process($input_grob, { group => "hoge foo bar" }, \$output2);
close $input_grob;
$t->process(\$input_scalarref, { group => "hoge foo bar" }, \$output3);

{
  my $t =  Template::Like->new({ INCLUDE_PATH => "tmpl" });
  $t->process("test001.html", { group => "hoge foo bar" }, \$output4);
}

{
  my $t =  Template::Like->new({ INCLUDE_PATH => "tmpl/" });
  $t->process("test001.html", { group => "hoge foo bar" }, \$output5);
}

{
  my $t =  Template::Like->new({ INCLUDE_PATH => ['lib/', 'tmpl'] });
  $t->process("test001.html", { group => "hoge foo bar" }, \$output6);
}

$t = Template::Like->new({ INCLUDE_PATH => ["tmpl", 'lib/'] });
$t2 = Template::Like->new({ INCLUDE_PATH => ["tmpl", 'lib/'], RELATIVE => 1 });
$t3 = Template::Like->new({ INCLUDE_PATH => ["tmpl", 'lib/'], ABSOLUTE => 1 });
$t->process("test001.html", { group => "hoge foo bar" }, \$output7);
#my @include_path = $t->include_path;

is($result, $output1, "filename");
is($result, $output2, "filehandle");
is($result, $output3, "scalarref");
is($result, $output4, "include_path_is_scalar");
is($result, $output5, "include_path_is_arrayref");
is($result, $output6, "include_path_is_arrayref");
is($result, $output7, "include_path_new_option");
##is("tmpl:lib/", join(':', @include_path), "include_path_new_option");
#
eval {$t->process("../test001.html", {}, \$output7);};
if ($@) { pass("relative security"); } else { fail("relative security"); }

eval {$t2->process("../tmpl/test001.html", {}, \$output7);};
if ($@) { fail("relative security"); } else { pass("relative security"); }

$t3->process("///tmp/test001.html", { group => "hoge foo bar" }, \$output8);
is($result, $output8, "slash");

$t->process("tmpl/////test001.html", { group => "hoge foo bar" }, \$output9);
is($result, $output9, "slash");


unlink <tmpl/*>;
rmdir 'tmpl';

