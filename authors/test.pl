#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;
use Damail;

my $imap = Damail->create_client();
my $archive_folder = $imap->damail_find_or_create_archive_folder_name();
say($archive_folder);
if (@ARGV) {
    $imap->damail_archive(\@ARGV);
}

