package Damail::JSONMaker::NetIMAPClient;
use strict;
use warnings;
use utf8;

use JSON;
use Net::IMAP::Client::MsgSummary;
use Time::Piece;
use Log::Minimal;
use Time::HiRes qw(gettimeofday tv_interval);

# $msgids is simple message_id or arrayref of messages_ids
# There is no IMAP has no built in move command.
sub Net::IMAP::Client::damail_archive {
    my ($self, $msgids) = @_;

    my $t0 = [gettimeofday];

    my $archive_folder = $self->damail_find_or_create_archive_folder_name();
    infof("Archiving %s to %s", ddf($msgids), $archive_folder);

    infof('move messages from inbox to archive folder');
    $self->select('INBOX');
    $self->add_flags($msgids, ['\\Seen'])
        or croakf("Cannot add seen flag to %s: %s", ddf($msgids), $self->last_error);
    $self->copy($msgids, $archive_folder)
        or croakf("Cannot copy %s to %s: %s", ddf($msgids), ddf($archive_folder), $self->last_error);

    infof('and remove it from INBOX');
    $self->add_flags($msgids, '\\Deleted')
        or croakf("Cannot add deleted flags to %s: %s", ddf($msgids), $self->last_error);
    $self->expunge
        or croakf("Cannot expunge: %s", $self->last_error);
    my $elapsed = tv_interval($t0, [gettimeofday]);

    infof('done to archive. elapsed %s secs.', $elapsed);
}

sub Net::IMAP::Client::damail_find_or_create_archive_folder_name {
    my $self = shift;

    $self->{archive_folder_name} //= sub {
        my @folders = $self->folders;
        for (@folders) {
            return $_ if $_ eq '[Gmail]/All Mail';
        }

        my $default_archive = 'Archives/' . Time::Piece->new()->year;
        for (@folders) {
            return $_ if $_ eq $default_archive;
        }
        $self->create_folder($default_archive);
        return $default_archive;
    }->();
}

sub Net::IMAP::Client::MsgSummary::seen {
    my $self = shift;

    for my $flag (@{$self->flags || []}) {
        return 1 if uc($flag) eq '\\SEEN';
    }
    return 0;
}

# take a message meta data for first part.
sub Net::IMAP::Client::MsgSummary::damail_first_part {
    my $self = shift;

    if (ref($self->parts) eq 'ARRAY') {
        return $self->parts->[0]->damail_first_part;
    } else {
        return +{
            charset => $self->parameters ? $self->parameters->{charset} : 'utf-8',
            subtype => $self->{subtype},
            transfer_encoding => $self->{transfer_encoding},
        };
    }
}

sub Net::IMAP::Client::MsgSummary::as_hashref {
    my $self = shift;

    my $h = +{
        subject => $self->subject,
        seen => $self->seen,
        date => $self->date,
        uid => $self->uid,
        message_id => $self->message_id,
        from => [
            map {
                +{
                    name => $_->name,
                    email => $_->email,
                }
            }
            @{$self->from || []}
        ],
        to => [
            map {
                +{
                    name => $_->name,
                    email => $_->email,
                }
            }
            @{$self->to || []}
        ],
        first_part => $self->damail_first_part,
    };
    if (ref($self->parts) eq 'ARRAY') {
        $h->{parts} = [
            map {
                +{
                    part_id => $_->part_id,
                    subtype => $_->subtype,
                    transfer_encoding => $_->transfer_encoding,
                    parameters => $_->parameters,
                    uid => $_->uid,
                }
            } @{$self->parts || []}
        ];
    }
    for my $prop (qw(transfer_encoding subtype parameters)) {
        if ($self->$prop) {
            $h->{$prop} = $self->$prop;
        }
    }

    return $h;
}

1;

