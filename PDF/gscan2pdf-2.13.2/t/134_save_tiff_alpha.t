use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 1;

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
system(
    qw(convert -fill lightblue),
    '-family',
    'DejaVu Sans',
    qw(-pointsize 12 -units PixelsPerInch -density 300),
    'label:The quick brown fox',
    'test.png'
);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.png'],
    finished_callback => sub {
        $slist->save_tiff(
            path          => 'test.tif',
            list_of_pages => [ $slist->{data}[0][2]{uuid} ],
            options       => {
                compression => 'lzw',
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

like(
    capture(qw(identify test.tif)),
    qr/test.tif TIFF \d\d\dx\d\d \d\d\dx\d\d\+0\+0 16-bit sRGB/,
    'valid TIFF created'
);

#########################

unlink 'test.tif', 'test.png';
Gscan2pdf::Document->quit();
