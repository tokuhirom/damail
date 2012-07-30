#!/usr/bin/env perl
use strict;
use warnings;
use utf8;
use 5.010000;
use File::Spec;
use File::Basename;
use lib File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'lib'));
use autodie;
use Damail;
use Data::Dumper;

my $imap = Damail->create_client();
say("folders: " . Dumper([$imap->folders]));
my $archive_folder = $imap->damail_find_or_create_archive_folder_name();
say("Archive folder: $archive_folder");
if (@ARGV) {
    $imap->damail_archive(\@ARGV);
}

