package Damail::Util;
use strict;
use warnings;
use utf8;

use parent qw(Exporter);

our @EXPORT = qw(imap decode_utf7 p);
use Encode ();
use Data::Dumper;

sub imap() { $Damail::IMAP }
sub decode_utf7 { Encode::decode('IMAP-UTF-7', $_[0]) }
sub p($) { warn Dumper(@_) }

1;

