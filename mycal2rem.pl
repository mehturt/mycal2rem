#!/usr/bin/perl -w

use strict;
use DateTime;

my @month = ('None','Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');
my %weekday = ("SU" => 'Sun', "MO" => 'Mon', "TU" => 'Tue', "WE" => 'Wed', "TH" => 'Thu', "FR" => 'Fri', "SA" => 'Sat');
my $timezone = "CET";
my $debug = 0;

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
#		print "Parsing date: >$date< tz >$tzid<\n";
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
		$rule{'BYDAY'} = $1;
	}

	return %rule;
}

sub ParseValarm
{
	my ($trigger);

	while(<>)
	{
		chop;
		chop;
		if (/^END:VALARM$/) {
			last;
		}
		elsif (/^ACTION:(.+)$/) {
			if ($1 ne "DISPLAY") {
				last;
			}
		}
		elsif (/^TRIGGER:-P(\d+)DT(\d+)H(\d+)M\d+S$/) {
			my $minutes = $2 * 60 + $3;
			$trigger = "+$minutes";
		}
	}

	return $trigger;
}

sub ParseEvent
{
	my ($dtstart, $summary, %rrule, $trigger);

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
		elsif (/^BEGIN:VALARM$/) {
			my $l_trigger = ParseValarm;
			if (!defined $trigger) {
				$trigger = $l_trigger;
			}
		}
		elsif (/^END:VEVENT/) {
			last;
		}
	}

	print "Event: $summary\n" if ($debug == 1);
	print "Event trigger: $trigger\n" if (defined $trigger && $debug == 1);

# FIXME ml
	$dtstart->set_time_zone($timezone);

	if ($debug == 1) {
		printf "Start: %d.%d.%d %d:%02d:%02d\n",
			$dtstart->day,
			$dtstart->month,
			$dtstart->year,
			$dtstart->hour,
			$dtstart->min,
			$dtstart->sec;
	}

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
		elsif ($rrule{'FREQ'} eq "WEEKLY"
			&& $rrule{'BYDAY'} ne ""
		) {
			print " " . $weekday{$rrule{'BYDAY'}};
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
		if (defined $trigger) {
			print " $trigger";
		}
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
