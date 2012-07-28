package Damail::JSONMaker::NetIMAPClient;
use strict;
use warnings;
use utf8;

use JSON;
use Net::IMAP::Client::MsgSummary;

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

