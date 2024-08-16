#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Smart::Comments;

GetOptions(
    'd=s' => \my $openresty_dir,
    'branch=s' => \my $new_branch,
    'nginx-ver=s' => \my $nginx_ver,
    'git-pull' => \my $git_pull,
);

die "-d OPENRESTY_DIR is required but missing"
    unless $openresty_dir;
die "--branch NEW_BRANCH is required but missing"
    unless $new_branch;
die "--nginx-ver NGINX_VER is required but missing"
    unless $nginx_ver;

sub sh($);

my %repo_branch = (
    'luajit2' => 'v2.1-agentzh'
);

my $or_tag = 'HEAD';
my $remote = 'jiahao';
my $changes = 0;

my @lines = do {
    my $data;

    if ($or_tag ne 'HEAD') {
        $data = sh "git -C \"$openresty_dir\" "
                 . "show \"v$or_tag:util/mirror-tarballs\"";
    } else {
        my $fh;
        open $fh, "<", "$openresty_dir/util/mirror-tarballs"
            or die "$!";
        $data = do { local $/; <$fh> };
        close $fh;
    }

    split /\r?\n/, $data;
};

for (@lines) {
    if (!m{^#} && m{util/get-tarball "(https?://[^"]+)" -O "?([^\$]+)-\$ver}) {
        my ($repo, $name) = ($1, $2);

        # NB: https://people.freebsd.org/~osa/ngx_http_redis-$ver.tar.gz
        if ($name =~ m{^nginx|redis-nginx-module$}) {
            # $ver = undef;
            next;
        }

        my ($repo_addr) = $repo =~ m{^(https?://.*)/(archive|tarball)};
        my ($repo_name) = $repo_addr =~ m{/([^/]+)(?:.git)?$};

        if (!-d $repo_name) {
            die "Directory $repo_name does not exist\n";
        }

        my $cur_branch = sh "git -C $repo_name branch --show-current";
        my $is_clean = sh "git -C $repo_name status -s -u no";
        my $br = $repo_branch{$repo_name} // 'master';

        if ($cur_branch eq $br) {
            if ($git_pull) {
                sh "git -C $repo_name pull";
            }

            sh "git -C $repo_name checkout -b $new_branch";
        }

        if (!-f "$repo_name/.travis.yml") {
            warn "WARN: $repo_name does not have .travis.yml";
            next;
        }

        REPLACE: {
            my $replaced = 0;
            my %nginx_versions;

            open my $fh, "<", "$repo_name/.travis.yml"
                or die "cannot open $repo_name/.travis.yml for read: $!";
            while (<$fh>) {
                if (/NGINX_VERSION=(\d+\.\d+\.\d+)/) {
                    if ($1 eq $nginx_ver) {
                        $replaced = 1;
                    }
                    $nginx_versions{$1} = 1;
                }
            }
            close $fh;

            if (!%nginx_versions) {
                warn "WARN: $repo_name NGINX_VERSION not found\n";
                last REPLACE;
            }

            if ($replaced && $is_clean) {
                warn "WARN: $repo_name NGINX_VERSION already replaced\n";
                last REPLACE;
            }

            my $fileout;
            my $last_nginx_ver = (sort keys %nginx_versions)[-1];
            open $fh, "<", "$repo_name/.travis.yml"
                or die "cannot open $repo_name/.travis.yml for read: $!";
            while (<$fh>) {
                my $n = s/NGINX_VERSION=$last_nginx_ver/NGINX_VERSION=$nginx_ver/;
                $changes += $n;
                $fileout .= $_;
            }
            close $fh;

            open $fh, ">", "$repo_name/.travis.yml"
                or die "cannot open $repo_name/.travis.yml for write: $!";
            print $fh $fileout;
            close $fh;

            my $travis_clean = sh "git -C $repo_name status -s -u no .travis.yml";
            if ($travis_clean) {
                sh "git -C $repo_name add .travis.yml";
                sh "git -C $repo_name commit -m 'tests: bumped the NGINX core to $nginx_ver.'";
            }

            my $remote_diff = sh "git -C $repo_name diff $remote/$new_branch $new_branch";
            if ($remote_diff) {
                sh "git -C $repo_name push $remote $new_branch";

            } else {
                my $pr_url = sh "hub -C $repo_name prs || true";
                if ($pr_url) {
                    warn "PR already exists: $pr_url\n";

                } else {
                    $pr_url = sh "hub -C $repo_name pull-request -m 'tests: bumped the NGINX core to $nginx_ver.'";
                    warn "created PR: $pr_url\n";
                    # NB: wait for the PR to be created
                    sleep 1;

                    my $out = sh "git -C $repo_name diff $br";
                    warn "DIFF: $out\n";
                }
            }
        }
    }
}

if (!$changes) {
    warn "WARN: no changes made\n";
} else {
    warn "INFO: $changes changes made\n";
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
