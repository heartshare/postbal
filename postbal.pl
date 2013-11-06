#!/usr/bin/perl -w

# Postbal
# Postfix Load Balancer
# https://github.com/rbewley4/postbal
#
# Copyright 2013 Russell Bewley
# Released under the MIT license
#
# Based on original work by Hari Hendaryanto <hari.h -at- csmcom.com>

use strict;
use warnings;
use Sys::Syslog qw(:DEFAULT setlogsock);
use List::Util::WeightedRoundRobin;
use Storable;

#
# Configuration files
#
my $config_file = "/etc/postfix/postbal.cf";
my $recovery_file = "/tmp/postbal.dat";

#
# Initalize syslog
#
openlog('postfix/postbal','pid','mail');
syslog("info","Postbal starting, configuration %s, recovery %s", $config_file, $recovery_file);

#
# Read load balancer configuration from postbal.cf
#
my $list = [];

open(my $fh, "<", "/etc/postfix/postbal.cf")
	or die "cannot open /etc/postfix/postbal.cf: $!";

while (my $line = <$fh>) {
	chomp($line);
	if($line =~ /^\s*$/){
		# ignore whitespace and blank lines
	}
	elsif($line =~ /^\s*#/){
		# ignore comments
	}
	elsif($line =~ /^\{(\d+)\}(.*)/){
		# parse transport
		push(@$list, { name => $2, weight => $1 });
	}
	else {
	    syslog("info","postbal.cf: ERROR invalid line '%s'", $line);
	}
}

close($fh);

#
# Setup the Weighted Round-Robin scheduler based on our configuration.
#
my $weighted_list_factory = List::Util::WeightedRoundRobin->new();
my $weighted_list = $weighted_list_factory->create_weighted_list( $list );
my $num_transports = scalar(@{$weighted_list});

#
# Read the last known state from disk so
# that we can start where we left off
#
store {}, $recovery_file unless -r $recovery_file;
my $recovery_store=retrieve($recovery_file);

my $position;
if (!defined $recovery_store->{"last_position"}) {
    $position = 0;
}
else {
    $position = $recovery_store->{"last_position"};
}

#
# Autoflush standard output.
#
select STDOUT; $|++;

#
# Main event loop:
# Listen for "get" requests and respond
# with the name of a transport.
#
while (<>) {
    chomp;

    if (/^get\s(.+)$/i) {
        # choose the transport and reply to the request
        my $transport = ${$weighted_list}[$position];
        syslog("info","Using '%s' Transport Service", $transport);
        print "200 $transport\n";

        # advance to the next position in the list
        # for the next iteration
        $position++;
        if ($position >= $num_transports) {
            $recovery_store->{"last_position"} = 0;
            $position = 0;
        }

        # store the new position for recovery
        $recovery_store->{"last_position"} = $position;
        store $recovery_store, $recovery_file;
    }
    else {
        print "400 error:invalid_request\n";
    }
}