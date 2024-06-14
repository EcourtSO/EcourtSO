use warnings;
use strict;
use Test::More tests => 4;
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
        'cap'             => 69,
        'constraint_type' => 0,
        'desc'            => '',
        'index'           => 18,
        'max_values'      => 1,
        'name'            => 'cct-1',
        'title'           => '',
        'type'            => 2,
        'unit'            => 0,
        'val'             => '1.07818603515625'
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

# An EPSON DS-1660W was setting tl-y=0.99 instead of 1, but not setting
# SANE_INFO_INEXACT, which was hitting the reload-recursion-limit.
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
            $info = 21870;
            if ( $value == 1 ) { $value = 0.999984741210938 }

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
        $raw_options->[$index]{val} = $value;
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
        new => {
            l => 0,
            y => 10,
            x => 10,
            t => 1,
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
                                'tl-y' => 1
                            },
                            {
                                'br-x' => 10
                            },
                            {
                                'br-y' => 11
                            },
                        ],
                        frontend => {
                            'paper' => 'new'
                        }
                    },
                    'set inexact paper without SANE_INFO_INEXACT'
                );
                $flag = TRUE;
                $loop->quit;
            }
        );
        $dialog->set_current_scan_options(
            Gscan2pdf::Scanner::Profile->new_from_data(
                {
                    frontend => {
                        'paper' => 'new'
                    },
                },
            )
        );
        $loop->run unless ($flag);

        # EPSON DS-1660W calls the flatbed a document table
        my $options = $dialog->get('available-scan-options');
        is( $options->flatbed_selected, TRUE, 'Document Table means flatbed' );

        # as cct-1 does not have a title, test for label text
        is( $dialog->get_label_for_option('cct-1'),
            'cct-1', 'text for option with no title' );

        Gtk3->main_quit;
    }
);
$dialog->get_devices;

Gtk3->main;
ok $dialog->get('num-reloads') < 5, "didn't hit reload recursion limit";

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
