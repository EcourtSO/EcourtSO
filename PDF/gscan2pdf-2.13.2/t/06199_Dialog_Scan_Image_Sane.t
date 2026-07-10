use warnings;
use strict;
use Test::More tests => 6;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
use Sub::Override;    # Override Frontend::Image_Sane to test functionality that
                      # we can't with the test backend
use Storable qw(freeze);    # For cloning the options cache

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger();

# The overrides must occur before the thread is spawned in setup.
my $override = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_get_devices' => sub {
        my ( $self, $uuid ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'get-devices',
                uuid    => $uuid,
                info    => freeze(
                    [
                        {
                            'name'  => 'mock_device',
                            'label' => 'mock_device'
                        }
                    ]
                ),
                status => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_open_device' => sub {
        my ( $self, $uuid, $device_name ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'open-device',
                uuid    => $uuid,
                info    => freeze( \$device_name ),
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_scan_page' => sub {
        my ( $self, $uuid, $path ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'scan-page',
                uuid    => $uuid,
                status  => SANE_STATUS_GOOD,
                info    => freeze( \$path ),
            }
        );
        return;
    }
);

my $options = [
    undef,
    {
        'title'      => 'Brightness',
        'desc'       => 'Controls the brightness of the acquired image.',
        'unit'       => 0,
        'cap'        => 13,
        'index'      => 1,
        'name'       => 'brightness',
        'constraint' => {
            'min'   => -100,
            'max'   => 100,
            'quant' => 1
        },
        'type'            => 1,
        'val'             => 0,
        'max_values'      => 1,
        'constraint_type' => 1
    },
    {
        'index'      => 2,
        'name'       => 'contrast',
        'constraint' => {
            'quant' => 1,
            'max'   => 100,
            'min'   => -100
        },
        'max_values'      => 1,
        'val'             => 0,
        'type'            => 1,
        'constraint_type' => 1,
        'title'           => 'Contrast',
        'desc'            => 'Controls the contrast of the acquired image.',
        'cap'             => 13,
        'unit'            => 0
    },
    {
        'name'            => 'resolution',
        'index'           => 3,
        'constraint'      => [600],
        'constraint_type' => 2,
        'max_values'      => 1,
        'val'             => 600,
        'type'            => 1,
        'desc'            => 'Sets the resolution of the scanned image.',
        'title'           => 'Scan resolution',
        'cap'             => 5,
        'unit'            => 4
    },
    {
        'max_values'      => 1,
        'type'            => 1,
        'val'             => 300,
        'constraint_type' => 2,
        'index'           => 4,
        'name'            => 'x-resolution',
        'constraint'      => [ 150, 225, 300, 600, 900, 1200 ],
        'cap'             => 69,
        'unit'            => 4,
        'title'           => 'X-resolution',
        'desc' => 'Sets the horizontal resolution of the scanned image.'
    },
    {
        'index'           => 5,
        'name'            => 'y-resolution',
        'constraint'      => [ 150, 225, 300, 600, 900, 1200, 1800, 2400 ],
        'val'             => 300,
        'type'            => 1,
        'max_values'      => 1,
        'constraint_type' => 2,
        'desc'  => 'Sets the vertical resolution of the scanned image.',
        'title' => 'Y-resolution',
        'unit'  => 4,
        'cap'   => 69
    },
    {
        'desc'            => '',
        'title'           => 'Geometry',
        'cap'             => 64,
        'unit'            => 0,
        'index'           => 6,
        'max_values'      => 1,
        'type'            => 5,
        'constraint_type' => 0
    },
    {
        'title' => 'Scan area',
        'desc'  => 'Select an area to scan based on well-known media sizes.',
        'unit'  => 0,
        'cap'   => 5,
        'index' => 7,
        'constraint' => [
            'Maximum', 'A4',     'A5 Landscape', 'A5 Portrait',
            'B5',      'Letter', 'Executive',    'CD'
        ],
        'name'            => 'scan-area',
        'val'             => 'Maximum',
        'type'            => 3,
        'max_values'      => 1,
        'constraint_type' => 3
    },
    {
        'unit'            => 3,
        'cap'             => 5,
        'title'           => 'Top-left x',
        'desc'            => 'Top-left x position of scan area.',
        'val'             => 0,
        'type'            => 2,
        'max_values'      => 1,
        'constraint_type' => 1,
        'name'            => 'tl-x',
        'index'           => 8,
        'constraint'      => {
            'min'   => 0,
            'max'   => '215.899993896484',
            'quant' => 0
        }
    },
    {
        'desc'       => 'Top-left y position of scan area.',
        'title'      => 'Top-left y',
        'cap'        => 5,
        'unit'       => 3,
        'constraint' => {
            'quant' => 0,
            'min'   => 0,
            'max'   => '297.179992675781'
        },
        'index'           => 9,
        'name'            => 'tl-y',
        'constraint_type' => 1,
        'max_values'      => 1,
        'type'            => 2,
        'val'             => 0
    },
    {
        'constraint_type' => 1,
        'max_values'      => 1,
        'type'            => 2,
        'val'             => '215.899993896484',
        'index'           => 10,
        'constraint'      => {
            'min'   => 0,
            'max'   => '215.899993896484',
            'quant' => 0
        },
        'name'  => 'br-x',
        'cap'   => 5,
        'unit'  => 3,
        'desc'  => 'Bottom-right x position of scan area.',
        'title' => 'Bottom-right x'
    },
    {
        'cap'             => 5,
        'unit'            => 3,
        'desc'            => 'Bottom-right y position of scan area.',
        'title'           => 'Bottom-right y',
        'max_values'      => 1,
        'type'            => 2,
        'val'             => '297.179992675781',
        'constraint_type' => 1,
        'index'           => 11,
        'constraint'      => {
            'min'   => 0,
            'max'   => '297.179992675781',
            'quant' => 0
        },
        'name' => 'br-y'
    },
    {
        'cap'   => 5,
        'unit'  => 0,
        'title' => 'Scan source',
        'desc'  => 'Selects the scan source (such as a document-feeder).',
        'constraint_type' => 3,
        'max_values'      => 1,
        'type'            => 3,
        'val'             => 'Flatbed',
        'index'           => 12,
        'constraint'      => [ 'Flatbed', 'Automatic Document Feeder' ],
        'name'            => 'source'
    },
];
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_get_options' => sub {
        my ( $self, $uuid ) = @_;
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'get-options',
                uuid    => $uuid,
                info    => freeze($options),
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        my $info = 0;
        if ( $index == 12 and $value = 'Automatic Document Feeder' ) {  # source
            $options->[10]{constraint}{max} = '215.899993896484';
            $options->[11]{constraint}{max} = '355.599990844727';
            $options->[10]{val}             = '215.899993896484';
            $options->[11]{val}             = '355.599990844727';
            $info                           = SANE_INFO_RELOAD_OPTIONS;
        }

        # x-resolution, y-resolution, scan-area
        elsif ( $index == 4 or $index == 5 or $index == 7 ) {
            $info = SANE_INFO_RELOAD_OPTIONS;
        }
        $options->[$index]{val} = $value;
        if ( $info & SANE_INFO_RELOAD_OPTIONS ) {
            Gscan2pdf::Frontend::Image_Sane::_thread_get_options( $self,
                $uuid );
        }
        else {
            $self->{return}->enqueue(
                {
                    type    => 'finished',
                    process => 'set-option',
                    uuid    => $uuid,
                    status  => SANE_STATUS_GOOD,
                }
            );
        }
        return;
    }
);

Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->{signal} = $dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        $dialog->set( 'device', 'mock_device' );
    }
);

$dialog->set( 'num-pages', 1 );
$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        my $loop = Glib::MainLoop->new;
        $dialog->{new_signal} = $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $path, $page_number, $xres, $yres ) = @_;
                unlink $path;
                $dialog->signal_handler_disconnect( $dialog->{new_signal} );
                is $xres, 300, 'x-resolution defaults';
                is $yres, 300, 'y-resolution defaults';
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    $loop->quit;
                }
            }
        );
        $dialog->scan;
        $loop->run;

        # wait for resolution option to propagate to current-scan-options before
        # scanning
        my $myoptions = $dialog->get('available-scan-options');
        $dialog->set_option( $myoptions->by_name(SANE_NAME_SCAN_RESOLUTION),
            600 );
        $loop = Glib::MainLoop->new;
        $dialog->signal_connect( 'changed-scan-option' => sub { $loop->quit } );
        $loop->run;

        $loop = Glib::MainLoop->new;
        $dialog->{new_signal} = $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $path, $page_number, $xres, $yres ) = @_;
                unlink $path;
                $dialog->signal_handler_disconnect( $dialog->{new_signal} );
                is $xres, 600, 'x from resolution';
                is $yres, 600, 'y from resolution';
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    $loop->quit;
                }
            }
        );
        $dialog->scan;
        $loop->run;

        # wait for resolution option to propagate to current-scan-options before
        # scanning
        $myoptions = $dialog->get('available-scan-options');
        $dialog->set_option( $myoptions->by_name('x-resolution'), 150 );
        $loop = Glib::MainLoop->new;
        $dialog->signal_connect( 'changed-scan-option' => sub { $loop->quit } );
        $loop->run;

        $loop = Glib::MainLoop->new;
        $dialog->{new_signal} = $dialog->signal_connect(
            'new-scan' => sub {
                my ( $widget, $path, $page_number, $xres, $yres ) = @_;
                unlink $path;
                $dialog->signal_handler_disconnect( $dialog->{new_signal} );
                is $xres, 150, 'x-resolution from profile';
                is $yres, 600, 'y-resolution from resolution';
            }
        );
        $dialog->signal_connect(
            'finished-process' => sub {
                my ( $widget, $process ) = @_;
                if ( $process eq 'scan_pages' ) {
                    Gtk3->main_quit;
                }
            }
        );
        $dialog->scan;
        $loop->run;
    }
);
$dialog->get_devices;

Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
