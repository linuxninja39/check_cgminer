#!/usr/bin/env perl

use strict;
use warnings;

use JSON;
use Data::Dumper;
use IO::Socket::INET;
use Getopt::Long;

#flush after ever write
$| = 1;

sub minerCmd {
	my $host = shift;
	my $cmd = shift;
	my $param = shift;

	my $port = 4028;

	my $cmdHash = {
		command => $cmd,
	};
	if(defined $param) {
		$cmdHash->{parameter} = $param;
	}
	
	print Dumper($cmdHash);
	my $jsonString = encode_json($cmdHash);
	print "$jsonString\n";

	my $sock = new IO::Socket::INET(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
	if (!$sock) {
		die("Could not connect to host '$host': $!");
	}
	$sock->timeout(5);

	$sock->send($jsonString);

	my $ret = '';
	while ($sock->read(my $in,1024)) {
		$ret .= $in;
	}

	$sock->close();

	my $retHash = decode_json($ret);

	return $retHash;
}

sub checkTemp {
	my $data = shift;
	my $warn = shift;
	my $crit = shift;

	my $ret = {
		retVal => 0,
	};

	my $temp = $data->{GPU}->[0]->{Temperature};
	if (!$temp) {
		$ret->{retVal} = 3;
		$ret->{retString} = "Could not get Temperature from server";
		return $ret;
	}

	my $status = 'OK';
	
	if ($temp > $warn) {
		$ret->{retVal} = 1;
		$status = "Warning";
	}
	if ($temp > $crit) {
		$ret->{retVal} = 2;
		$status = "Critical";
	}

	$ret->{retString} = "Temperature $status " . $temp . '|' .$temp;

	return $ret;
}

sub checkHash {
	my $data = shift;
	my $warn = shift;
	my $crit = shift;

	my $ret = {
		retVal => 0,
	};

	my $hash = $data->{GPU}->[0]->{'MHS 5s'};
	if (!$hash) {
		$ret->{retVal} = 3;
		$ret->{retString} = "Could not get MHash/s from server";
		return $ret;
	}

	my $status = 'OK';
	
	if ($hash > $warn) {
		$ret->{retVal} = 1;
		$status = "Warning";
	}
	if ($hash > $crit) {
		$ret->{retVal} = 2;
		$status = "Critical";
	}

	$ret->{retString} = "MHash/s $status " . $hash . '|' .$hash;

	return $ret;
}

MAIN: {
	my $host;
	my $cmd;
	my $param;
	my $tempWarn;
	my $tempCrit;
	my $hashWarn;
	my $hashCrit;
	GetOptions(
		"host|h=s" => \$host,
		"command|c|cmd=s" => \$cmd,
		"parameter|p|param=s" => \$param,
		"tempWarn|tw=i" => \$tempWarn,
		"tempCrit|tc=i" => \$tempCrit,
		"hashWarn|hw=f" => \$hashWarn,
		"hashCrit|hc=f" => \$hashCrit,
	);

	my $minerData = minerCmd($host, $cmd, $param);
	print Dumper($minerData);

	my $ret = {
		retVal => 3,
		retString => 'Unknown'
	};

	if ($tempWarn && $tempCrit) {
		$ret = checkTemp($minerData, $tempWarn, $tempCrit);
	} elsif ($hashCrit && $hashWarn) {
		$ret = checkHash($minerData, $hashWarn, $hashCrit);
	}
	print $ret->{retString} . "\n";
	exit $ret->{retVal};
}
