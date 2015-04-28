# Perl Module - Devel::Module::Trace

Devel::Module::Trace is a perl module which prints a table of all used and
required module with its origin and elapsed time. This helps tear down slow
modules and helps optimizing module usage in general.

This module uses the Time::Hires module for timing and the POSIX module for
the final output which may slightly interfer your results.


## Usage

To get module trace information for the Benchmark module use this oneliner:

```
  perl -MDevel::Module::Trace=print -MBenchmark -e exit
```

## Output

The result is printed to STDERR on exit if using the `print` option. You can get
the raw results at any time with the `Devel::Module::Trace::raw_result` function
and force print the results table any time by the `Devel::Module::Trace::print_pretty`
function.

```
  %> perl -MDevel::Module::Trace=print -MBenchmark -e exit
   -------------------------------------------------------------------------------------------
  | 13:02:25.17689 |  Benchmark.pm        | 0.009065 | -e:0                                   |
  | 13:02:25.17703 |      strict.pm       | 0.000005 | /usr/share/perl/5.18/Benchmark.pm:3    |
  | 13:02:25.17721 |      strict.pm       | 0.000005 | /usr/share/perl/5.18/Benchmark.pm:426  |
  | 13:02:25.17727 |      Carp.pm         | 0.003863 | /usr/share/perl/5.18/Benchmark.pm:432  |
  | 13:02:25.17737 |          5.006       | 0.000019 | /home/sven/perl5/lib/perl5/Carp.pm:3   |
  | 13:02:25.17745 |          strict.pm   | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:4   |
  | 13:02:25.17750 |          warnings.pm | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:5   |
  | 13:02:25.17755 |          strict.pm   | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:8   |
  | 13:02:25.17777 |          strict.pm   | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:18  |
  | 13:02:25.17815 |          strict.pm   | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:67  |
  | 13:02:25.18072 |          strict.pm   | 0.000010 | /home/sven/perl5/lib/perl5/Carp.pm:398 |
  | 13:02:25.18079 |          warnings.pm | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:399 |
  | 13:02:25.18091 |          warnings.pm | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:406 |
  | 13:02:25.18098 |          strict.pm   | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:413 |
  | 13:02:25.18109 |          Exporter.pm | 0.000005 | /home/sven/perl5/lib/perl5/Carp.pm:35  |
  | 13:02:25.18122 |      Exporter.pm     | 0.000004 | /usr/share/perl/5.18/Benchmark.pm:433  |
  | 13:02:25.18145 |      Time/HiRes.pm   | 0.000005 | (eval 2):2                             |
   -------------------------------------------------------------------------------------------
```
