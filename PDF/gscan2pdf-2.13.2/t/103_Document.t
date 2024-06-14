use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 2;
use Glib 1.210 qw(TRUE FALSE);
use Gtk3 -init;    # Could just call init separately
use Gscan2pdf::Document;

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;

# build a cropped (i.e. too little data compared with header) pnm
# to test padding code
system(qw(convert rose: test.ppm));
my $old = capture( qw(identify -format), '%m %G %g %z-bit %r', 'test.ppm' );
system('convert rose: - | head -c -1K > test.pnm');

$slist->set_dir($dir);
$slist->import_scan(
    filename          => 'test.pnm',
    page              => 1,
    delete            => 1,
    dir               => $dir,
    finished_callback => sub {
        system( 'convert', $slist->{data}[0][2]{filename}, 'test2.ppm' );
        is(
            capture( qw(identify -format), '%m %G %g %z-bit %r', 'test2.ppm' ),
            $old,
            'padded pnm imported correctly (as PNG)'
        );
        is( -s 'test2.ppm', -s 'test.ppm', 'padded pnm correct size' );
        Gtk3->main_quit;
    }
);
Gtk3->main;

#########################

unlink 'test.ppm', 'test2.ppm', 'test.pnm', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();

__END__
