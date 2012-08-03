use strict;
use warnings;
use utf8;
use File::Spec;
use File::Basename;
use lib File::Spec->catdir(dirname(__FILE__), 'extlib', 'lib', 'perl5');
use lib File::Spec->catdir(dirname(__FILE__), 'lib');
use Amon2::Lite;
use Encode;
use Data::Page;
use Config::Pit;
use JSON;
use Email::MIME::Encodings;
use Encode;
use Log::Minimal;
use Data::Dumper;
use Time::HiRes qw(gettimeofday tv_interval);


use Damail;
use Damail::Handler;

use Tatsumaki;
use AnyEvent::IMAP;
use Tatsumaki::Application;
use Twiggy::Server;

my $load_cv = AE::cv();

my $imap = Damail->create_client_ae();
$imap->reg_cb(
    connect => sub {
        infof("Connected. Trying to login");
        $imap->login()->cb(sub {
            my ($ok) = @_;
            $ok or die "Cannot logged in to the IMAP server.";
            infof("Logged in.");
            $Damail::IMAP = $imap;
            $load_cv->send;
        });
    },
    send => sub {
        debugf("SEND: %s", $_[1]);
    },
    recv => sub {
        debugf("RECV: %s", $_[1]);
    },
    disconnect => sub {
        my ($self, $reason) = @_;
        warnf("Disconnected. %s", $reason);
        $self->connect();
    },
);

# send ping
my $timer = AE::timer(60, 60, sub {
    infof("send ping");
    $imap->noop
});

infof("connect to the server");
my ($tag, $cv) = $imap->connect();
infof("waiting login");
warn $load_cv->recv;

infof("OK.");

use Plack::Builder;
use Getopt::Long;

my $host = '127.0.0.1';
my $port = 2828;
GetOptions(
    host => \$host,
    port => \$port,
);

my $tatsumaki = Tatsumaki::Application->new(
    [
        '/'                     => 'Damail::Handler::Index',
        '/folders.json'         => 'Damail::Handler::Folders',
        '/folder/messages.json' => 'Damail::Handler::Folder::Messages',
        '/message/show.json'    => 'Damail::Handler::Message::Show',
        '/message/archive.json' => 'Damail::Handler::Message::Archive',
    ]
);
my $app = builder {
    enable 'Plack::Middleware::AccessLog::Timed';
    enable 'Plack::Middleware::Static',
        path => qr{^/static/}, root => './';

    $tatsumaki->psgi_app;
};

# setting up twiggy
my $twiggy = Twiggy::Server->new(
    host => $host,
    port => $port,
);
$twiggy->register_service($app);

infof("Server is ready. Please access to http://%s:%s/", $host, $port);

AE::cv->recv;

