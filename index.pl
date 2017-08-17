#! /usr/bin/perl -w 

use strict;
use VisSched;
use CGI;
use CGI::Carp qw(fatalsToBrowser set_message);

set_message("It's not a bug, it's a feature!---Send questions, complaints, and commentaries to kingaa at umich dot edu");
$VisSched::CGINAME = 'index.pl';

my $query = new CGI;

if (!($query->param('upload'))) {
    frontpage($query);
} elsif (verify($query)) {
    download($query);
}

exit;
