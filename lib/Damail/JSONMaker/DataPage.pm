package Damail::JSONMaker::DataPage;
use strict;
use warnings;
use utf8;
use Data::Page;

sub Data::Page::as_hashref {
    my $self = shift;

    +{
        map { $_ => $self->$_ }
        qw(total_entries next_page)
    }
}

1;
