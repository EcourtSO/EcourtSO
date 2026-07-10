use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
use Sub::Override;    # Override Frontend::Image_Sane to test functionality that
                      # we can't with the test backend
use Storable qw(freeze);    # For cloning the options cache
use Exception::Class (
    'Image::Sane::Exception' => { alias => 'throw', fields => 'status' } );

BEGIN {
    use Gscan2pdf::Dialog::Scan::Image_Sane;
}

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
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
        my $device_handle = {};
        bless \$device_handle, "Image::Sane::Device";
        $self->{device_handle} = \$device_handle;
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

# bug 313 seems to have been caused by getting a particular option (option 5)
# test it here (option 1).
my $raw_options = [
    undef,
    {
        'cap'             => SANE_CAP_SOFT_SELECT + SANE_CAP_SOFT_DETECT,
        'constraint_type' => SANE_CONSTRAINT_NONE,
        'max_values'      => 1,
        'type'            => SANE_TYPE_BOOL,
        'unit'            => SANE_UNIT_NONE
    },
    {
        'unit'            => 4,
        'constraint_type' => 2,
        'cap'             => 5,
        'index'           => 1,
        'desc'            => 'Sets the resolution of the scanned image.',
        'title'           => 'Scan resolution',
        'type'            => 1,
        'val'             => 75,
        'name'            => 'resolution',
        'max_values'      => 1,
        'constraint'      => [ 100, 200, 300, 600 ]
    },
    {
        'type'       => 3,
        'val'        => 'ADF',
        'max_values' => 1,
        'name'       => 'source',
        'constraint' => [ 'Flatbed', 'ADF' ],
        'title'      => 'Scan source',
        'desc'       => 'Selects the scan source (such as a document-feeder).',
        'index'      => 2,
        'cap'        => 5,
        'constraint_type' => 3,
        'unit'            => 0
    },
    {
        'type'       => 2,
        'val'        => 0,
        'name'       => 'tl-x',
        'max_values' => 1,
        'constraint' => {
            'min'   => 0,
            'max'   => '215.900009155273',
            'quant' => 0
        },
        'title'           => 'Top-left x',
        'desc'            => 'Top-left x position of scan area.',
        'index'           => 3,
        'cap'             => 5,
        'constraint_type' => 1,
        'unit'            => 3
    },
    {
        'desc'       => 'Top-left y position of scan area.',
        'title'      => 'Top-left y',
        'cap'        => 5,
        'index'      => 4,
        'name'       => 'tl-y',
        'max_values' => 1,
        'constraint' => {
            'min'   => 0,
            'quant' => 0,
            'max'   => '297.010681152344'
        },
        'val'             => 0,
        'type'            => 2,
        'constraint_type' => 1,
        'unit'            => 3
    },
    {
        'constraint_type' => 1,
        'unit'            => 3,
        'max_values'      => 1,
        'name'            => 'br-x',
        'constraint'      => {
            'min'   => 0,
            'max'   => '215.900009155273',
            'quant' => 0
        },
        'type'  => 2,
        'val'   => '215.900009155273',
        'desc'  => 'Bottom-right x position of scan area.',
        'title' => 'Bottom-right x',
        'cap'   => 5,
        'index' => 5
    },
    {
        'val'        => '297.010681152344',
        'type'       => 2,
        'name'       => 'br-y',
        'max_values' => 1,
        'constraint' => {
            'quant' => 0,
            'max'   => '297.010681152344',
            'min'   => 0
        },
        'index'           => 6,
        'cap'             => 5,
        'desc'            => 'Bottom-right y position of scan area.',
        'title'           => 'Bottom-right y',
        'unit'            => 3,
        'constraint_type' => 1
    },
];
$raw_options->[0]{val} = $#{$raw_options};
$override->replace(
    'Image::Sane::Device::get_option_descriptor' => sub ($$) {
        my ( $self, $n ) = @_;
        $logger->debug(
            "in Image::Sane::Device::get_option_descriptor $self, $n");

        # shallow copy in order to be able to remove val
        my $opt = { %{ $raw_options->[$n] } };
        delete $opt->{val};
        return $opt;
    }
);
$override->replace(
    'Image::Sane::Device::get_option' => sub {
        my ( $self, $n ) = @_;
        $logger->debug("in Image::Sane::Device::get_option $self, $n");
        my $status = $n == 1 ? SANE_STATUS_INVAL : SANE_STATUS_GOOD;
        if ($status) {
            Image::Sane::Exception->throw(
                error  => Image::Sane::strstatus($status),
                status => $status
            );
        }
        return $raw_options->[$n]{val};
    }
);
$override->replace( 'Image::Sane::Device::DESTROY' => sub ($) { } );

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

$dialog->{reloaded_signal} = $dialog->signal_connect(
    'reloaded-scan-options' => sub {
        $dialog->signal_handler_disconnect( $dialog->{reloaded_signal} );

        ######################################

        my $options = $dialog->get('available-scan-options');
        is_deeply(
            $options->by_index(1),
            {
                'index'           => 1,
                'cap'             => 0,
                'constraint_type' => SANE_CONSTRAINT_NONE,
                'max_values'      => 1,
                'type'            => SANE_TYPE_BOOL,
                'unit'            => SANE_UNIT_NONE
            },
            'make options that throw an error undetectable and unselectable'
        );
        Gtk3->main_quit;
    }
);
$dialog->get_devices;

Gtk3->main;

Gscan2pdf::Frontend::Image_Sane->quit;
__END__
