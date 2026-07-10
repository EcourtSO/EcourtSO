use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
    use Gscan2pdf::Document;
}

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);
Gscan2pdf::Document->setup($logger);

my $slist = Gscan2pdf::Document->new;
my $dir   = File::Temp->newdir;
$slist->set_dir($dir);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $path, $page_number, $xres, $yres ) = @_;
                $slist->import_scan(
                    page              => 1,
                    dir               => $dir,
                    to_png            => TRUE,
                    filename          => $path,
                    xresolution       => $xres,
                    yresolution       => $yres,
                    delete            => TRUE,
                    finished_callback => sub {
                        is -s "$slist->{data}[ 0 ][2]{filename}", 296,
                          'variable-height scan imported with expected size';
                        Gtk3->main_quit;
                    }
                );
            }
        );

        my $options = $dialog->get('available-scan-options');
        $dialog->set_option( $options->by_name('depth'), 1 );
    }
);
$dialog->signal_connect(
    'changed-scan-option' => sub {
        my ( $widget, $name, $value, $uuid ) = @_;
        my $options = $dialog->get('available-scan-options');
        if ( $name eq 'depth' ) {
            $dialog->set_option( $options->by_name('hand-scanner'), TRUE );
        }
        else {
            $dialog->scan;
        }
    }
);
$dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->set( 'device', 'test:0' );
    }
);
$dialog->set( 'device-list',
    [ { 'name' => 'test:0' }, { 'name' => 'test:1' } ] );
Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
Gscan2pdf::Document->quit();
__END__
