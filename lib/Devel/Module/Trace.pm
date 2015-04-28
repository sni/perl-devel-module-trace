package # hide package name from indexer
    DB;
# allow -d:Devel::Module::Trace loading
sub DB {}


package Devel::Module::Trace;

=head1 NAME

Devel::Module::Trace - Trace module origins

=head1 DESCRIPTION

This module traces use/require statements to print the origins of loaded modules

=cut

use warnings;
use strict;

our $VERSION = '0.01';

################################################################################
my $modules  = [];
my $cur_lvl  = $modules;
my $enabled  = 0;
BEGIN {
    use Time::HiRes qw/gettimeofday tv_interval time/;
};

################################################################################
$Devel::Module::Trace::print  = 0;
$Devel::Module::Trace::filter = [];
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
    if($enabled) {
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
    $enabled  = 1;
    *CORE::GLOBAL::require = sub {
        my @caller = caller;
        my $mod     = {name => $_[0], caller => $caller[1].':'.$caller[2], time => time };
        my $t0      = [gettimeofday];
        my $old_lvl = $cur_lvl;
        $cur_lvl    = [];
        my $res     = CORE::require($_[0]);
        my $elapsed = tv_interval($t0);
        $mod->{'elapsed'} = $elapsed;
        $mod->{'sub'}     = $cur_lvl if scalar @{$cur_lvl};
        $cur_lvl = $old_lvl;
        push(@{$cur_lvl}, $mod);
        return $res;
    };
    return;
}

################################################################################
sub _disable {
    *CORE::GLOBAL::require = *CORE::require;
    $enabled  = 0;
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

=head1 AUTHOR

Sven Nierlein, C<< <nierlein at cpan.org> >>

=head1 COPYRIGHT & LICENSE

Copyright 2015 Sven Nierlein.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.

=cut
