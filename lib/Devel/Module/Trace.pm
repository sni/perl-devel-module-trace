## no critic
package # hide package name from indexer
    DB;
# allow -d:Devel::Module::Trace loading
sub DB {}
## use critic

package Devel::Module::Trace;

=head1 NAME

Devel::Module::Trace - Trace module origins

=head1 DESCRIPTION

This module traces use/require statements to print the origins of loaded modules

=head1 SYNOPSIS

=over 4

  # load module
  use Devel::Module::Trace;

  # load other modules
  use Some::Other::Modules;
  require Even::More::Modules;

  # output results
  Devel::Module::Trace::print_pretty();

  # using directly
  perl -d:Module::Trace=print -M<Module> -e exit

=back

=cut

use warnings;
use strict;
use Data::Dumper;
use POSIX;
use Devel::OverrideGlobalRequire;

our $VERSION = '0.03';

################################################################################
BEGIN {
    use Time::HiRes qw/gettimeofday tv_interval time/;
    $^P = $^P | 0x400; # Save source code lines, see perldoc perlvar

    #$Devel::Module::Trace::modules   = [] unless defined $Devel::Module::Trace::modules;
    $Devel::Module::Trace::count     = 0  unless defined $Devel::Module::Trace::count;
    $Devel::Module::Trace::print     = 0  unless defined $Devel::Module::Trace::print;
    $Devel::Module::Trace::filter    = [] unless defined $Devel::Module::Trace::filter;
    $Devel::Module::Trace::enabled   = 0  unless defined $Devel::Module::Trace::enabled;
    $Devel::Module::Trace::save      = 0  unless defined $Devel::Module::Trace::save;
    $Devel::Module::Trace::autostart = 1  unless defined $Devel::Module::Trace::autostart;
    $Devel::Module::Trace::all       = [] unless defined $Devel::Module::Trace::all;
    $Devel::Module::Trace::nested    = 0  unless defined $Devel::Module::Trace::nested;
}
my $cur_parent;
my $indent = 4;

################################################################################
sub import {
    my(undef, @options) = @_;
    for my $option (@options) {
        if($option eq 'print') {
            $Devel::Module::Trace::print = 1;
        }
        elsif($option eq 'noautostart') {
            $Devel::Module::Trace::autostart = 0;
        }
        elsif($option =~ 'filter=(.*)$') {
            my $filter = $1;
            push @{$Devel::Module::Trace::filter}, $filter;
        }
        elsif($option =~ 'save=(.*)$') {
            $Devel::Module::Trace::save = $1;
        } else {
            die("unknown option: ".$option);
        }
    }
    _enable() if $Devel::Module::Trace::autostart;
    return;
}

################################################################################

=head1 METHODS

=head2 raw_result

    raw_result()

returns an array with the raw result list.

=cut
sub raw_result {
    return($Devel::Module::Trace::all);
}

################################################################################

=head2 save

    save(<filename>)

save results to given file

=cut
sub save {
    my($file) = @_;
    open(my $fh, '>', $file) or die("cannot write to $file: $!");
    $Data::Dumper::Indent = 1;
    $Data::Dumper::Purity = 1;
    print $fh Dumper({
        result => raw_result(),
        filter => $Devel::Module::Trace::filter,
        script => $0,
    });
    close($fh);
    print STDERR $Devel::Module::Trace::count." modules written to ".$file."\n";
    return;
}

################################################################################

=head2 print_pretty

    print_pretty()

prints the results as ascii table to STDERR.

=cut
sub print_pretty {
    my($raw) = @_;
    $raw = raw_result() unless $raw;
    # get max caller and module
    my($max_module, $max_caller) = _get_max_pp_size(raw_result());
    return if $max_module == 0;
    print " ","-"x($max_module+$max_caller+34), "\n";
    for my $mod (@{$raw}) {
        next if _filtered($mod->{'name'});
        my($time, $milliseconds) = split(/\./mx, $mod->{'time'});
        my $spaces = $mod->{'level'}*$indent;
        printf(STDERR "| %s%08.5f | %-".($spaces)."s %-".($max_module-$spaces)."s | %.6f | %-".$max_caller."s |\n",
                    POSIX::strftime("%H:%M:", localtime($time)),
                    POSIX::strftime("%S", localtime($time)).'.'.$milliseconds,
                    "",
                    $mod->{'name'},
                    $mod->{'elapsed'},
                    $mod->{'caller'},
        );
    }
    print " ","-"x($max_module+$max_caller+34), "\n";
    return;
}

################################################################################
sub _enable {
    $Devel::Module::Trace::enabled = 1;
    # prevent adding it twice which results in endless recursion
    if($Devel::Module::Trace::subref && $Devel::Module::Trace::subref eq "".\&{*CORE::GLOBAL::require}) {
        return;
    }
    Devel::OverrideGlobalRequire::override_global_require(\&_trace_use);
    $Devel::Module::Trace::subref = "".\&{*CORE::GLOBAL::require};
    return;
}

################################################################################
sub _trace_use {
    my($next_require,$module_name) = @_;
    if(!$Devel::Module::Trace::enabled) {
        return &{$next_require}();
    }
    my($p,$f,$l) = caller(1);
    my $code;
    {
        ## no critics
        no strict 'refs';
        $code = \@{"::_<$f"};
        ## use critics
    }
    if(!$code->[$l]) {
        return &{$next_require}();
    }
    my $code_str = $code->[$l];
    my $i = $l-1;
    # try to concatenate previous lines if statement was multilined
    while($i > 0 && $code->[$i] && $code->[$i] !~ m/^(.*\}|.*\;|=cut)\s*$/mxo) {
        if($code->[$i] !~ m/^\s*$|^\s*\#/mxo) {
            $code_str = $code->[$i].$code_str;
        }
        $i--;
    }
    if($code_str !~ m/^\s*(use|require)/mxo) {
        return &{$next_require}();
    }
    my $mod = {
        'package'  => $p,
        'name'     => $module_name,
        'caller'   => $f.':'.$l,
        'caller_f' => $f,
        'caller_l' => $l,
        'time'     => time,
        'level'    => $Devel::Module::Trace::nested,
    };
    if($cur_parent) {
        $cur_parent->{'sub'} = [] unless defined $cur_parent->{'sub'};
        push(@{$cur_parent->{'sub'}}, $mod);
        $mod->{'parent'} = $cur_parent;
    }
    push(@{$Devel::Module::Trace::all}, $mod);
    $Devel::Module::Trace::nested++;
    $cur_parent       = $mod;
    my $t0            = [gettimeofday];
    my $res           = &{$next_require}();
    my $elapsed       = tv_interval($t0);
    $mod->{'elapsed'} = $elapsed;
    $Devel::Module::Trace::nested--;
    $cur_parent       = $mod->{'parent'};
    $Devel::Module::Trace::count++;
    return $res;
}

################################################################################
sub _disable {
    $Devel::Module::Trace::enabled = 0;
    return;
}

################################################################################
BEGIN {
    _enable() if $Devel::Module::Trace::autostart;
};

################################################################################
sub _filtered {
    my($mod) = @_;
    for my $f (@{$Devel::Module::Trace::filter}) {
        if($mod =~ m|$f|mx) {
            return(1);
        }
        if($f eq 'perl' && $mod =~ m|^[\d\.]+$|mx) {
            return(1);
        }
    }
    return;
}

################################################################################
sub _get_max_pp_size {
    my($mods) = @_;
    my($max_module, $max_caller) = (0,0);
    for my $mod (@{$mods}) {
        next if _filtered($mod);
        my $l1 = length($mod->{'name'}) + ($mod->{'level'} * $indent);
        my $l2 = length($mod->{'caller'});
        $max_module = $l1 if $max_module < $l1;
        $max_caller = $l2 if $max_caller < $l2;
    }
    return($max_module, $max_caller);
}

################################################################################
END {
    print_pretty() if $Devel::Module::Trace::print;
    save($Devel::Module::Trace::save) if $Devel::Module::Trace::save;
};

################################################################################

1;

=head1 REPOSITORY

    Git: http://github.com/sni/perl-devel-module-trace

=head1 SEE ALSO

    L<Devel::OverrideGlobalRequire>

=head1 AUTHOR

Sven Nierlein, C<< <nierlein at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2015 Sven Nierlein.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
