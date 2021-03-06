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

use Class::Method::Modifiers qw(install_modifier);
use Log::Minimal;

install_modifier('Net::IMAP::Client', 'before', '_socket_write', sub {
    local $Log::Minimal::TRACE_LEVEL = $Log::Minimal::TRACE_LEVEL + 1;
    infof("[IMAP-SEND] %s", $_[1]);
});
install_modifier('Net::IMAP::Client', 'around', '_socket_getline', sub {
    my $code = shift;
    my $ret = $code->(@_);
    local $Log::Minimal::TRACE_LEVEL = $Log::Minimal::TRACE_LEVEL + 1;
    infof("[IMAP-RECV] %s", $ret);
    return $ret;
});

sub create_client {
    my $conf = pit_get('damail', require => {
        'imap_server' => 'imap server',
        imap_user => 'user',
        imap_pass => 'pass',
        imap_ssl => 1,
        imap_port => 993,
    });

    my $imap = Net::IMAP::Client->new(
        server => $conf->{imap_server},
        user   => $conf->{imap_user},
        pass   => $conf->{imap_pass},
        ssl    => $conf->{imap_ssl},
        port   => $conf->{imap_port},
    ) or die "Cannot connect to IMAP server";
    $imap->login or die "Cannot login: " . $imap->last_error;
    return $imap;
}

1;

