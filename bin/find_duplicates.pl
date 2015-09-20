#!/usr/bin/env perl
use strict;
use warnings;
use feature qw( say );

use Digest::SHA;
use Getopt::Long;
use FindBin qw($Bin);
use File::Spec::Functions;

my $verbose;
my $dir = '.';
my @exc;

GetOptions(
    "v|verbose" => \$verbose,
    "dir=s" => \$dir,
    "exclude=s@" => \@exc,
);

my %seen;
debug("dir [$dir]");

traverse($dir);
show_dup();

say 'Done';
exit(0);

sub traverse {
    my $dir = shift;
    debug("Looking for dup in dir [$dir]");

    opendir my $dh, $dir
        or die "Unable to open dir [$dir]; ERROR [$!]";
    FILE:
    while (my $file = readdir($dh)) {
        debug("file [$file]");
        next FILE if ($file =~ /^\.\.?/ and -d $file);

        my $filepath = catfile($dir, $file);
        debug("Filepath [$filepath]");
        if (@exc and grep(/\Q$filepath\E/, @exc)) {
            debug("SKIPed exclude [$filepath]");
            next FILE;
        }

        if (-d $filepath) {
            debug("file [$filepath] is dir");
            traverse($filepath);
            next;
        }

        my $sha1 = Digest::SHA->new(1)->addfile($filepath);
        my $digest = $sha1->hexdigest();
        debug("Got digest [$digest]");

        unless (exists $seen{$digest}) {
            $seen{$digest} = [];
        } else {
            debug(sprintf("file [$filepath] is dup of [%s]", join(', ', @{ $seen{$digest} })));
        }
        push @{$seen{$digest}}, $filepath;
    }
}

sub show_dup {
    for my $dig (keys %seen) {
        say "DUP => ".join(', ', @{$seen{$dig}}) if @{$seen{$dig}}>1;
    }
}

sub debug {
    my $msg = shift;
    print STDERR "[DEBUG] $msg\n" if $ENV{FIND_DUP_DEBUG} || $verbose;
}

