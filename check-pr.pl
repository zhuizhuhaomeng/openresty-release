#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
use Smart::Comments;

sub sh($);

while (<>) {
    chomp;

    my $repo = $_;

    my $ci_status = sh "cd $repo && hub ci-status || true";
    my $br = sh "cd $repo && git br -q --show-current";

    printf "$repo: $ci_status\n";
    if ($ci_status eq 'failure') {
        system "cd $repo && gh pr checks -R openresty/$repo xiaocang:$br || true";
    }
}

sub sh ($) {
    # warn "cmd: $_[0]";

    my $out = `$_[0]`;
    if ($?) {
        die "Failed to run command '$_[0]': ", $? >> 8, "\n";
    }

    chomp $out;
    return $out;
}
