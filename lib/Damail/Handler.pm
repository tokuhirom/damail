use strict;
use warnings;
use utf8;
use autodie;

package Damail::Handler;

package Damail::Handler::Index {
    use parent qw(Tatsumaki::Handler);

    sub get {
        my $self = shift;
        open my $fh, '<', 'templates/index.mt';
        my $src = do { local $/; <$fh> };
        $self->write($src);
    }
}

package Damail::Handler::Folders {
    use parent qw(Damail::Handler::Base);
    use Damail::Util;
    use Data::Dumper;

    __PACKAGE__->asynchronous(1);

    sub get {
        my $self = shift;
        imap->folders->cb(sub {
            my ($ok, $folders) = shift->recv;
            $ok or $self->fail($folders);

            imap->status_multi($folders)->cb(sub {
                my ($ok, $status) = shift->recv;
                $ok or $self->fail($folders);

                $self->render_json(
                    {
                        folders => [
                            sort {
                                sub {
                                    return -1 if $a->{name} eq 'INBOX';
                                    return  1 if $b->{name} eq 'INBOX';
                                    return ($a->{UIDVALIDITY} || 0) <=> ($b->{UIDVALIDITY}||0);
                                }->()
                            }
                            map {
                                my $h = $status->{$_};
                                $h->{origname} = $_;
                                $h->{name} = decode_utf7($_);
                                $h;
                            }
                            @$folders
                        ],
                    }
                );
            });
        });
    }
}

package Damail::Handler::Folder::Messages {
    use parent qw(Damail::Handler::Base);
    use Log::Minimal;
    use List::Util qw/min/;
    use Mail::IMAP::Address;

    use Damail::Util;
    use Damail::IMAP;

    __PACKAGE__->asynchronous(1);

    sub get {
        my $self = shift;

        my $folder_name = $self->request->param('folder_name')
            or Tatsumaki::Error::HTTP->throw(403, 'folder_name missing');
        my $cv = Damail::IMAP->get_summary($folder_name);
        $cv->cb(sub {
            my ($ok, $messages) = shift->recv;
            $ok or return $self->fail($messages);

            my $data = [
                map {
                    Net::IMAP::Client::MsgSummary->new($_)->as_hashref
                } @{$messages}
            ];
            $self->render_json({
                messages => $data
            });
        });
    }
}

package Damail::Handler::Message::Show {
    use parent qw(Damail::Handler::Base);
    use Log::Minimal;
    use List::Util qw/min/;
    use Email::MIME::Encodings;
    use Encode;

    use Damail::Util;
    use Damail::IMAP;

    __PACKAGE__->asynchronous(1);

    sub post {
        my $self = shift;

        my $message_uid = $self->request->param('message_uid') or die;
        my $part_id = $self->request->param('part_id') || 1;
        my $transfer_encoding = $self->request->param('transfer_encoding') or die;
        my $message_charset = $self->request->param('message_charset') || 'utf-8';
        my $folder_name = $self->request->param('folder_name') || 'utf-8';

        $message_uid !~ /[\015\012]/ or die "Bad message id: $message_uid";
        $part_id =~ /^[0-9.]+$/ or die "Bad part_id: $part_id";

        infof("Fetching $message_uid, $part_id");
        my $select_cb = AE::cv();

        $select_cb->cb(sub {
            my ($ok) = shift->recv;
            $ok or return $self->fail;

            my ($tag, $cv) = imap->send_cmd("UID FETCH $message_uid BODY[$part_id]");
            $cv->cb(sub {
                my ($ok, $msg) = shift->recv;
                $ok or return $self->fail;

                shift @$msg;
                shift @$msg;
                pop @$msg;

                my $body = join "\n", @$msg;
                if ($transfer_encoding ne 'null') {
                    $body = Email::MIME::Encodings::decode($transfer_encoding, $body);
                }
                $body = decode($message_charset, $body);

                return $self->render_json({
                    body => $body
                });
            });
        });

        if (imap->{folder_name} ne $folder_name) {
            imap->select($folder_name)->cb(sub {
                $select_cb->send(shift->recv);
            });
        } else {
            $select_cb->send(1);
        }
    }
}

package Damail::Handler::Message::Archive {
    use parent qw(Damail::Handler::Base);
    use Log::Minimal;
    use List::Util qw/min/;
    use Email::MIME::Encodings;
    use Encode;

    use Damail::Util;
    use Damail::IMAP;

    __PACKAGE__->asynchronous(1);

    sub post {
        my $self = shift;

        my @message_uids = split(/,/, $self->request->param('message_uids'));
        unless (@message_uids) {
            die "Missing message_uids: " . Dumper($self->request);
        }

        # validation
        for (@message_uids) {
            $_ =~ /^[0-9]+$/ or die "Invalid message_uid: $_";
        }

        # TODO: use AE.
        my $imap = Damail->create_client();
        $imap->damail_archive(\@message_uids);

        return $self->render_json({
            message_uids => \@message_uids,
        });
    }
}

1;

