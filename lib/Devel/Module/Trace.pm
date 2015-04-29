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
use Devel::OverrideGlobalRequire;

our $VERSION = '0.02';

################################################################################
my $modules = [];
my $cur_lvl = $modules;
BEGIN {
    use Time::HiRes qw/gettimeofday tv_interval time/;
    $^P = $^P | 0x400; # Save source code lines, see perldoc perlvar
};

################################################################################
$Devel::Module::Trace::print   = 0;
$Devel::Module::Trace::filter  = [];
$Devel::Module::Trace::enabled = 0 unless defined $Devel::Module::Trace::enabled;
sub import {
    my(undef, @options) = @_;
    for my $option (@options) {
        if($option eq 'print') {
            $Devel::Module::Trace::print = 1;
        }
        elsif($option =~ 'filter=(.*)$') {
            my $filter = $1;
            push @{$Devel::Module::Trace::filter}, $filter;
        } else {
            die("unknown option: ".$option);
        }
    }
    return;
}

################################################################################

=head1 METHODS

=head2 raw_result

    raw_result()

returns an array with the raw result list.

=cut
sub raw_result {
    return($modules);
}

################################################################################

=head2 print_pretty

    print_pretty()

prints the results as ascii table to STDERR.

=cut
sub print_pretty {
    my $reenable = 0;
    if($Devel::Module::Trace::enabled) {
        _disable();
        $reenable = 1;
    }
    my($raw, $indent, $max_module, $max_caller, $max_indent) = @_;
    $raw    = $modules unless $raw;
    if(!$indent) {
        require POSIX;
        $indent = 0;
        # get max caller and module
        ($max_module, $max_caller) = _get_max_pp_size($modules, 0, 0, 0);
        return if $max_module == 0;
        print " ","-"x($max_module+$max_caller+34), "\n" if $indent == 0;
    }
    for my $mod (@{$raw}) {
        next if _filtered($mod->{'name'});
        my($time, $milliseconds) = split(/\./mx, $mod->{'time'});
        printf(STDERR "| %s%08.5f | %-".$indent."s %-".($max_module-$indent)."s | %.6f | %-".$max_caller."s |\n",
                    POSIX::strftime("%H:%M:", localtime($time)),
                    POSIX::strftime("%S", localtime($time)).'.'.$milliseconds,
                    "",
                    $mod->{'name'},
                    $mod->{'elapsed'},
                    $mod->{'caller'},
        );
        if($mod->{'sub'}) {
            print_pretty($mod->{'sub'}, $indent+4, $max_module, $max_caller, $max_indent);
        }
    }
    print " ","-"x($max_module+$max_caller+34), "\n" if $indent == 0;
    _enable() if $reenable;
    return;
}

################################################################################
sub _enable {
    $Devel::Module::Trace::enabled = 1;
    Devel::OverrideGlobalRequire::override_global_require(\&_trace_use);
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
        package => $p,
        name    => $module_name,
        caller  => $f.':'.$l,
        time    => time
    };
    my $t0      = [gettimeofday];
    my $old_lvl = $cur_lvl;
    $cur_lvl    = [];
    my $res     = &{$next_require}();
    my $elapsed = tv_interval($t0);
    $mod->{'elapsed'} = $elapsed;
    $mod->{'sub'}     = $cur_lvl if scalar @{$cur_lvl};
    $cur_lvl          = $old_lvl;
    push(@{$cur_lvl}, $mod);
    return $res;
}

################################################################################
sub _disable {
    $Devel::Module::Trace::enabled = 0;
    return;
}

################################################################################
BEGIN {
    _enable();
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
    my($mods, $max_module, $max_caller, $cur_indent) = @_;
    for my $mod (@{$mods}) {
        next if _filtered($mod);
        my $l1 = length($mod->{'name'}) + $cur_indent;
        my $l2 = length($mod->{'caller'});
        $max_module = $l1 if $max_module < $l1;
        $max_caller = $l2 if $max_caller < $l2;
        if($mod->{'sub'}) {
            ($max_module, $max_caller) = _get_max_pp_size($mod->{'sub'}, $max_module, $max_caller, $cur_indent+4);
        }
    }
    return($max_module, $max_caller);
}

################################################################################
END {
    print_pretty() if $Devel::Module::Trace::print;
};

################################################################################

1;

=head1 TODO

    * add waterfall charts output

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
