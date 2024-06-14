use warnings;
use strict;
use Test::More tests => 7;

BEGIN {
    use_ok('Gscan2pdf::Frontend::Image_Sane');
    use Gtk3;
}

#########################

Glib::set_application_name('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $path;
Gscan2pdf::Frontend::Image_Sane->open_device(
    device_name       => 'test',
    finished_callback => sub {
        Gscan2pdf::Frontend::Image_Sane->scan_pages(
            dir               => '.',
            npages            => 1,
            new_page_callback => sub {
                ( my $status, $path ) = @_;
                is( $status,  5,     'SANE_STATUS_GOOD' );
                is( -s $path, 30807, 'PNM created with expected size' );
            },
            finished_callback => sub {
                Gtk3->main_quit;
            },
        );
    }
);
Gtk3->main;

#########################

unlink $path;

Gscan2pdf::Frontend::Image_Sane->quit();

is( Gscan2pdf::Frontend::Image_Sane::decode_info(0), 'none', 'no info' );
is( Gscan2pdf::Frontend::Image_Sane::decode_info(1),
    'SANE_INFO_INEXACT', 'SANE_INFO_INEXACT' );
is(
    Gscan2pdf::Frontend::Image_Sane::decode_info(3),
    'SANE_INFO_RELOAD_OPTIONS + SANE_INFO_INEXACT',
    'combination'
);
is( Gscan2pdf::Frontend::Image_Sane::decode_info(11),
    '? + SANE_INFO_RELOAD_OPTIONS + SANE_INFO_INEXACT', 'missing' );
