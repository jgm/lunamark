#!/usr/bin/env perl -w

use IPC::Open2;
use HTML::Tidy;
use Text::Diff;
use Term::ANSIColor;
use Getopt::Std;
use Pod::Usage;
use File::Find;
use Benchmark;
use warnings;

my %options = ();
getopts("citd:w:", \%options) or pod2usage(-verbose => 1) && exit;

$cmdsub = $options{w} || undef;
$colors = $options{c};
$testdir = $options{d} || "tests";
$usetidy = $options{t};
$ignoreblanklines = $options{i};
@patterns = @ARGV;


$tidy = HTML::Tidy->new( { output_xhtml => 1,
                           tidy_mark => 0,
                           show_body_only => 1
                         } );

my $time_start = new Benchmark;

my $failures = 0;
my $passes   = 0;

@tests = ();
find(\&wanted, ($testdir));

foreach (@tests) {
  process($_);
}

my $time_end = new Benchmark;
my $time_diff = timediff($time_end, $time_start);

print "Passed:  ", $passes, " tests\n";
print "Failed:  ", $failures, " tests\n";
print "Time:   ", timestr($time_diff), "\n";

exit($failures);

# end of main program

sub wanted {
  my $fn = $File::Find::name;
  ($fn =~ /\.test$/) || return;
  foreach (@patterns) {
    ($fn =~ $_) || return;
  };
  push(@tests, $fn);
}

sub process {
    my $fn = $_;
    my $result = runtest($fn);
    my $ok = ($result =~ /^$/);
    if ($ok) {
      $passes += 1;
      if ($colors) {
        print colored ("[OK]     ", "yellow");
      } else {
        print "[OK]     ";
      }
      print $fn, "\n";
    } else {
      $failures += 1;
      if ($colors) {
        print colored ("[FAILED] ", "red");
      } else {
        print "[FAILED] ";
      }
      print $fn, "\n";
      if ($colors) {
        print colored ($result, "cyan");
      } else {
        print $result;
      }
    }
}

sub runtest {
  my $f = $_[0];
  open(FILE, $f) or die "Can't read file '$f'\n";

  my $cmd = <FILE>;
  $cmd =~ s/[^ ]*/$cmdsub/ if defined $cmdsub;
  while (<FILE>) {
    if ($_ =~ /^<<< *$/) { last; }
  }

  my($outstream, $instream);
  open2($outstream, $instream, $cmd);

  while (<FILE>) {
    if ($_ =~ /^>>> *$/) {
      close $instream;
      last;
    } else {
      print $instream $_;
    }
  }

  my $expected = "";
  while (<FILE>) {
    $expected .= $_;
  }

  my $actual = "";
  while (<$outstream>) {
    $actual .= $_;
  }
  close $outstream;

  if ($usetidy) {
    $expected = $tidy->clean($expected);
    $actual = $tidy->clean($actual);
  }

  if ($ignoreblanklines) {
    $expected =~ s/\n\n*/\n/g;
    $actual =~ s/\n\n*/\n/g;
  }

  my $diff = diff \$expected, \$actual;

  return $diff;
}

__END__

=pod

=head1 NAME

B<shtest>


=head1 SYNOPSIS

B<shtest.pl> [ B<options> ]  [ I<pattern> ... ]

=head1 DESCRIPTION

Runs tests in the 'tests' directory (or another directory specified
using B<-d>).  Tests are contained in files with the '.test' extension.
The first line of the test is the command line.  Standard input
follows a line containing '<<<', and expected output follows a line
containing '>>>'.

Only tests that match all of the (regex) patterns will be run.

=head1 OPTIONS

=over 4

=item B<-w>

Specify the path to the program to test.  The first word of
the command line specified in each test will be replaced by this path.

=item B<-c>

Use ANSI colors in output.

=item s<-c>

Run output through tidy.

=item B<-d>

Specify directory containing tests (default = tests).

=back

=head1 BUGS

=head1 VERSION HISTORY

1.0	Tue 06 Jun 2011

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2011 John MacFarlane

This is free software; you may redistribute it and/or modify it under
the same terms as Perl itself.

=cut
