use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use IPC::System::Simple qw(system capture);
use Gscan2pdf::Document;
use Test::More tests => 1;

BEGIN {
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
system(qw(ln -s test.tif test2.tif));
my $old = capture( qw(identify -format), '%m %G %g %z-bit %r', 'test.tif' );

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test2.tif'],
    finished_callback => sub {
        is(
            capture(
                qw(identify -format),
                '%m %G %g %z-bit %r',
                $slist->{data}[0][2]{filename}
            ),
            $old,
            'TIFF imported correctly'
        );
        Gtk3->main_quit;
    }
);
Gtk3->main;

#########################

unlink 'test.tif', 'test2.tif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
