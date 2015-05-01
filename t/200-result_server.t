use warnings;
use strict;
use Test::More tests => 8;
use File::Temp qw/tempfile/;

my($fh, $testfile) = tempfile();
my $cmd1 = $^X.' -d:Module::Trace=save='.$testfile.' -MBenchmark -MCarp -e exit 2>&1';
ok(1, $cmd1);
my $result = `$cmd1`;
is($?, 0, "return code");
like($result, "/modules written to ".$testfile."/", 'wrote test file');
ok(-s $testfile, "test file has content");

my $cmd2 = $^X.' script/devel_module_trace_result_server '.$testfile.' cgi 2>&1';
ok(1, $cmd2);
$result = `$cmd2`;
is($?, 0, "return code");
like($result, '/"Carp.pm"/', 'found Carp.pm');
like($result, '/"Benchmark.pm"/', 'found Benchmark.pm');
unlink($testfile);

