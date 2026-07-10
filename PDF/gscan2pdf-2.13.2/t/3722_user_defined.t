use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

# Create test image
system(qw(convert xc:white white.pnm));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['white.pnm'],
    finished_callback => sub {
        $slist->user_defined(
            page    => $slist->{data}[0][2]{uuid},
            command => 'echo error > /dev/stderr;convert %i -negate %i',
            finished_callback => sub {
                $slist->analyse(
                    list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
                    finished_callback => sub { Gtk3->main_quit }
                );
            },
            error_callback => sub {
                my ( $uuid, $process, $msg ) = @_;
                is( $msg, 'error',
                    'user_defined caught error injected in queue' );
            },
        );
    }
);
Gtk3->main;

is( $slist->{data}[0][2]{mean}, 0, 'User-defined after error' );

#########################

unlink 'white.pnm';
Gscan2pdf::Document->quit();
