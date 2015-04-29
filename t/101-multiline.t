#!/usr/bin/env perl

use warnings;
use strict;
use Test::More tests => 2;

my $cmd    = "$^X -d:Module::Trace=print t/data/multiline_use.pl 2>&1";
ok(1, $cmd);
my $result = `$cmd`;
like($result, '/\s+Carp.pm\s+/', 'found Carp.pm');
