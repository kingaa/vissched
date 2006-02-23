#! /usr/bin/perl -w

use strict;

my (@profs, @avail, @times, @students, @weight, @openings);
my ($nprof, $ntime, $nstudent, $type);
my ($p, $s, $t);
my ($len, @a);

$t = 0;
$s = 0;

$type = "n";
while (<>) {
    chop;
    @a = split /,\s*/;
    $len = scalar(@a);

    if ($a[0] =~ /Availability/) {
	@profs = @a[1..$len-1];
	$type = "a";
    } elsif ($a[0] =~ /Matches/) {
	@profs = @a[1..$len-1];
	$type = "m";
    } elsif ($type =~ /a/) {
	$times[$t] = $a[0];
	$avail[$t] = [@a[1..$len-1]];
	$t += 1;
    } elsif ($type =~ /m/) {
	$students[$s] = $a[0];
	$weight[$s] = [@a[1..$len-1]];
	$s += 1;
    }

}

$nprof = scalar(@profs);
$ntime = scalar(@times);
$nstudent = scalar(@students);

for $t (0..$ntime-1) {
    my ($j, $k, @ope);
    $j = 0;
    for $k (0..$nprof-1) {
	if (${$avail[$t]}[$k]) {
	    $ope[$j] = $k;
	    $j++;
	}
    }
    $openings[$t] = [@ope];
}

print "$nprof $ntime $nstudent\n";
foreach $p (@profs) {
    print "$p\n";
}
foreach $t (@times) {
    print "$t\n";
}
foreach $s (@students) {
    print "$s\n";
}
foreach $t (@openings) {
    $len = scalar(@{$t});
    print "$len @{$t}\n";
}
foreach $s (@weight) {
    print "@{$s}\n";
}
