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
            'max'   => '356',
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
            'max'   => '356',
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

# A fujitsu:fi-4220C2dj was ignoring paper change requests because setting
# initial geometry set SANE_INFO_INEXACT
$override->replace(
    'Gscan2pdf::Frontend::Image_Sane::_thread_set_option' => sub {
        my ( $self, $uuid, $index, $value ) = @_;
        my $opt    = $raw_options->[$index];
        my $status = 0;
        my $info   = 0;
        if (   $opt->{name} eq 'br-x'
            or $opt->{name} eq 'br-y'
            or $opt->{name} eq 'tl-y'
            or $opt->{name} eq 'tl-y' )
        {
            $info = SANE_INFO_RELOAD_PARAMS + SANE_INFO_INEXACT;

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
            $raw_options->[$index]{val} = $value - 0.5;
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

$dialog->set(
    'paper-formats',
    {
        'US Legal' => {
            'l' => 0,
            't' => 0,
            'x' => 216,
            'y' => 356
        },
        'US Letter' => {
            'l' => 0,
            't' => 0,
            'x' => 216,
            'y' => 279
        }
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

        ######################################

        # need a new main loop because of the timeout
        my $loop = Glib::MainLoop->new;
        my $flag = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-paper' => sub {
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            {
                                'br-x' => '215.899993896484'
                            },
                            {
                                'br-y' => '279'
                            },
                        ],
                        frontend => {
                            'paper' => 'US Letter'
                        }
                    },
                    'set first paper'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'paper', 'US Letter' );
        $loop->run unless ($flag);

        # need a new main loop because of the timeout
        $loop             = Glib::MainLoop->new;
        $flag             = FALSE;
        $dialog->{signal} = $dialog->signal_connect(
            'changed-paper' => sub {
                $dialog->signal_handler_disconnect( $dialog->{signal} );
                is_deeply(
                    $dialog->get('current-scan-options')->get_data,
                    {
                        backend => [
                            {
                                'br-x' => '215.899993896484'
                            },
                            {
                                'br-y' => '356'
                            },
                        ],
                        frontend => {
                            'paper' => 'US Legal'
                        }
                    },
                    'set second paper after SANE_INFO_INEXACT'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set( 'paper', 'US Legal' );
        $loop->run unless ($flag);
        Gtk3->main_quit;
    }
);
$dialog->get_devices;

Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
