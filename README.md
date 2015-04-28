# Perl Module - Devel::Module::Trace

Devel::Module::Trace is a perl module which prints a table of all used and
required module with its origin and elapsed time. This helps tear down slow
modules and helps optimizing module usage in general.

This module uses the Time::Hires module for timing and the POSIX module for
the final output which may slightly interfer your results.

## Usage

```
  perl -MDevel::Module::Trace[=<option1>,<option2>,...] -M<module> -e exit
```

## Options

Options are supplied as command line options to the module itself. Multiple options can be separated by comma.

```
  perl -MDevel::Module::Trace=<option1>,<option2>,... -M<module> -e exit
```

### print

Make the module print the results at exit.

```
  perl -MDevel::Module::Trace=print -MBenchmark -e exit
```

### filter

Output filter are defined by the filter option. Multiple filter can be used as comma separated list.
The generic `perl` filter hides requires like `use 5.008`.

```
  %> perl -MDevel::Module::Trace="filter=strict.pm,filter=warnings.pm,filter=perl" -MBenchmark -e exit
```

## Output

The result is printed to STDERR on exit if using the `print` option. You can get
the raw results at any time with the `Devel::Module::Trace::raw_result` function
and force print the results table any time by the `Devel::Module::Trace::print_pretty`
function.

```
  %> perl -MDevel::Module::Trace="print,filter=strict.pm,filter=warnings.pm,filter=perl" -MBenchmark -e exit
   ------------------------------------------------------------------------------------------------
  | 14:11:05.40767 |  Benchmark.pm             | 0.026743 | -e:0                                   |
  | 14:11:05.40806 |      Carp.pm              | 0.009195 | /usr/share/perl/5.18/Benchmark.pm:432  |
  | 14:11:05.41720 |          Exporter.pm      | 0.000004 | /home/sven/perl5/lib/perl5/Carp.pm:35  |
  | 14:11:05.41735 |      Exporter.pm          | 0.000004 | /usr/share/perl/5.18/Benchmark.pm:433  |
  | 14:11:05.41759 |      Time/HiRes.pm        | 0.000005 | (eval 2):2                             |
  | 14:11:05.43501 |  Fcntl.pm                 | 0.001754 | /usr/lib/perl/5.18/POSIX.pm:17         |
  | 14:11:05.43548 |      Exporter.pm          | 0.000005 | /usr/lib/perl/5.18/Fcntl.pm:6          |
  | 14:11:05.43550 |      XSLoader.pm          | 0.000812 | /usr/lib/perl/5.18/Fcntl.pm:7          |
  | 14:11:05.44485 |  XSLoader.pm              | 0.000009 | /usr/lib/perl/5.18/POSIX.pm:9          |
  | 14:11:05.44676 |  Tie/Hash.pm              | 0.001250 | /usr/lib/perl/5.18/POSIX.pm:419        |
  | 14:11:05.44696 |      Carp.pm              | 0.000007 | /usr/share/perl/5.18/Tie/Hash.pm:5     |
  | 14:11:05.44706 |      warnings/register.pm | 0.000004 | /usr/share/perl/5.18/Tie/Hash.pm:6     |
   ------------------------------------------------------------------------------------------------
```

## Example

To get module trace information for the Benchmark module use this oneliner:

```
  perl -MDevel::Module::Trace=print -MBenchmark -e exit
```

