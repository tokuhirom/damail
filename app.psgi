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
use Time::HiRes qw(gettimeofday tv_interval);

use Damail;

my $imap = Damail->create_client();

our $VERSION = '0.01';

# put your configuration here
sub load_config {
    my $c = shift;

    my $mode = $c->mode_name || 'development';

    +{ }
}

get '/' => sub {
    my $c = shift;
    return $c->render('index.tt');
};

get '/folders.json' => sub {
    my $c = shift;
    my @folders = $imap->folders;
    my $all = $imap->status(\@folders);
    my $res = $c->render_json({
        folders => [
            sort {
                sub {
                    return -1 if $a->{name} eq 'INBOX';
                    return  1 if $b->{name} eq 'INBOX';
                    return ($a->{UIDVALIDITY} || 0) <=> ($b->{UIDVALIDITY}||0);
                }->()
            }
            map {
                my $h = $all->{$_};
                $h->{origname} = $_;
                $h->{name} = decode('IMAP-UTF-7', $_);
                $h;
            }
            @folders
        ],
    });
    return $res;
};

get '/folder/messages.json' => sub {
    my $c = shift;
    my $folder_name = $c->req->param('folder_name') // die;

    infof("Trying to load folder: '%s'", $folder_name);
    my $t0 = [gettimeofday];

    $imap->select($folder_name);
    my $messages = $imap->search('ALL');
    if (!$messages) {
        croakf("[%s] %s", $folder_name, $imap->last_error);
    }

    my $page = 0+($c->req->param('page') || 1);
    my $limit = 0+($c->req->param('limit') || 1);
       $limit = 100 if $limit > 100;
    my $pager = Data::Page->new();
    $pager->total_entries(0+@$messages);
    $pager->entries_per_page($limit);
    $pager->current_page($page);

    my @messages = $pager->splice([reverse @{$messages}]);
    my $summary = $imap->get_summaries(\@messages, '');
    unless ($summary) {
        die $imap->last_error;
    }
    my $elapsed = tv_interval($t0, [gettimeofday]);
    infof("$elapsed seconds elapsed. Ready to response. Serialized it to JSON");
 #  use Data::Dumper; warn Dumper([
 #      reverse @$summary
 #  ]->[1]);
    return $c->render_json(+{
        pager => $pager->as_hashref,
        messages => [
            map { $_->as_hashref } reverse @$summary
        ]
    });
};

# this method rewrites '\\Seen' flag. so  it should be POST.
post '/message/show.json' => sub {
    my $c = shift;
    my $message_uid = $c->req->param('message_uid') or die;
    my $part_id = $c->req->param('part_id') || 1;
    my $transfer_encoding = $c->req->param('transfer_encoding') or die;
    my $message_charset = $c->req->param('message_charset') || 'utf-8';
    my $body = $imap->get_part_body($message_uid, $part_id);
       $body = $$body;
    if ($transfer_encoding ne 'null') {
       $body = Email::MIME::Encodings::decode($transfer_encoding, $body);
    }
       $body = decode($message_charset, $body);

    return $c->render_json({
        body => $body
    });
};

# load plugins
__PACKAGE__->load_plugin('Web::CSRFDefender');
__PACKAGE__->load_plugin('Web::JSON');

__PACKAGE__->enable_session();

__PACKAGE__->to_app(handle_static => 1);

