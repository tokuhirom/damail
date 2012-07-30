#!/usr/bin/perl
use strict;
use warnings;
use utf8;
use 5.010000;
use autodie;
use File::Spec;
use File::Basename;
use lib File::Spec->rel2abs(File::Spec->catfile(dirname(__FILE__), '..', 'lib'));

use Damail;

# Archive all mails in INBOX.

my $imap = Damail->create_client();
$imap->select('INBOX');
my $messages = $imap->search('ALL');
for (@$messages) {
    $imap->damail_archive($_);
}

