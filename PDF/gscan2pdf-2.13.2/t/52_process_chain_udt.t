use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 1;
use Gtk3 -init;    # Could just call init separately
use Gscan2pdf::Tesseract;
use Gscan2pdf::Document;
use Gscan2pdf::Unpaper;

#########################

BEGIN {
    Gscan2pdf::Translation::set_domain('gscan2pdf');
}

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

# Create test image
system(qw(convert -size 210x297 xc:white white.pnm));

$slist->import_scan(
    filename          => 'white.pnm',
    page              => 1,
    udt               => 'convert %i -negate %o',
    resolution        => 300,
    delete            => 1,
    dir               => $dir,
    finished_callback => sub {
        $slist->analyse(
            list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
            finished_callback => sub {
                is( $slist->{data}[0][2]{mean},
                    0, 'User-defined with %i and %o' );
                Gtk3->main_quit;
            }
        );
    }
);
Gtk3->main;

#########################

unlink 'white.pnm';
Gscan2pdf::Document->quit();
