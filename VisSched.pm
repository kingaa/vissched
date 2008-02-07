package VisSched;

use 5.8.8;
use strict;
use warnings;
use CGI qw(:standard -nosticky -no_xhtml);
use FileHandle;
use IPC::Open2;
use Text::CSV;
use POSIX qw(strftime floor);

require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(
		 frontpage
		 verify
		 download
		 $CGINAME
		 $CSSFILE
		 $NTRIES
		 $NBEST
		 $NRAND
		 $DOCFILE
		 $LOGFILE
		 );

our $VERSION = '0.01';

our $CGINAME;
our $CSSFILE = './styley.css';
our $NTRIES = 100;
our $NBEST = 1;
our $NRAND = 5000;
our $DOCFILE = 'README.html';
our $LOGFILE = 'vissched.log';

sub init {
    my $q = shift;
    $q->param('ntries',$NTRIES) if (!($q->param('ntries')));
    $q->param('nrand',$NRAND) if (!($q->param('nrand')));
    $q->param('nbest',$NBEST) if (!($q->param('nbest')));
    1;
}

sub frontpage {
    my $q = shift;
    logger($q,'initial call');
    init($q);
    print $q->header(-expires=>'+0s'),
    $q->start_html(-title=>'vissched main page',-style=>{-src=>$CSSFILE}),
    $q->h1('vissched main page'),
    $q->hr,
    $q->p("Read the documentation",
	  $q->a({'href'=>$DOCFILE,'target'=>'_blank'},'here.')),
    $q->p("Download a template input CSV file", 
	  $q->a({'href'=>'input.csv'},'here.')),
    $q->start_multipart_form(-method=>'post',-action=>$CGINAME),
    $q->p("CSV file to upload:",
	  $q->filefield(-name=>'inputfile',-size=>'40')),
    $q->p("Number of tries:",
	  $q->textfield(-name=>'ntries',-value=>$q->param('ntries'),-size=>'5'),
	  "(must be between 1 and 1000)"),
    $q->p("Number of random swaps per try:",
	  $q->textfield(-name=>'nrand',-value=>$q->param('nrand'),-size=>'5'),
	  "(must be between 1 and 10000)"),
    $q->p("Number of schedules to keep:",
	  $q->textfield(-name=>'nbest',-value=>$q->param('nbest'),-size=>'5'),
	  "(must be between 1 and 3)"),
    $q->p($q->submit(-name=>'upload',-label=>'Compute'),
	  '&nbsp;',
	  $q->reset(-value=>'Reset ')),
    $q->end_form,
    $q->hr,
    $q->end_html;
    1;
}

sub verify {
    my $q = shift;
    logger($q,'verify call');
    my $retval = 1;
    $retval = 0 if (!($q->param('inputfile')));
    $retval = 0 if (!($q->param('ntries')) or $q->param('ntries') < 1 or $q->param('ntries') > 1000);
    $retval = 0 if (!($q->param('nrand')) or $q->param('nrand') < 1 or $q->param('nrand') > 10000);
    $retval = 0 if (!($q->param('nbest')) or $q->param('nbest') < 1 or $q->param('nbest') > 3);
    if ($retval == 0) {
 	print $q->header(-expires=>'+0s'),
	$q->start_html(-title=>'vissched error',-style=>{-src=>$CSSFILE}),
	$q->start_html(-title=>'vissched error',-style=>{-src=>'./styley.css'},
		       -head=>meta({-http_equiv=>'refresh',
				    -content=>"3;url=$CGINAME"})),
	$q->hr,
	$q->p("The parameters you specifed are outside of the allowable range."),
	$q->p($q->a({'href'=>$CGINAME},
		    "Please click on this link if you are not redirected in a few moments.")),
	$q->hr,
	$q->end_html;
    }
    $retval;
}

sub visparse {

    my $input = shift;
    my $csv = Text::CSV->new();
    my (@profs, @avail, @times, @students, @weight, @openings);
    my ($nprof, $ntime, $nstudent, $type);
    my ($p, $s, $t);

    $t = 0;
    $s = 0;

    $type = "n";
    foreach (@$input) {

	if (!($csv->parse($_))) {
	    my $err = $csv->error_input();
	    die "cannot parse the line:\n$err\n";
	}

	my $status = $csv->parse($_);
	my @a = $csv->fields();
	my $len = scalar(@a);

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

    "$nprof $ntime $nstudent\n"
	. join("\n",@profs) . "\n"
	. join("\n",@times) . "\n"
	. join("\n",@students) . "\n"
	. join("\n",map {my $len = scalar(@{$_}); "$len @{$_}";} @openings) . "\n"
	. join("\n",@weight) . "\n";
}

sub visparse_old {

    my $input = shift;
    my (@profs, @avail, @times, @students, @weight, @openings);
    my ($nprof, $ntime, $nstudent, $type);
    my ($p, $s, $t);

    $t = 0;
    $s = 0;

    $type = "n";
    foreach (@$input) {
	s/\r\n/\n/g;		# go from DOS to unix format if necessary
 	chop;
	
	my @a = split /,\s*/, $_, -1; # do not drop trailing fields
	my $len = scalar(@a);

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

    "$nprof $ntime $nstudent\n"
	. join("\n",@profs) . "\n"
	. join("\n",@times) . "\n"
	. join("\n",@students) . "\n"
	. join("\n",map {my $len = scalar(@{$_}); "$len @{$_}";} @openings) . "\n"
	. join("\n",@weight) . "\n";
}

sub vissched {
    my $q = shift;
    my $file = $q->param('inputfile');
    open(INPUT,"<$file") or die("cannot open input CSV file $file for reading: $!");
    my @input = <INPUT>;
    close(INPUT);
    my ($rh,$wh);
    my $ntries = $q->param('ntries');
    my $nrand = $q->param('nrand');
    my $nbest = $q->param('nbest');
    my $pid = open2($rh,$wh,"nice ./vissched --ntries=$ntries --nbest=$nbest --nrand=$nrand");
    print $wh visparse \@input;
    my @ans = <$rh>;
    @ans;
}

sub schedulepage {
    my $q = shift;
    my @sched = vissched $q;
    print $q->header(-expires=>'+0s'),
    $q->start_html(-title=>'View schedule page',-style=>{-src=>$CSSFILE},
		   -head=>meta({-http_equiv=>'pragma',-content=>"no-cache"}),
		   -head=>meta({-http_equiv=>'cache-control',-content=>"no-store"})),
    $q->h1('View schedule page'),
    $q->hr,
    $q->start_multipart_form(-method=>'post',-action=>$CGINAME),
    $q->submit(-name=>'mainpage',-value=>'Cancel  '),
    "&nbsp;",
    $q->submit(-name=>'download',-value=>'Download'),
    $q->start_table({-border=>'1'});
    foreach my $line (@sched) {
	print $q->start_Tr();
	my @recs = split /,/, $line;
	foreach (@recs) {
	    print $q->td($_);
	}
	print $q->end_Tr();
    }
    print $q->end_table(),
    $q->br,
    $q->submit(-name=>'mainpage',-value=>'Cancel  '),
    "&nbsp;",
    $q->submit(-name=>'download',-value=>'Download'),
    $q->end_form,
    $q->end_html;
    1;
}

sub download {
    my $q = shift;
    logger($q,'download call');
    my @sched = vissched $q;
    print $q->header(-type=>'application/x-download',
 		     -expires=>'+0s',
 		     -content_disposition=>'attachment;filename=output.csv');
    foreach (@sched) {
	s/\n/\r\n/g;		# put the output into DOS format
	print;
    }
    1;
}


sub logger {
    my $query = shift;
    my $msg = shift;
    open(LOG,">>$LOGFILE") 
	or die("cannot open file $LOGFILE for writing: $!");
    flock LOG, 2;
    print LOG strftime("%c",gmtime()) 
	. ' GMT ' 
	. $msg 
	. ' by '
	. $query->remote_user 
	. ' on ' 
	. $query->remote_host 
	. "\n";
    close(LOG);
    1;
}

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

VisSched - Perl extension for Visit-Day Scheduler

=head1 SYNOPSIS

  use VisSched;
  $descrip = visparse \@records;

=head1 DESCRIPTION

Stub documentation for VisSched, created by h2xs. It looks like the
author of the extension was negligent enough to leave the stub
unedited.

Blah blah blah.

=head2 EXPORT

None by default.



=head1 SEE ALSO

=head1 AUTHOR

Aaron A. King, E<lt>kingaa@umich.eduE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 by Aaron A. King

This library is free software; you can redistribute it and/or modify
it under the same terms as Perl itself, either Perl version 5.8.7 or,
at your option, any later version of Perl 5 you may have available.


=cut
