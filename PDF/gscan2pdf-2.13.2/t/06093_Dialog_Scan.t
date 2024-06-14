use warnings;
use strict;
use Test::More tests => 5;
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
my $logger = Log::Log4perl::get_logger;

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

my $raw_options = [
    undef,
    {
        'cap'             => 5,
        'constraint'      => [ 'ADF', 'Document Table' ],
        'constraint_type' => 3,
        'desc'            => 'Document Source',
        'index'           => 2,
        'max_values'      => 1,
        'name'            => 'source',
        'title'           => 'Document Source',
        'type'            => 3,
        'unit'            => 0,
        'val'             => 'Document Table'
    },
    {
        'cap'             => 100,
        'constraint_type' => 0,
        'desc'            =>
'This option provides the user with a wider range of supported resolutions.  Resolutions not supported by the hardware will be achieved through image processing methods.',
        'index'      => 3,
        'max_values' => 1,
        'name'       => 'enable-resampling',
        'title'      => 'Enable Resampling',
        'type'       => 0,
        'unit'       => 0
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => 1200,
            'min'   => 50,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Resolution',
        'index'           => 4,
        'max_values'      => 1,
        'name'            => 'resolution',
        'title'           => 'Resolution',
        'type'            => 1,
        'unit'            => 4,
        'val'             => 75
    },
    {
        'cap'             => 69,
        'constraint_type' => 0,
        'desc'            => 'Bind X and Y resolutions',
        'index'           => 5,
        'max_values'      => 1,
        'name'            => 'resolution-bind',
        'title'           => 'Bind X and Y resolutions',
        'type'            => 0,
        'unit'            => 0,
        'val'             => 1
    },
    {
        'cap'        => 68,
        'constraint' => {
            'max'   => 1200,
            'min'   => 50,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'X Resolution',
        'index'           => 6,
        'max_values'      => 1,
        'name'            => 'x-resolution',
        'title'           => 'X Resolution',
        'type'            => 1,
        'unit'            => 4,
        'val'             => 75
    },
    {
        'cap'        => 68,
        'constraint' => {
            'max'   => 1200,
            'min'   => 50,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Y Resolution',
        'index'           => 7,
        'max_values'      => 1,
        'name'            => 'y-resolution',
        'title'           => 'Y Resolution',
        'type'            => 1,
        'unit'            => 4,
        'val'             => 75
    },
    {
        'cap'        => 5,
        'constraint' => [
            'Executive/Portrait', 'ISO/A4/Portrait',
            'ISO/A5/Portrait',    'ISO/A5/Landscape',
            'ISO/A6/Portrait',    'ISO/A6/Landscape',
            'JIS/B5/Portrait',    'JIS/B6/Portrait',
            'JIS/B6/Landscape',   'Letter/Portrait',
            'Manual',             'Maximum'
        ],
        'constraint_type' => 3,
        'desc'            => 'Scan Area',
        'index'           => 8,
        'max_values'      => 1,
        'name'            => 'scan-area',
        'title'           => 'Scan Area',
        'type'            => 3,
        'unit'            => 0,
        'val'             => 'Manual'
    },
    {
        'cap'             => 13,
        'constraint'      => [ 'Monochrome', 'Grayscale', 'Color' ],
        'constraint_type' => 3,
        'desc'            => 'Image Type',
        'index'           => 9,
        'max_values'      => 1,
        'name'            => 'mode',
        'title'           => 'Image Type',
        'type'            => 3,
        'unit'            => 0,
        'val'             => 'Color'
    },
    {
        'cap'             => 32,
        'constraint_type' => 0,
        'desc'            => 'Scan area and image size related options.',
        'index'           => 10,
        'max_values'      => 0,
        'name'            => 'device-03-geometry',
        'title'           => 'Geometry',
        'type'            => 5,
        'unit'            => 0
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => '215.899993896484',
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Bottom Right X',
        'index'           => 11,
        'max_values'      => 1,
        'name'            => 'br-x',
        'title'           => 'Bottom Right X',
        'type'            => 2,
        'unit'            => 3,
        'val'             => '215.899993896484'
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => '297.179992675781',
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Bottom Right Y',
        'index'           => 12,
        'max_values'      => 1,
        'name'            => 'br-y',
        'title'           => 'Bottom Right Y',
        'type'            => 2,
        'unit'            => 3,
        'val'             => '297.179992675781'
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => '215.899993896484',
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Top Left X',
        'index'           => 13,
        'max_values'      => 1,
        'name'            => 'tl-x',
        'title'           => 'Top Left X',
        'type'            => 2,
        'unit'            => 3,
        'val'             => 0
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => '297.179992675781',
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Top Left Y',
        'index'           => 14,
        'max_values'      => 1,
        'name'            => 'tl-y',
        'title'           => 'Top Left Y',
        'type'            => 2,
        'unit'            => 3,
        'val'             => 0
    },
    {
        'cap'             => 32,
        'constraint_type' => 0,
        'desc'            => 'Image modification options.',
        'index'           => 15,
        'max_values'      => 0,
        'name'            => 'device-04-enhancement',
        'title'           => 'Enhancement',
        'type'            => 5,
        'unit'            => 0
    },
    {
        'cap'        => 13,
        'constraint' =>
          [ '0 degrees', '90 degrees', '180 degrees', '270 degrees', 'Auto' ],
        'constraint_type' => 3,
        'desc'            => 'Rotate',
        'index'           => 16,
        'max_values'      => 1,
        'name'            => 'rotate',
        'title'           => 'Rotate',
        'type'            => 3,
        'unit'            => 0,
        'val'             => '0 degrees'
    },
    {
        'cap'        => 13,
        'constraint' => {
            'max'   => 100,
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Skip Blank Pages Settings',
        'index'           => 17,
        'max_values'      => 1,
        'name'            => 'blank-threshold',
        'title'           => 'Skip Blank Pages Settings',
        'type'            => 2,
        'unit'            => 0,
        'val'             => 0
    },
    {
        'cap'        => 13,
        'constraint' => {
            'max'   => 100,
            'min'   => -100,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Change brightness of the acquired image.',
        'index'           => 18,
        'max_values'      => 1,
        'name'            => 'brightness',
        'title'           => 'Brightness',
        'type'            => 1,
        'unit'            => 0,
        'val'             => 0
    },
    {
        'cap'        => 13,
        'constraint' => {
            'max'   => 100,
            'min'   => -100,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Change contrast of the acquired image.',
        'index'           => 19,
        'max_values'      => 1,
        'name'            => 'contrast',
        'title'           => 'Contrast',
        'type'            => 1,
        'unit'            => 0,
        'val'             => 0
    },
    {
        'cap'        => 13,
        'constraint' => {
            'max'   => 255,
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Threshold',
        'index'           => 20,
        'max_values'      => 1,
        'name'            => 'threshold',
        'title'           => 'Threshold',
        'type'            => 1,
        'unit'            => 0,
        'val'             => 128
    },
    {
        'cap'             => 32,
        'constraint_type' => 0,
        'desc'            => '',
        'index'           => 21,
        'max_values'      => 0,
        'name'            => 'device--',
        'title'           => 'Other',
        'type'            => 5,
        'unit'            => 0
    },
    {
        'cap'             => 69,
        'constraint'      => [ '1.0', '1.8' ],
        'constraint_type' => 3,
        'desc'            => 'Gamma',
        'index'           => 22,
        'max_values'      => 1,
        'name'            => 'gamma',
        'title'           => 'Gamma',
        'type'            => 3,
        'unit'            => 0,
        'val'             => '1.8'
    },
    {
        'cap'        => 101,
        'constraint' => {
            'max'   => 999,
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Image Count',
        'index'           => 23,
        'max_values'      => 1,
        'name'            => 'image-count',
        'title'           => 'Image Count',
        'type'            => 1,
        'unit'            => 0
    },
    {
        'cap'        => 69,
        'constraint' => {
            'max'   => 100,
            'min'   => 1,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'JPEG Quality',
        'index'           => 24,
        'max_values'      => 1,
        'name'            => 'jpeg-quality',
        'title'           => 'JPEG Quality',
        'type'            => 1,
        'unit'            => 0,
        'val'             => 90
    },
    {
        'cap'             => 5,
        'constraint'      => [ 'JPEG', 'RAW' ],
        'constraint_type' => 3,
        'desc'            =>
'Selecting a compressed format such as JPEG normally results in faster device side processing.',
        'index'      => 25,
        'max_values' => 1,
        'name'       => 'transfer-format',
        'title'      => 'Transfer Format',
        'type'       => 3,
        'unit'       => 0,
        'val'        => 'RAW'
    },
    {
        'cap'        => 69,
        'constraint' => {
            'max'   => 268435455,
            'min'   => 1,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Transfer Size',
        'index'           => 26,
        'max_values'      => 1,
        'name'            => 'transfer-size',
        'title'           => 'Transfer Size',
        'type'            => 1,
        'unit'            => 0,
        'val'             => 1048576
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
                info    => freeze($raw_options),
                status  => SANE_STATUS_GOOD,
            }
        );
        return;
    }
);

# An Epson ET-4750 was triggering the reload-recursion-limit on setting br-x and
# -y it was triggering a reload, and the reloaded values were outside the
# tolerance.
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        my $opt    = $raw_options->[$index];
        my $status = 0;
        my $info   = 0;
        if (   ( $opt->{name} eq 'br-x' and $value == 216 )
            or ( $opt->{name} eq 'br-y' and $value == 279 ) )
        {
            if ( $opt->{name} eq 'br-x' ) {
                $opt->{val} = 215.899993896484;
            }
            else {
                $opt->{val} = 279.399993896484;
            }
            $info =
              21936 + SANE_INFO_RELOAD_PARAMS +
              SANE_INFO_RELOAD_OPTIONS +
              SANE_INFO_INEXACT;

            $logger->info(
                    "sane_set_option $index ($opt->{name})"
                  . " to $value returned status $status ("
                  . Image::Sane::strstatus($status)
                  . ') with info '
                  . (
                    defined $info
                    ? sprintf( '%d (%s)',
                        $info,
                        Gscan2pdf::Frontend::Image_Sane::decode_info($info) )
                    : 'undefined'
                  )
            );
        }
        else {
            $raw_options->[$index]{val} = $value;
        }
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'set-option',
                uuid    => $uuid,
                status  => $status,
                info    => $info,
            }
        );
        return;
    }
);

Gscan2pdf::Frontend::Image_Sane->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::Image_Sane->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);

$dialog->add_profile(
    'my profile',
    Gscan2pdf::Scanner::Profile->new_from_data(
        {
            backend => [
                {
                    'scan-area' => 'Letter/Portrait'
                },
                {
                    'br-x' => 216
                },
                {
                    'br-y' => 279
                },
            ],
        }
    )
);

$dialog->{signal} = $dialog->signal_connect(
    'changed-device-list' => sub {
        $dialog->signal_handler_disconnect( $dialog->{signal} );
        $dialog->set( 'device', 'mock_device' );
    }
);

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        ######################################

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-profile' => sub {
                my ( $widget, $profile ) = @_;
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is( $profile, 'my profile', 'changed-profile' );

                # br-x is not 216 because the max is 215.899993896484
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            {
                                'scan-area' => 'Letter/Portrait'
                            },
                            {
                                'br-x' => 215.899993896484
                            },
                            {
                                'br-y' => 279
                            },
                        ],

                    },
                    'current-scan-options with profile'
                );
                my $options = $dialog->get('available-scan-options');
                is( $options->by_name('br-x')->{val},
                    215.899993896484, 'br-x value' );
                is( $options->by_name('br-y')->{val},
                    279.399993896484, 'br-y value' );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'profile', 'my profile' );
        $loop->run unless ($flag);
        Gtk3->main_quit;
    }
);
$dialog->get_devices;

Gtk3->main;
ok $dialog->get('num-reloads') < 5, "didn't hit reload recursion limit";

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
