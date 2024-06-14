use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 2;
use Gtk3 -init;    # Could just call init separately

BEGIN {
    use Gscan2pdf::Document;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(
    qw(convert +matte -depth 1 -colorspace Gray),
    '-family', 'DejaVu Sans',
    qw(-pointsize 12 -density 300),
    'label:The quick brown fox', 'test.png'
);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.png'],
    finished_callback => sub {
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
            finished_callback => sub {
                $slist->save_pdf(
                    path          => 'test2.pdf',
                    list_of_pages => [ $slist->{data}[0][2]{uuid} ],
                    options       => {
                        downsample       => 1,
                        'downsample dpi' => 150,
                    },
                    finished_callback => sub { Gtk3->main_quit }
                );
            }
        );
    }
);
Gtk3->main;

is( -s 'test.pdf' > -s 'test2.pdf', 1,
    'downsampled PDF smaller than original' );
system(qw(pdfimages test2.pdf x));
like(
    capture( qw(identify -format), '%m %G %g %z-bit %r', 'x-000.pbm' ),
    qr/PBM 2\d\dx[23]\d 2\d\dx[23]\d[+]0[+]0 1-bit DirectClass Gray/,
    'downsampled'
);

#########################

unlink 'test.png', 'test.pdf', 'test2.pdf', 'x-000.pbm';
Gscan2pdf::Document->quit();
