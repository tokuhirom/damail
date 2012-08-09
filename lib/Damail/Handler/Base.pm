use strict;
use warnings;
use utf8;

package Damail::Handler::Base {
    use parent qw(Tatsumaki::Handler);
    use JSON ();
    use Log::Minimal;

    my $json = JSON->new->ascii;

    sub render_json {
        my ($self, $data) = @_;

        $self->response->content_type('application/json; charset=utf-8');
        $self->write($data);
        $self->finish;
    }

    sub fail {
        my $self = shift;
        local $Log::Minimal::TRACE_LEVEL = $Log::Minimal::TRACE_LEVEL + 1;
        warnf("%s", @_);
        $self->condvar->croak(Tatsumaki::Error::HTTP->new(500, @_));
    }
}

1;