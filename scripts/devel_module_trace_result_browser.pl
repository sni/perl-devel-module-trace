#!/usr/bin/env perl

use warnings;
use strict;
use Socket;
use IO::Socket;
use POSIX;
use Template;
use Devel::Module::Trace;

my $file    = $ARGV[0] or die("usage: $0 <result file> [-r]");
my $restart = ($ARGV[1] && $ARGV[1] eq '-r') ? 1 : 0;
my $port    = 3000;

################################################################################
# read template
my $template;
while(<DATA>) { $template .= $_; }

################################################################################
my $server = new IO::Socket::INET(Proto     => 'tcp',
                                  LocalPort => $port,
                                  Listen    => SOMAXCONN,
                                  Reuse     => 1);
$server or die "Unable to create server socket: $!" ;
print STDERR "listenting on :$port\n";
while(my $client = $server->accept()) {
    my $output = _get_output();
    $client->autoflush(1);
    print $client "HTTP/1.0 200 OK", Socket::CRLF;
    print $client "Content-type: text/html", Socket::CRLF;
    print $client Socket::CRLF;
    print $client $output;
    close $client;
    exit if $restart;
}
exit;


################################################################################
# read result file
sub _get_output {
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
    my $result = $VAR1;
    my $filter = $VAR2;

    # flatten our result
    $Devel::Module::Trace::filter = $filter;
    my $flattened = _filter(_flatten_results($result));
    # calculate percentages
    my $start_time = $flattened->[0]->{'time'};
    my $end_time   = $start_time;
    for my $mod (@{$flattened}) {
        my $end = $mod->{'time'} + $mod->{'elapsed'};
        if($end > $end_time) { $end_time = $end; }
    }
    my $total_time = $end_time - $start_time;
    for my $mod (@{$flattened}) {
        $mod->{'offset_x'} = ($mod->{'time'} - $start_time) / $total_time;
        $mod->{'width'}    = $mod->{'elapsed'} / $total_time;
    }

    my $output;
    my $tt = Template->new();
    $tt->process(
        \$template,
        {
            'sprintf'    => \&CORE::sprintf,
            'int'        => \&CORE::int,
            'strftime'   => sub { return(POSIX::strftime($_[0], localtime($_[1]))) },
            'results'    => $flattened,
            'start_time' => $start_time,
            'end_time'   => $end_time,
        },
        \$output
    ) || die $tt->error();
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
        $mod->{'human_time'} =
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

__DATA__
﻿<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Devel::Module::Trace</title>
    <style type='text/css'>
      .node {
        white-space: nowrap;
        height: 20px;
        position: absolute;
        background: #52C5F6;
      }
      .node_border {
        position: absolute;
        border: 1px dotted grey;
      }
    </style>
  </head>
  <body>
  <h2>Module Load Order and Duration</h2>
  [% height = 20; width = 1000 %]
  <div style="position: relative; border: 1px solid black; height: [% results.size * height %]px; width: [% width %]px;">
  [% FOREACH r = results %]
  <div class="node_border" style="width: [% int(width * r.width) %]px; left: [% int(width * r.offset_x) %]px; top: [% loop.index * height %]px; height: [% (r.num_childs + 1) * height %]px;">
  <div class="node" style="width: [% int(width * r.width) %]px; left: 0; top: 0;" title="Name: [% r.name %]&#013;Started: [% r.human_time %]&#013;Elapsed: [% sprintf("%.5f", r.elapsed) %]s&#013;Package: [% r.package %]&#013;Caller: [% r.caller %]">[% r.name %]</div>
  </div>
  [% END %]
  </div>
  </body>
</html>
