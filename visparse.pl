#! /usr/bin/perl -w

use strict;
use VisSched qw(visparse);

my @input = <>;

print visparse \@input;
