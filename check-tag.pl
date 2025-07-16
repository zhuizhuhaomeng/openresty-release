#!/usr/bin/perl
use strict;
use warnings;
use Getopt::Long;
use Smart::Comments;

sub sh($);

my ($openresty_dir, $show_log, $log_only, $count, $mods, $new_tag, $old_tag,
    $force_pull);

GetOptions(
    'd=s' => \$openresty_dir,
    'm=s@' => \$mods, # module names
    'l' => \$show_log, # view git log since tag in current openresty
    'o' => \$log_only,
    'c' => \$count, # count git commits and compare the latest tag with current openresty
    'old-tag=s' => \$old_tag,
    'new-tag=s' => \$new_tag,
    'force-pull|f' => \$force_pull,
);

$openresty_dir //= "openresty";
$new_tag //= "HEAD";

die "specifiy the --old-tag old tag for openresty"
    if !defined $old_tag;

# mirror-tarballs path in openresty/util/
die "please specifiy your mirror-tarballs path"
    if !-d $openresty_dir;

my %repo_branch = (
    'luajit2' => 'v2.1-agentzh'
);

my $pretty_format = 'format:"    * %s _Thanks %an for the patch._"';

sub git_tags ($;$);
sub git_diff ($$);
sub commits_since_tag ($$);

my $old_ref = git_tags($old_tag);
my $new_ref = git_tags($new_tag, $force_pull);
git_diff($old_ref, $new_ref);

sub git_tags ($;$) {
    my ($or_tag, $git_pull) = @_;

    my $tag_ref;

    # open my $fh, "<", $file or die "cannot open $file for read: $!";
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

    my $ver;
    for (@lines) {
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
                if ($git_pull) {
                    sh "git -C $repo_name pull";
                }
            } else {
                sh "git clone $repo_addr $repo_name";
            }

            # real version
            my $tag = sh "cd $repo_name && TAG=\$(git tag -l v$ver); if [ -z \$TAG ]; then git tag -l $ver; else echo \$TAG; fi";

            $tag_ref->{"[$repo_name]($repo_addr)"} = $tag;
        }
    }

    return $tag_ref;
}

sub git_diff ($$) {
    my ($old_ref, $new_ref) = @_;

    for my $k (keys %$old_ref) {
        my $otag = $old_ref->{$k};
        my $ntag = $new_ref->{$k};
        my ($repo_name) = $k =~ m{\[([^\[\]]+)\]};

        # NB: check commit since last tag
        if ($new_tag eq 'HEAD') {
            $ntag = sh "cd $repo_name && git describe --abbrev=0 --tags";

            commits_since_tag($repo_name, $ntag);
        }

        if ($otag ne $ntag) {
            warn "# New Tag: $repo_name: $ntag(new) vs $otag";
            printf "* upgraded $k to $ntag\n";

            my $git_opt = $show_log ? "-p" : "--pretty=$pretty_format";
            printf "%s\n", sh "git -C $repo_name log $git_opt $otag..$ntag | grep -E -v '(Merge branch|bumped|Bump copyright date|update nginx to|upgrade nginx to|travis-ci:|tests:)' | sort";

        } else {
            warn "# Pass: $repo_name: latest!";
        }
    }
}

sub commits_since_tag ($$) {
    my ($repo_name, $tag) = @_;

    my $commit_count = sh "git -C $repo_name rev-list $tag..HEAD --count";

    if ($commit_count > 0) {
        warn "# New Commit\t: $repo_name: $commit_count commits since '$tag'";
        printf "* $repo_name\t: new commits\n";
        my $git_opt = $show_log ? "-p" : "--pretty=$pretty_format";
        printf "%s\n", sh "git -C $repo_name log $git_opt $tag..HEAD | grep -E -v '(Merge branch|bumped|Bump copyright date|update nginx to|upgrade nginx to|travis-ci:|tests:)' | sort";
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
