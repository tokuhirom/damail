package Damail::IMAP;
use strict;
use warnings;
use utf8;
use Log::Minimal;
use AE;
use List::Util qw/min/;
use Mail::IMAP::Envelope;
use Net::IMAP::Client::MsgSummary;

use Damail::Util;

sub get_summary {
    my ($class, $folder_name) = @_;

    my $cv = AE::cv();

    imap->status($folder_name)->cb(sub {
        my ($ok, $status) = shift->recv;
        $ok or return $cv->send(0, 'Cannot get status');

        if ($status->{MESSAGES} > 0) {
            imap->select($folder_name)->cb(sub {
                my ($ok) = shift->recv;
                infof("Selected.");
                $ok or return $cv->send(0, "Cannot select $folder_name");

                my $limit = min(50, $status->{MESSAGES});
                imap->fetch("1:$limit (UID FLAGS INTERNALDATE RFC822.SIZE ENVELOPE BODYSTRUCTURE)")->cb(sub {
                    my ($ok, $messages) = shift->recv;
                    $ok or return $cv->send(0, "Cannot fetch");

                    $cv->send(1, $messages);
                });
            });
        } else {
            $cv->send(1, []);
        }
    });

    return $cv;
}

1;

