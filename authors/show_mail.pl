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
for (@ARGV) {
    my $msg = $imap->get_rfc822_body($_);
    print $$msg;
}

