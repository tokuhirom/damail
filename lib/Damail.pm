package Damail;
use strict;
use warnings;
use utf8;

use 5.010001;

our $VERSION = '0.01';

use Config::Pit;

use Net::IMAP::Client;
use Encode::IMAPUTF7;

use Damail::JSONMaker::DataPage;
use Damail::JSONMaker::NetIMAPClient;

sub create_client {
    my $conf = pit_get('damail', require => {
        'server' => 'imap server',
        user => 'user',
        pass => 'pass',
        ssl => 1,
        port => 993,
    });

    my $imap = Net::IMAP::Client->new(
        %$conf
    ) or die "Cannot connect to IMAP server";
    $imap->login or die "Cannot login: " . $imap->last_error;
    my @folders = $imap->folders;
    $imap->select('INBOX');
    return $imap;
}

1;

