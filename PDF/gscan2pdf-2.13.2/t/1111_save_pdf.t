use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 9;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately

BEGIN {
    use_ok('Gscan2pdf::Document');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(qw(convert rose: test.pnm));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

# use a new main loop to avoid nesting, which was preventing the counters
# resetting in some environments
my $loop = Glib::MainLoop->new;
my $flag = FALSE;
$slist->import_files(
    paths            => ['test.pnm'],
    started_callback => sub {
        my ( $thread, $process, $completed, $total ) = @_;
        is( $completed, 0, 'completed counter starts at 0' );
        is( $total,     2, 'total counter starts at 2' );
    },
    finished_callback => sub {
        is( $slist->scans_saved, '', 'pages not tagged as saved' );
        $flag = TRUE;
        $loop->quit;
    }
);
$loop->run unless ($flag);

$slist->save_pdf(
    path             => 'test.pdf',
    list_of_pages    => [ $slist->{data}[0][2]{uuid} ],
    started_callback => sub {
        my ( $thread, $process, $completed, $total ) = @_;
        is( $completed, 0, 'completed counter re-initialised' );
        is( $total,     1, 'total counter re-initialised' );
    },
    options => {
        post_save_hook         => 'pdftoppm %i test',
        post_save_hook_options => 'fg',
    },
    finished_callback => sub {
        like(
            capture("pdfinfo test.pdf"),
            qr/Page size:\s+70 x 46 pts/,
            'valid PDF created'
        );
        is( $slist->scans_saved, 1, 'pages tagged as saved' );
        Gtk3->main_quit;
    }
);
Gtk3->main;

like(
    capture(qw(identify test-1.ppm)),
    qr/test-1.ppm PPM 146x96 146x96\+0\+0 8-bit sRGB/,
    'ran post-save hook on pdf'
);

#########################

unlink 'test.pnm', 'test.pdf', 'test-1.ppm';
Gscan2pdf::Document->quit();
