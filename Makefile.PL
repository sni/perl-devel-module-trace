use inc::Module::Install;

name       'Devel-Module-Trace';
all_from   'lib/Devel/Module/Trace.pm';
author     'Sven Nierlein <nierlein@cpan.org>';
license    'perl';
repository 'http://github.com/sni/perl-devel-module-trace';

requires 'Time::HiRes';

build_requires 'Test::More';

auto_install;

WriteAll;
