#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Std;
use Smart::Comments;

sub sh($);

getopts('f:lc', \my %opts);

my $file = delete $opts{f} # mirror-tarballs path in openresty/util/
    or die "please specifiy your mirror-tarballs path";
my $log = delete $opts{l}; # view git log since tag in current openresty
my $count = delete $opts{c}; # count git commits and compare the latest tag with current openresty

open my $fh, $file or die "cannot open $file for read: $!";

my $ver;
while (<$fh>) {
    chomp;

    my $line = $_;
    if (m{^ver=([v\d.-]+)}) {
        $ver = $1;
    }

    if (!m{^#} && m{util/get-tarball "(https?://[^"]+)" -O "?([^\$]+)-\$ver}) {
        my ($repo, $name) = ($1, $2);

        # NB: https://people.freebsd.org/~osa/ngx_http_redis-$ver.tar.gz
        if ($name =~ m{^nginx|redis-nginx-module$}) {
            $ver = undef;
            next;
        }

        my ($repo_addr) = $repo =~ m{^(https?://.*)/(archive|tarball)};
        my ($repo_name) = $repo_addr =~ m{/([^/]+)(?:.git)?$};

        if (-d $repo_name) {
            sh "cd $repo_name && git pull";
        } else {
            sh "git clone $repo_addr $repo_name";
        }

        my $latest_ver = sh "cd $repo_name && git describe --abbrev=0 --tags";

        my $pass = 1;
        if ($latest_ver !~ m{^v?$ver}) {
            printf "New Tag\t\t: %s: %.10s(new) vs %.10s\n", $name, $latest_ver, $ver;
            $pass = 0;
        }

        # real version
        my $tag = sh "cd $repo_name && TAG=\$(git tag -l v$ver); if [ -z \$TAG ]; then git tag -l $ver; else echo \$TAG; fi";

        my $commit_count = sh "cd $repo_name && git rev-list $latest_ver..HEAD --count";

        if ($commit_count > 0) {
            printf "New Commit\t: %s: %d commits since '$latest_ver'\n", $name, $commit_count;
            $pass = 0;
        }

        if ($commit_count > 0 && $log && $tag) {
            printf "------ diff log --------\n";
            printf "%s\n", sh "cd $repo_name && git log -p $tag..HEAD";
            printf "------ diff log end --------\n";
        }

        if ($pass) {
            printf "Pass\t\t: %s: latest!\n", $name;
        } else {
            printf "** Summary: check here $repo_addr\n";
        }

        printf "===================== END %.20s =================================\n", $name;
    }
}

sub sh ($) {
    warn "cmd: $_[0]";

    my $out = `$_[0]`;
    if ($?) {
        die "Failed to run command '$_[0]': ", $? >> 8, "\n";
    }

    chomp $out;
    return $out;
}
