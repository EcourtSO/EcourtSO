use warnings;
use strict;
use Test::More tests => 23;
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

$dialog->set(
    'paper-formats',
    {
        new => {
            l => 0,
            y => 10,
            x => 10,
            t => 0,
        }
    }
);

$dialog->set( 'num-pages', 2 );

my $profile_changes = 0;
my ( $signal, $signal2 );
$signal = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect($signal);

        my $options = $dialog->get('available-scan-options');

        # v1.3.7 had the bug that profiles were not being saved properly,
        # due to the profiles not being cloned in the set and get routines

        # need a new main loop to avoid nesting
        my $loop1 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $loop1->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-x'), 10 );
        $loop1->run;

        my $loop2 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $loop2->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-y'), 10 );
        $loop2->run;

        $dialog->save_current_profile('profile 1');
        is_deeply(
            $dialog->{profiles}{'profile 1'}->get_data,
            {
                backend => [
                    {
                        'tl-x' => '10'
                    },
                    {
                        'tl-y' => '10'
                    },
                ]
            },
            'applied 1st profile'
        );
        is( $dialog->get('profile'),
            'profile 1', 'saving current profile sets profile' );

        my $loop3 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                $loop3->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-x'), 20 );
        $loop3->run;

        my $loop4 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {

                #                $flag = TRUE;
                $loop4->quit;
            }
        );
        $dialog->set_option( $options->by_name('tl-y'), 20 );
        $loop4->run;

        $dialog->save_current_profile('profile 2');
        is_deeply(
            $dialog->{profiles}{'profile 2'}->get_data,
            {
                backend => [
                    {
                        'tl-x' => '20'
                    },
                    {
                        'tl-y' => '20'
                    },
                ]
            },
            'applied 2nd profile'
        );
        is_deeply(
            $dialog->{profiles}{'profile 1'}->get_data,
            {
                backend => [
                    {
                        'tl-x' => '10'
                    },
                    {
                        'tl-y' => '10'
                    },
                ]
            },
            'applied 2nd profile without affecting 1st'
        );

        $dialog->remove_profile('profile 1');
        is_deeply(
            $dialog->{profiles}{'profile 2'}->get_data,
            {
                backend => [
                    {
                        'tl-x' => '20'
                    },
                    {
                        'tl-y' => '20'
                    },
                ]
            },
            'remove_profile()'
        );

        is $options->by_name('source')->{val}, 'Flatbed',
          'source defaults to Flatbed';
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages';
        is $dialog->{framen}->is_sensitive, FALSE, 'num-page gui ghosted';
        $dialog->set( 'num-pages', 2 );
        is $dialog->get('num-pages'), 1,
          'allow-batch-flatbed should force num-pages2';
        ok $options->flatbed_selected, 'flatbed_selected() via value';

        is $dialog->{vboxx}->get_visible, FALSE,
          'flatbed, so hide vbox for page numbering';

        $dialog->set( 'allow-batch-flatbed', TRUE );
        $dialog->set( 'num-pages',           2 );
        $signal = $dialog->signal_connect(
            'changed-num-pages' => sub {
                $dialog->signal_handler_disconnect($signal);
                is $dialog->get('num-pages'), 1,
                  'allow-batch-flatbed should force num-pages3';
                is $dialog->{framen}->is_sensitive, FALSE,
                  'num-page gui ghosted2';
            }
        );
        $dialog->set( 'allow-batch-flatbed', FALSE );

        # need a new main loop to avoid nesting
        my $loop5 = Glib::MainLoop->new;
        is $dialog->get('adf-defaults-scan-all-pages'), 1,
          'default adf-defaults-scan-all-pages';
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                if ( $option eq 'source' ) {
                    $dialog->signal_handler_disconnect($signal);
                    is $dialog->get('num-pages'), 0,
                      'adf-defaults-scan-all-pages should force num-pages';
                    is $options->flatbed_selected, FALSE,
                      'not flatbed_selected() via value';
                    $loop5->quit;
                }
            }
        );
        $dialog->set_option( $options->by_name('source'),
            'Automatic Document Feeder' );
        $loop5->run;

        # need a new main loop to avoid nesting
        my $loop6 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                $dialog->set( 'num-pages', 1 );
                $loop6->quit;
            }
        );
        $dialog->set_option( $options->by_name('source'), 'Flatbed' );
        $loop6->run;

        # need a new main loop to avoid nesting
        my $loop7 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                $dialog->signal_handler_disconnect($signal2);
                fail 'should not try to set invalid option';
                $loop7->quit;
            }
        );
        $signal2 = $dialog->signal_connect(
            'changed-current-scan-options' => sub {
                $dialog->signal_handler_disconnect($signal);
                $dialog->signal_handler_disconnect($signal2);
                $loop7->quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    'backend' => [ { 'mode' => 'Lineart' } ]
                }
            )
        );
        $loop7->run;

        # need a new main loop to avoid nesting
        my $loop8 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                $dialog->signal_handler_disconnect($signal2);
                fail 'should not try to set option if value already correct';
                $loop8->quit;
            }
        );
        $signal2 = $dialog->signal_connect(
            'changed-current-scan-options' => sub {
                $dialog->signal_handler_disconnect($signal);
                $dialog->signal_handler_disconnect($signal2);
                $loop8->quit;
            }
        );
        Glib::Idle->add(
            sub {
                $dialog->set_current_scan_options(
                    Gscan2pdf::Scanner::Profile->new_from_data(
                        {
                            'backend' => [ { 'mode' => 'Gray' } ]
                        }
                    )
                );
            }
        );
        $loop8->run;

        my $loop9 = Glib::MainLoop->new;
        $dialog->set( 'adf-defaults-scan-all-pages', 0 );
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);
                is $dialog->get('num-pages'), 1,
                  'adf-defaults-scan-all-pages should force num-pages 2';

                is $dialog->{vboxx}->get_visible, TRUE,
                  'simplex ADF, so show vbox for page numbering';

                $loop9->quit;
            }
        );
        $dialog->set_option( $options->by_name('source'),
            'Automatic Document Feeder' );
        $loop9->run;

        # bug in 2.5.3 where setting paper via default options only
        # set combobox without setting options
        my $loop10 = Glib::MainLoop->new;
        $signal = $dialog->signal_connect(
            'changed-paper' => sub {
                $dialog->signal_handler_disconnect($signal);
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            {
                                'tl-x' => '0'
                            },
                            {
                                'tl-y' => '0'
                            },
                            {
                                'br-x' => '10'
                            },
                            {
                                'br-y' => '10'
                            },
                        ],
                        frontend => {
                            'paper' => 'new'
                        },
                    },
                    'set paper with conflicting options'
                );
                $loop10->quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        {
                            'tl-x' => '20'
                        },
                        {
                            'tl-y' => '20'
                        },
                    ],
                    frontend => {
                        'paper' => 'new'
                    },
                },
            )
        );
        $loop10->run;

        # bug previous to v2.1.7 where having having set double sided and
        # reverse, and then switched from ADF to flatbed, clicking scan produced
        # the error message that the facing pages should be scanned first
        $loop10 = Glib::MainLoop->new;
        $dialog->set( 'side-to-scan', 'reverse' );
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->signal_handler_disconnect($signal);

                # if allow-batch-flatbed = FALSE
                is $dialog->get('sided'), 'single',
                  'selecting flatbed forces single sided';

                $loop10->quit;
            }
        );
        $dialog->set_option( $options->by_name('source'), 'Flatbed' );
        $loop10->run;

        # bug previous to v2.6.7 where changing a geometry option, thus setting
        # paper to Manual/undef was not respected when reloading options
        $signal = $dialog->signal_connect(
            'changed-scan-option' => sub {
                my ( $widget, $option, $value ) = @_;
                $dialog->set_paper;
            }
        );
        $signal = $dialog->signal_connect(
            'changed-paper' => sub {
                $dialog->signal_handler_disconnect($signal);
                is_deeply $dialog->get('current-scan-options')->get_data,
                  {
                    backend => [
                        {
                            'tl-x' => '0'
                        },
                        {
                            'tl-y' => '0'
                        },
                        {
                            'br-x' => '10'
                        },
                        {
                            'source' => 'Flatbed'
                        },
                        {
                            'br-y' => '9'
                        },
                    ],
                  },
                  'set Manual paper';

                Gtk3->main_quit;
            }
        );
        $dialog->set_option( $options->by_name('br-y'), 9 );
    }
);
$dialog->set( 'device', 'test' );
$dialog->scan_options;
Gtk3->main;

is( $dialog->{combobp}->get_num_rows,
    3, 'available paper reapplied after setting/changing device' );
is( $dialog->{combobp}->get_active_text,
    'Manual', 'paper combobox has a value' );

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
