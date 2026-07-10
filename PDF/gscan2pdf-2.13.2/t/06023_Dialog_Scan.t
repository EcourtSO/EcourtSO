use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->add_profile(
    'my profile',
    Gscan2pdf::Scanner::Profile->new_from_data(
        { backend => [ { 'resolution' => '100' } ] }
    )
);

my $signal;
$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal);

        my $options = $dialog->get('available-scan-options');

        # v2.3.0 had the bug that profiles were being applied on top of each
        # other, so if an unwanted option was selected, it was impossible to
        # deselect it. Make sure that options are reset before applying a
        # profile

        # need a new main loop to avoid nesting
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $dialog->signal_handler_disconnect($signal);
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-x'), 10 );
        $loop->run unless ($flag);

        $flag   = FALSE;
        $signal = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect($signal);
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [ { 'resolution' => '100' }, ],

                    },
                    'reset before applying profile'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'my profile' );
        $loop->run unless ($flag);
        Gtk3->main_quit;
    }
);
$dialog->set( 'device', 'test' );
$dialog->scan_options;
Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
