#!/usr/bin/perl

use strict;
use warnings;

sub usage { die "$0 year [start month (default: 1)]\n"; }

my $year   = shift @ARGV // usage();
my $startm = shift @ARGV // 1;

my($thisyear,$thismonth) = (localtime(time))[5,4];
$thisyear  += 1900;
$thismonth += 1;

print "hostname=";
system("hostname");
while(1) {
	do_month($year,$startm);
	last if $year == $thisyear && $startm == $thismonth;
	if(++$startm > 12)  { $year++; $startm=1; }
}

sub do_month {
	my($fyear,$fmonth) = @_;
	my($tyear,$tmonth) = @_;
	my $fromdate = sprintf("%04d-%02d-01",$fyear,$fmonth);
	if(++$tmonth > 12)  { $tyear++; $tmonth=1; }
	my $todate   = sprintf("%04d-%02d-01",$tyear,$tmonth);

	open(my $sacct,"-|","sacct --startt=${fromdate}T00:00:00 --endt=${todate}T00:00:00 --allusers --parsable2 --format=JobID,Elapsed,AllocCPUS,CPUTimeRAW,Start,User --state=ca,cd,f,nf,to") || die "Failed to run sacct for $fromdate -> $todate";

	my $headline = <$sacct>;
	chomp($headline);
	my @head  = split(/\|/,$headline);

	while(<$sacct>) {
		chomp;
		my @row = split(/\|/);
		next unless $row[0] =~ /^\d+$/;
		my %r;
		foreach my $h (@head) { $r{$h} = shift @row; }
		$r{wall_duration} = calc_wall_duration($r{Elapsed});

		my $d = $r{CPUTimeRAW} - ($r{wall_duration} * $r{AllocCPUS});
		if($d) {
			my $ncore = int($r{CPUTimeRAW} / $r{wall_duration});
			printf "%d;%d;%d;%s;%s\n", $r{JobID}, $ncore, $r{AllocCPUS}, $r{Start},$r{User};
		}
	}
	close($sacct) || die "sacct failed";
}

sub calc_wall_duration {
	my($e) = @_;
	return int($3)+int($2)*60+int($1)*60*60 if $e =~ /^(\d\d):(\d\d):(\d\d)$/;
	return int($4)+int($3)*60+(int($2)+int($1)*24)*60*60 if $e =~ /^(\d+)-(\d\d):(\d\d):(\d\d)$/;
	die $e;
}

