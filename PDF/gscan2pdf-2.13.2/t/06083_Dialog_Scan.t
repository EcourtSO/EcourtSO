use warnings;
use strict;
use Test::More tests => 2;
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
        'constraint'      => [ 4800, 2400, 1200, 600, 300, 150, 100, 75 ],
        'constraint_type' => 2,
        'desc'            => 'Sets the resolution of the scanned image.',
        'max_values'      => 1,
        'name'            => 'resolution',
        'title'           => 'Scan resolution',
        'type'            => 1,
        'unit'            => 4,
        'val'             => 75
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => '216.699996948242',
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Top-left x position of scan area.',
        'index'           => 8,
        'max_values'      => 1,
        'name'            => 'tl-x',
        'title'           => 'Top-left x',
        'type'            => 2,
        'unit'            => 3,
        'val'             => 0
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => 300,
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Top-left y position of scan area.',
        'index'           => 9,
        'max_values'      => 1,
        'name'            => 'tl-y',
        'title'           => 'Top-left y',
        'type'            => 2,
        'unit'            => 3,
        'val'             => 0
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => '216.699996948242',
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Bottom-right x position of scan area.',
        'index'           => 10,
        'max_values'      => 1,
        'name'            => 'br-x',
        'title'           => 'Bottom-right x',
        'type'            => 2,
        'unit'            => 3,
        'val'             => '216.699996948242'
    },
    {
        'cap'        => 5,
        'constraint' => {
            'max'   => 300,
            'min'   => 0,
            'quant' => 0
        },
        'constraint_type' => 1,
        'desc'            => 'Bottom-right y position of scan area.',
        'index'           => 11,
        'max_values'      => 1,
        'name'            => 'br-y',
        'title'           => 'Bottom-right y',
        'type'            => 2,
        'unit'            => 3,
        'val'             => 300
    },
    {
        'cap'             => 69,
        'constraint_type' => 0,
        'desc'            => 'Clear calibration cache',
        'max_values'      => 0,
        'name'            => 'clear-calibration',
        'title'           => 'Clear calibration',
        'type'            => 4,
        'unit'            => 0
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

# Reload clear-calibration button pressed to test that this doesn't trigger an
# infinite reload loop
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        my $info = 0;
        if ( defined $raw_options->[$index]{name}
            and $raw_options->[$index]{name} eq 'clear-calibration' )
        {
            $info = SANE_INFO_RELOAD_OPTIONS;
        }
        else {
            $raw_options->[$index]{val} = $value;
        }
        $self->{return}->enqueue(
            {
                type    => 'finished',
                process => 'set-option',
                uuid    => $uuid,
                status  => SANE_STATUS_GOOD,
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

$dialog->set(
    'paper-formats',
    {
        'A4' => {
            'x' => 210,
            'y' => 279,
            't' => 0,
            'l' => 0
        },
    }
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

        my $signal;
        $signal = $dialog->signal_connect(
            'changed-paper' => sub {
                my ( $dialog, $paper ) = @_;
                $dialog->signal_handler_disconnect($signal);
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            { 'resolution'        => '100' },
                            { 'clear-calibration' => undef },
                            {
                                'br-x' => '210'
                            },
                            {
                                'br-y' => '279'
                            },
                        ],
                        frontend => { paper => 'A4' }
                    },
                    'all options applied'
                );
                Gtk3->main_quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    backend => [
                        { 'resolution'        => '100' },
                        { 'clear-calibration' => undef },
                        {
                            'br-x' => '210'
                        },
                        {
                            'br-y' => '279'
                        },
                    ],
                    frontend => { paper => 'A4' }
                }
            )
        );
    }
);
$dialog->get_devices;

Gtk3->main;
ok $dialog->get('num-reloads') < 6,
  'finished reload loops without recursion limit';

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
