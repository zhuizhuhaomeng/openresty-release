use strict;
use warnings;
use Getopt::Std;
use Smart::Comments;

=begin
-ver=0.0.14
+ver=0.0.15rc1
 $root/util/get-tarball "https://github.com/openresty/stream-lua-nginx-module/tarball/v$ver" -O stream-lua-nginx-module-$ver.tar.gz || exit 1
 tar -xzf stream-lua-nginx-module-$ver.tar.gz || exit 1
 mv openresty-stream-lua-nginx-module-* ngx_stream_lua-$ver || exit 1
=cut

# find old version and new version from the patch file
# then, find the dirname from the mv command,
# save it to the hash, and print the hash

my $usage = "Usage: $0 -p patchfile -t testfile -i\n";
my %opts = ();
getopts('p:t:i', \%opts) or die $usage;

my $patch = $opts{p} or die $usage;
my $test = $opts{t} or die $usage;
my $inplace = $opts{i} || 0;

my %mods = ();
my $old_ver;
my $new_ver;
my $new_output;

# HERE's an excepted input, no mv command in the patch file
=begin
-ver=2.1.0.13
+ver=2.1.0.14
 $root/util/get-tarball "https://github.com/openresty/lua-cjson/archive/$ver.tar.gz" -O "lua-cjson-$ver.tar.gz" || exit 1
 tar -xzf lua-cjson-$ver.tar.gz || exit 1
=cut

open my $fh, '<', $patch or die "Cannot open $patch: $!";
my $tmpname;
while (<$fh>) {
    chomp;
    if (/^-ver=(.*)$/) {
        if ($old_ver) {
            $mods{$tmpname} = { old_ver => $old_ver, new_ver => $new_ver };
            undef $old_ver;
            undef $new_ver;
        }

        $old_ver = $1;
    }
    if (/^\+ver=(.*)$/) {
        $new_ver = $1;
    }
    if (/^\s*mv (?:\S+) (\S+?)\$ver \|\| exit 1$/) {
        $mods{$1} = { old_ver => $old_ver, new_ver => $new_ver };
        undef $old_ver;
        undef $new_ver;
    }

    # for lua-cjson
    if (/^\s*tar \S+ (\S+?)\$ver\.tar\.\S+ \|\| exit 1$/) {
        $tmpname = $1;
    }
}
close $fh;

# --add-module=../ngx_devel_kit-0.3.3 \
# find the [modname]-[old_ver] in the line, then replace it with [modname]-[new_ver]
open $fh, '<', $test or die "Cannot open $test: $!";
my $combined_pattern = join '|', map { quotemeta } keys %mods;
my $changes = 0;
while (<$fh>) {
    chomp;
    if (/($combined_pattern)/) {
        my $modname = $1;
        my $old_ver = $mods{$modname}{old_ver};
        my $new_ver = $mods{$modname}{new_ver};
        my $n = s/$modname$old_ver/$modname$new_ver/;
        $changes += $n;
    }
    $new_output .= "$_\n";
}
close $fh;

if ($inplace) {
    open my $fh, '>', $test or die "Cannot open $test: $!";
    print $fh $new_output;
    close $fh;
} else {
    print "Changes: $changes\n";
}
