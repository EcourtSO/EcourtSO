use warnings;
use strict;
use Test::More tests => 1;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately
use Image::Sane ':all';     # To get SANE_* enums
use Sub::Override;          # Override Frontend::CLI to test functionality that
                            # we can't with the test backend
use Gscan2pdf::Dialog::Scan::CLI;

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger   = Log::Log4perl::get_logger;
my $override = Sub::Override->new;
$override->replace(
    'Gscan2pdf::Frontend::CLI::get_devices' => sub {
        my ( $class, %options ) = @_;
        if ( defined $options{started_callback} ) {
            $options{started_callback}->();
        }
        if ( defined $options{running_callback} ) {
            $options{running_callback}->();
        }
        if ( defined $options{finished_callback} ) {
            $options{finished_callback}
              ->( Gscan2pdf::Frontend::CLI->parse_device_list() );
        }
        return;
    }
);

Gscan2pdf::Frontend::CLI->setup($logger);

my $dialog = Gscan2pdf::Dialog::Scan::CLI->new(
    title           => 'title',
    'transient-for' => $window,
    'logger'        => $logger
);
my $loop;
$dialog->signal_connect(
    'changed-device-list' => sub {
        my ( $self, $devices ) = @_;
        is_deeply $devices, [], 'changed-device-list called with empty array';
        if ($loop) {
            Gtk3->main_quit;
        }
        else {
            $loop = TRUE;
        }
    }
);
$dialog->get_devices;
if ( not $loop ) {
    $loop = TRUE;
    Gtk3->main;
}

__END__
