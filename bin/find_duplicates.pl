#!/usr/bin/env perl
use strict;
use warnings;
use feature qw( say );

use Digest::SHA;
use Getopt::Long;
use FindBin qw($Bin);
use File::Spec::Functions;
use Term::ANSIColor;

$|=1;
my $verbose;
my $no_color;
my @dirs;
my @exc;
my $exec;

GetOptions(
    "v|verbose" => \$verbose,
    "no-color" => \$no_color,
    "dir=s@" => \@dirs,
    "exclude=s@" => \@exc,
    "exec=s" => \$exec, # find style exec
);

my %seen;
my $width = 50;

for my $dir (@dirs) {
    traverse($dir);
}

show_dup();

say '='x$width;
say 'Done';
exit(0);

sub traverse {
    my $dir = shift;
    info(" --> processing dir [$dir]");

    opendir my $dh, $dir
        or die "Unable to open dir [$dir]; ERROR [$!]";
    FILE:
    while (my $file = readdir($dh)) {
        my $filepath = catfile($dir, $file);
        debug("Filepath [$filepath]");
        next FILE if (($file =~ /^\.\.?/ && -d $filepath) || (-l $filepath));

        if (@exc and grep(/\Q$filepath\E/, @exc)) {
            debug("SKIPed exclude [$filepath]");
            next FILE;
        }

        if (-d $filepath) {
            print "\n";
            traverse($filepath) unless exists $seen{$filepath};
            $seen{$filepath}=1;
            next FILE;
        }

        my $sha1 = Digest::SHA->new(1)->addfile($filepath);
        my $digest = $sha1->hexdigest();
        debug("Got digest [$digest]");

        unless (exists $seen{$digest}) {
            $seen{$digest} = [];
        } else {
            info(sprintf("file [$filepath] is dup of:\n\t%s\n", join("\n\t", @{ $seen{$digest} })));
            if ($exec) {
                my $tmpexec = $exec;
                my $bash_filepath = $filepath;
                $bash_filepath =~ s/([\s\(\)])/\\$1/g;
                $tmpexec =~ s/{}/$bash_filepath/g;
                run($tmpexec);
            }
        }
        push @{$seen{$digest}}, $filepath;
    }
}

sub run {
    my $cmd = shift;
    system($cmd) == 0 or die "Failted to run cmd [$cmd]";
    info("Ran cmd [$cmd]");
}

sub show_dup {
    say '';
    say '-'x$width;
    say 'Result';
    for my $dig (keys %seen) {
        say join("\n", '-'x$width, join("\n", @{$seen{$dig}}))
            if ref($seen{$dig}) eq 'ARRAY' and @{$seen{$dig}}>1;
    }
}

sub info {
    my $msg = shift;
    my $info = "[INFO] $msg\n";
    $info = $no_color ? $info : colored(['green'], $info);
    print $info;
}

sub debug {
    my $msg = shift;
    print STDERR "[DEBUG] $msg\n" if $ENV{FIND_DUP_DEBUG} || $verbose;
}

