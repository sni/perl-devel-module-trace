#!/usr/bin/env perl

use warnings;
use strict;
use POSIX;
use Template;
use Mojolicious::Lite;
use JSON::XS;
use Devel::Module::Trace qw(noautostart);

my $file = $ARGV[0] or die("usage: $0 <result file>");

################################################################################
get '/' => sub {
  my $c   = shift;
  $c->render(text => _get_output());
};
app->start('daemon');
exit;


################################################################################
# read result file
sub _get_output {
    my($result, $filter) = _read_results($file);
    my $stash = {
        'sprintf'    => \&CORE::sprintf,
        'int'        => \&CORE::int,
        'strftime'   => sub { return(POSIX::strftime($_[0], localtime($_[1]))) },
    };

    # flatten our result
    $Devel::Module::Trace::filter = $filter;
    my $flattened = _filter(_flatten_results($result));
    $stash->{'results'} = $flattened;
    # calculate percentages
    my $start_time = $flattened->[0]->{'time'};
    my $end_time   = $start_time;
    for my $mod (@{$flattened}) {
        my $end = $mod->{'time'} + $mod->{'elapsed'};
        if($end > $end_time) { $end_time = $end; }
    }
    my $total_time = $end_time - $start_time;
    $stash->{'start_time'} = $start_time;
    $stash->{'end_time'}   = $end_time;
    $stash->{'total_time'} = $total_time;
    for my $mod (@{$flattened}) {
        $mod->{'offset_x'} = ($mod->{'time'} - $start_time) / $total_time;
        $mod->{'width'}    = $mod->{'elapsed'} / $total_time;
    }

    # get most used modules
    my $most = {};
    for my $mod (@{$flattened}) {
        if(!defined $most->{$mod->{'name'}}) {
            $most->{$mod->{'name'}} = {
                name     => $mod->{'name'},
                count    => 0,
                first    => $mod,
                others   => [],
                duration => 0,
            }
        } else {
            push @{$most->{$mod->{'name'}}->{'others'}}, $mod;
        }
        $most->{$mod->{'name'}}->{'count'}++;
        $most->{$mod->{'name'}}->{'duration'} += $mod->{'elapsed'};
    }
    $stash->{'most'}    = [sort { $b->{count} <=> $a->{count} } values %{$most}];
    $stash->{'modules'} = $most;

    # get slowest used modules
    $stash->{'slowest'} = [sort { $b->{duration} <=> $a->{duration} } values %{$most}];

    my $template = _get_template();
    my $output;
    my $tt = Template->new();
    $tt->process(\$template, $stash, \$output) || die $tt->error();
    return($output);
}


################################################################################
sub _flatten_results {
    my($mods) = @_;
    my $flat = [];
    for my $mod (@{$mods}) {
        $mod->{'num_childs'} = 0 unless $mod->{'num_childs'};
        push @{$flat}, $mod;
        if($mod->{'sub'}) {
            for my $submod (@{$mod->{'sub'}}) {
                $submod->{'parent'} = $mod;
            }
            my $subs = _flatten_results($mod->{'sub'});
            push @{$flat}, @{$subs};
            $mod->{'num_childs'} += scalar @{$subs};
        }
        my($time, $milliseconds) = split(/\./mx, $mod->{'time'});
        $mod->{'human_starttime'} =
            POSIX::strftime("%H:%M:", localtime($time)).
            POSIX::strftime("%S", localtime($time)).'.'.$milliseconds;
        ($time, $milliseconds) = split(/\./mx, ($mod->{'time'}+$mod->{'elapsed'}));
        $mod->{'human_endtime'} =
            POSIX::strftime("%H:%M:", localtime($time)).
            POSIX::strftime("%S", localtime($time)).'.'.$milliseconds;

    }
    return($flat);
}

################################################################################
sub _filter {
    my($mods) = @_;
    my $filtered = [];
    for my $mod (@{$mods}) {
        if(Devel::Module::Trace::_filtered($mod->{'name'})) {
            $mod->{'parent'}->{'num_childs'}--;
            next;
        }
        push @{$filtered}, $mod;
    }
    return($filtered);
}

################################################################################
sub _get_template {
    our $data    = "";
    my $template = "";
    if(-e 'templates/index.tt') {
        open(my $fh, '<', 'templates/index.tt') or die("cannot read index.tt: $!");
        while(<$fh>) { $template .= $_; }
        close($fh);
    } else {
        if(!$data) {
            while(<DATA>) { $template .= $_; }
        }
        $template = $data;
    }
    return($template);
}

################################################################################
sub _read_results {
    my($file) = @_;
    open(my $fh, '<', $file) or die("cannot open $file: $!");
    my $content = "";
    while(<$fh>) { $content .= $_; }
    close($fh);
    if($content !~ m/^\$VAR1/) {
        die("unknown result file format");
    }
    my($VAR1, $VAR2);
    eval($content);
    die($@) if($@);
    return($VAR1, $VAR2);
}

################################################################################

__DATA__