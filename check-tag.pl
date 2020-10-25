#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Smart::Comments;

sub sh($);

my ($file, $show_log, $log_only, $count, $mods);

GetOptions(
    'f=s' => \$file,
    'm=s@' => \$mods, # module names
    'l' => \$show_log, # view git log since tag in current openresty
    'o' => \$log_only,
    'c' => \$count, # count git commits and compare the latest tag with current openresty
);

# mirror-tarballs path in openresty/util/
die "please specifiy your mirror-tarballs path"
    if !defined $file;

open my $fh, "<", $file or die "cannot open $file for read: $!";

my %repo_branch = (
    'luajit2' => 'v2.1-agentzh'
);

my $ver;
while (<$fh>) {
    chomp;

    my $line = $_;
    if (m{^ver=([v\d.-]+(rc\d+)?)}) {
        $ver = $1;
    }

    if (!m{^#} && m{util/get-tarball "(https?://[^"]+)" -O "?([^\$]+)-\$ver}) {
        my ($repo, $name) = ($1, $2);

        # NB: https://people.freebsd.org/~osa/ngx_http_redis-$ver.tar.gz
        if ($name =~ m{^nginx|redis-nginx-module$}) {
            $ver = undef;
            next;
        }

        if (defined($mods) && !grep {$name eq $_} @$mods) {
            next;
        }

        my ($repo_addr) = $repo =~ m{^(https?://.*)/(archive|tarball)};
        my ($repo_name) = $repo_addr =~ m{/([^/]+)(?:.git)?$};

        if (-d $repo_name) {
            my $branch = sh "git -C $repo_name branch --show-current";
            my $is_clean = sh "git -C $repo_name status -s -u no";
            my $br = $repo_branch{$repo_name} // 'master';

            if ($branch ne $br || $is_clean ne "") {
                warn "WARN: $repo_name br: $branch, clean: $is_clean";
                next;
            }
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

        if (($pass == 0) && ($show_log || $log_only) && $tag) {
            printf "------ diff log $repo_name --------\n";

            my $git_opt = $show_log ? "-p" : "--pretty=format:\"- %s -- %an\"";
            printf "%s\n", sh "cd $repo_name && git log $git_opt $tag..HEAD";

            printf "------ diff log end --------\n";
        }

        if ($pass) {
            printf "Pass\t\t: %s: latest!\n", $name;
        } else {
            printf "** Summary: check here $repo_addr\n";
        }

        printf "===================== END %.30s =================================\n", $name;
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
