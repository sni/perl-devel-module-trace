#!/usr/bin/env perl

use warnings;
use strict;
use Test::More tests => 5;

my $cmd    = "$^X -d:Module::Trace=print t/data/multiline_use.pl 2>&1";
ok(1, $cmd);
my $result = `$cmd`;
is($?, 0, "return code");
like($result, '/\s+Carp.pm\s+/', 'found Carp.pm');
like($result, '/\s+Benchmark.pm\s+/', 'found Benchmark.pm');
like($result, '/\s+Exporter.pm\s+/', 'found Exporter.pm');
