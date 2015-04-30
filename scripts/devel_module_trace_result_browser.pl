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
    $|=1;
    my $output = _get_output();
    $client->autoflush(1);
    print $client "HTTP/1.0 200 OK", Socket::CRLF;
    print $client "Content-type: text/html", Socket::CRLF;
    print $client "Content-Length: ",length($output), Socket::CRLF;
    print $client "Cache-Control: no-cache ", Socket::CRLF;
    print $client Socket::CRLF;
    print $client $output;
    sleep(1);
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

__DATA__
﻿<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Frameset//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-frameset.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
    <title>Devel::Module::Trace</title>
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap.min.css" />
    <link rel="stylesheet" href="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/css/bootstrap-theme.min.css" />
    <script type="text/javascript" src="https://ajax.googleapis.com/ajax/libs/jquery/1.11.2/jquery.min.js"></script>
    <script type="text/javascript" src="https://maxcdn.bootstrapcdn.com/bootstrap/3.3.4/js/bootstrap.min.js"></script>
    <style type='text/css'>
      .node {
        white-space: nowrap;
        height: 13px;
        position: absolute;
        background: #5bc0de;
        line-height: 13px;
        font-size: x-small;
      }
      .node_border {
        position: absolute;
        border: 1px dotted grey;
      }
      .nodetooltip {
        text-align: left;
        white-space: nowrap;
      }
      .nodetooltip TD {
        maring-left: 2px;
        padding-right: 3px;
      }
    </style>
  </head>
  <body>

<!-- Navigation -->
<a name="top"></a>
<nav class="navbar navbar-default navbar-static-top">
  <div class="container">
    <div id="navbar" class="navbar-collapse collapse">
      <ul class="nav navbar-nav">
        <li><a href="#waterfall">Waterfall</a></li>
        <li><a href="#most-used">Most Used Modules</a></li>
        <li><a href="#slowest">Slowest Modules</a></li>
      </ul>
    </div>
  </div>
</nav>


<div class="container">

<!-- Waterfall -->
<a name="waterfall"></a>
<div class="page-header">
    <h1>Waterfall</h1>
</div>
<p>
  [% height = 18; width = 1000 %]
  <div style="position: relative; border: 1px solid grey; width: [% width - 1 %]px; height: [% (results.size * (height - 2)) - 1 %]px;">
  [% FOREACH r = results %]
  <span class="node_border" style="width: [% int(width * r.width)  %]px; left: [% int(width * r.offset_x) - 1 %]px; top: [% (loop.index * (height - 2)) - 1 %]px; height: [% ((r.num_childs + 1) * (height - 2)) - 1 %]px;">
  <span class="node" data-toggle="tooltip" data-placement="bottom" style="width: [% int(width * r.width) - 2 %]px; left: 0; top: 0;" title="<table class='nodetooltip'><tr><td>Name:</td><td>[% r.name %]</td></tr><tr><td>Started:</td><td>[% r.human_starttime %]</td></tr><tr><td>Started:</td><td>[% r.human_endtime %]</td></tr><tr><td>Duration:</td><td>[% sprintf('%.5f', r.elapsed) %]s</td></tr><tr><td>Package:</td><td>[% r.package %]</td></tr><tr><td>Caller:</td><td>[% r.caller %]</td></tr></table>">[% r.name %]</span>
  </span>
  [% END %]
  </div>
</p>


<!-- Most Used -->
<a name="most-used"></a>
<div class="page-header">
    <h1>Most Used Modules</h1>
</div>
<p>
</p>


<!-- Slowest Modules -->
<a name="slowest"></a>
<div class="page-header">
    <h1>Slowest Modules</h1>
</div>
<p>
</p>


</div>

<script type="text/javascript">
$(document).ready(function(){
    $('[data-toggle="tooltip"]').tooltip({html: true});
});
</script>
  </body>
</html>
