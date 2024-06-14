use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use File::Copy;
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(qw(convert rose: test.tif));
my $old = capture( qw(identify -format), '%m %G %g %z-bit %r', 'test.tif' );

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.tif'],
    finished_callback => sub {
        fail('TIFF not imported');
        Gtk3->main_quit;
    }
);
$slist->cancel(
    sub {
        is( defined( $slist->{data}[0] ), '', 'TIFF not imported' );
        $slist->import_files(
            paths             => ['test.tif'],
            finished_callback => sub {
                copy( "$slist->{data}[0][2]{filename}", 'test.tif' );
                Gtk3->main_quit;
            }
        );
    }
);
Gtk3->main;

is( capture( qw(identify -format), '%m %G %g %z-bit %r', 'test.tif' ),
    $old, 'TIFF imported correctly after cancelling previous import' );

#########################

unlink 'test.tif';
Gscan2pdf::Document->quit();
