#!/usr/bin/perl -w

use strict;
use DateTime;

my @month = ('None','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
my %weekday = ("SU" => 'Sun', "MO" => 'Mon', "TU" => 'Tue', "WE" => 'Wed', "TH" => 'Thu', "FR" => 'Fri', "SA" => 'Sat');
my $timezone = "+0200";

sub ParseDate
{
	my $date = shift;
	my ($dtstart, $tzid) = ();

	$date =~ s/VALUE=DATE//;
	if ($date =~ /TZID=(.*?)[:;]/) {
		$tzid = $1;
		$date =~ s/TZID=$tzid//;
	}

	$date =~ s/[;:]//g;

	if ($date =~ /Z$/) {
		$tzid = "UTC";
		$date =~ s/Z$//;
	}

	unless (defined $tzid) {
		$tzid = "UTC";
	}

	if (length($date) == 8) {
		$dtstart = DateTime->new(
			year => substr($date, 0, 4),
			month => substr($date, 4, 2),
			day => substr($date, 6, 2),
			time_zone => $timezone
			);
	}
	else {
#		print "Parsing date: >$date<\n";
		$dtstart = DateTime->new(
			year => substr($date, 0, 4),
			month => substr($date, 4, 2),
			day => substr($date, 6, 2),
			hour => substr($date, 9, 2),
			minute => substr($date, 11, 2),
			second => substr($date, 13, 2),
			time_zone => $tzid);
	}

	return $dtstart;
}

sub ParseRrule
{
	my $rrule = shift;

	my %rule = ( 'FREQ' => '',
		'BYMONTH' => '',
		'BYMONTHDAY' => '',
		'BYDAY' => '',
		'BYDAYNBR' => ''
		);

	if ($rrule =~ /FREQ=([A-Z]+)/) {
		$rule{'FREQ'} = $1;
	}
	if ($rrule =~ /BYMONTH=(\d+)/) {
		$rule{'BYMONTH'} = $1;
	}
	if ($rrule =~ /BYMONTHDAY=(\d+)/) {
		$rule{'BYMONTHDAY'} = $1;
	}

	if ($rrule =~ /BYDAY=(-?\d+)([^;]+)/) {
		$rule{'BYDAYNBR'} = $1;
		$rule{'BYDAY'} = $2;
	}
	elsif ($rrule =~ /BYDAY=([^;]+)/) {
		$rule{'BYDAY'} = $2;
	}

	return %rule;
}

sub ParseEvent
{
	my ($dtstart, $summary, %rrule);

	while(<>)
	{
		chop;
		chop;
		if (/^DTSTART(.*)/) {
			$dtstart = ParseDate($1);
		}
		elsif (/^SUMMARY:(.*)/ && !defined $summary) {
			$summary = $1;
		}
		elsif (/^RRULE:(.*)/) {
			%rrule = ParseRrule($1);
		}
		elsif (/^END:VEVENT/) {
			last;
		}
	}

#	print "Event: $summary\n";

# FIXME ml
	$dtstart->set_time_zone($timezone);

#	printf "Start: %d.%d.%d %d:%02d:%02d\n",
#		$dtstart->day,
#		$dtstart->month,
#		$dtstart->year,
#		$dtstart->hour,
#		$dtstart->min,
#		$dtstart->sec;

	my $have_time = 1;
	if ($dtstart->hour == 0 &&
		$dtstart->min == 0 &&
		$dtstart->sec == 0) {
		$have_time = 0;
	}
	
	print "REM";
	
	if (%rrule) {
		if ($rrule{'FREQ'} eq "MONTHLY"
			&& $rrule{'BYDAYNBR'} ne "0"
			&& $rrule{'BYDAY'} ne ""
		) {
			print " " . $weekday{$rrule{'BYDAY'}} .
				" " . $rrule{'BYDAYNBR'};
		}
		elsif ($rrule{'FREQ'} eq "YEARLY"
			&& $rrule{'BYMONTH'} ne ""
			&& $rrule{'BYMONTHDAY'} ne ""
		) {
			print " " . $month[$rrule{'BYMONTH'}] .
				" " . $rrule{'BYMONTHDAY'};
		}
		elsif ($rrule{'BYMONTHDAY'} ne "") {
			print " " . $rrule{'BYMONTHDAY'};
		}
		else {
			die;
		}
	}
	else {
		printf " %s %d %d",
			$month[$dtstart->month],
			$dtstart->day,
			$dtstart->year;
	}

	if ($have_time == 1) {
		printf " AT %d:%02d",
			$dtstart->hour,
			$dtstart->min;
	}

	print " MSG $summary\n";
}

# Main

while(<>)
{
	if (/^BEGIN:VEVENT/)
	{
		ParseEvent();
	}
}
