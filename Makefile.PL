use inc::Module::Install;

perl_version '5.008';
name         'Devel-Module-Trace';
all_from     'lib/Devel/Module/Trace.pm';
author       'Sven Nierlein <nierlein@cpan.org>';
license      'perl';
repository   'http://github.com/sni/perl-devel-module-trace';

requires 'POSIX';
requires 'Time::HiRes';
requires 'Devel::OverrideGlobalRequire';
requires 'Mojolicious::Lite';
requires 'Template';
requires 'JSON::XS';

build_requires 'Test::More';

WriteAll;
