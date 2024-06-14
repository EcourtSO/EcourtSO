use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
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
    qw(convert +matte -depth 1 -colorspace Gray -type Bilevel),
    '-family',
    'DejaVu Sans',
    qw(-pointsize 12 -density 300),
    'label:The quick brown fox',
    'test.tif'
);
system(qw(tiff2pdf -o test.pdf test.tif));
system(
    qw(convert +matte -depth 1 -colorspace Gray -type Bilevel),
    '-family',
    'DejaVu Sans',
    qw(-pointsize 12 -density 300),
    'label:The quick brown fox',
    'test.png'
);
my $old = capture( qw(identify -format), '%m %G %g %z-bit %r', 'test.png' );

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pdf'],
    finished_callback => sub {
        is(
            capture(
                qw(identify -format),
                '%m %G %g %z-bit %r',
                $slist->{data}[0][2]{filename}
            ),
            $old,
            'PDF imported correctly'
        );
        Gtk3->main_quit;
    }
);
Gtk3->main;

#########################

unlink 'test.pdf', 'test.tif', 'test.png';
Gscan2pdf::Document->quit();
