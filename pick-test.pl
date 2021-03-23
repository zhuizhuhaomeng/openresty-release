#!/usr/bin/env perl
use strict;
use warnings;
# use Smart::Comments;
use Getopt::Std;

sub sh ($);
sub parse_t ($$);

my %opts;
getopts('fd:', \%opts) or die;

my $old_t_dir = 't';
my $new_t_dir = $opts{d} // 't2';

my $force = $opts{f};

if ($force) {
    sh "rm -rf './$new_t_dir'";
}

if ( !-d "$new_t_dir" ) {
    sh "mkdir -p '$new_t_dir'";
}

sh "rsync -a --filter '+ **.pm' --filter '- *.t' --filter '- servroot' '$old_t_dir/' '$new_t_dir/'";

my %all_blocks;

while (<>) {
    chomp;
    my $line = $_;
    next if $line =~ /^\s*#/;
    my ($file, $block) = split(/:/, $line);

    if ( $block =~ m/TEST (\d+)/ ) {
        push @{ $all_blocks{$file} }, $1;

    } elsif ($block =~ m/\s*\*/) {
        push @{ $all_blocks{$file} }, '*';

    } else {
        die "failed to parse block '$block' in '$line'";
    }
}

while ( my ( $file, $pick_blocks ) = each %all_blocks ) {
    my $output = parse_t $file, $pick_blocks;
    next unless $output;

    my $new_t = "$new_t_dir/$file";

    my $fh;
    open $fh, ">", $new_t or die "$new_t: $!";
    print $fh $output;
    close $fh;
}

sub hit_blk ($$) {
    my ($blk, $blks) = @_;

    for my $b (@$blks) {
        if ($b eq '*') {
            return 1;
        }

        if ($b eq $blk) {
            return 1;
        }
    }

    return;
}

sub parse_t ($$) {
    my ($fn, $blks) = @_;
    my $fh;
    open $fh, "<", "$old_t_dir/$fn" or die $!;

    my @content;
    my %block;
    my $data_found;
    my $block_found;
    my $section_found;

    while (<$fh>) {
        chomp;
        if (/^__DATA__$/) {
            $data_found = 1;
            next;
        }

        if ($data_found) {
            if (/^=== TEST (\d+)/) {
                $block_found = $1;

                push @{$block{$block_found}}, $_
                    if hit_blk($block_found, $blks);
                next;
            }

            elsif (/^=== /) {
                die "failed to parse block";
            }

            if ($block_found && hit_blk($block_found, $blks) ) {
                push @{$block{$block_found}}, $_;
            }
        }
        else {
            push @content, $_;
        }
    }

    close $fh;

    my @test_block;
    for my $blk (sort { $a <=> $b } keys %block) {
        push @test_block, @{$block{$blk}};
    }

    return join("\n", @content) . "\n__DATA__\n"
         . join("\n", @test_block) . "\n";
}

sub sh ($) {
    my $cmd = shift;
    # warn $cmd;
    system($cmd) == 0
        or die "failed to exec cmd: $cmd ", $? >> 8, "\n";
}
