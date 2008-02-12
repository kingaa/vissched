#! /usr/bin/perl -w

use strict;

my (@profs, @avail, @times, @students, @weight, @openings);
my ($nprof, $ntime, $nstudent, $type);
my ($p, $s, $t);
my ($len, $output, @a);

$t = 0;
$s = 0;

$type = "n";
while (<>) {
    s/\r\n/\n/g;	     # go from DOS to unix format if necessary
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

@weight = map {
    my $line = join ',', @$_; 
    $line =~ s/,,/,0,/g; 	# replace missing entries with 0
    $line =~ s/,,/,0,/g; 	# replace missing entries with 0
    $line =~ s/,$/,0/g; 	# replace trailing missing entries with 0
    $line =~ s/^,/0,/g; 	# replace leading missing entries with 0
    $line =~ s/,/ /g;	# replace commas with spaces
    $line;
} @weight;

$output = "$nprof $ntime $nstudent\n"
    . join("\n",@profs) . "\n"
    . join("\n",@times) . "\n"
    . join("\n",@students) . "\n"
    . join("\n",map {my $len = scalar(@{$_}); "$len @{$_}";} @openings) . "\n"
    . join("\n",@weight) . "\n";


print $output;

