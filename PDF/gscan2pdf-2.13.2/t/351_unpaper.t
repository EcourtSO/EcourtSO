use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use IPC::Cmd            qw(can_run);
use IPC::System::Simple qw(system capture);
use Test::More tests => 7;

BEGIN {
    use Gscan2pdf::Document;
    use Gscan2pdf::Unpaper;
    use Gtk3 -init;    # Could just call init separately
}

Gscan2pdf::Translation::set_domain('gscan2pdf');

SKIP: {
    skip 'unpaper not installed', 5 unless can_run('unpaper');
    my $unpaper = Gscan2pdf::Unpaper->new;

    use Log::Log4perl qw(:easy);

    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    my %paper_sizes = (
        A4 => {
            x => 210,
            y => 297,
            l => 0,
            t => 0,
        },
        'US Letter' => {
            x => 216,
            y => 279,
            l => 0,
            t => 0,
        },
        'US Legal' => {
            x => 216,
            y => 356,
            l => 0,
            t => 0,
        },
    );

    # Create test image
    system(
        qw(convert -size 2100x2970 +matte -depth 1 -border 2x2 -bordercolor black),
        '-family',
        'DejaVu Sans',
        qw(-pointsize 12 -density 300),
        'label:The quick brown fox',
        'test.pnm'
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);
    $slist->set_paper_sizes( \%paper_sizes );

    $slist->import_files(
        paths             => ['test.pnm'],
        finished_callback => sub {
            is( int( abs( $slist->{data}[0][2]{xresolution} - 254 ) ),
                0, 'Resolution of imported image' );
            $slist->unpaper(
                page              => $slist->{data}[0][2]{uuid},
                options           => { command => $unpaper->get_cmdline },
                finished_callback => sub {
                    is( int( abs( $slist->{data}[0][2]{xresolution} - 254 ) ),
                        0, 'Resolution of processed image' );
                    is( system("identify $slist->{data}[0][2]{filename}"),
                        0, 'valid image created' );
                    is( dirname("$slist->{data}[0][2]{filename}"),
                        "$dir", 'using session directory' );
                    $slist->save_pdf(
                        path              => 'test.pdf',
                        list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
                        finished_callback => sub { Gtk3->main_quit }
                    );
                },
                error_callback => sub {
                    my ( $uuid, $process, $message ) = @_;
                    for my $msg ( split "\n", $message ) {

                        # if we use unlike, we no longer
                        # know how many tests there will be
                        if (
                            $msg !~ /( deprecated |
                            \Qdoes not contain an image sequence pattern\E |
                            \QEncoder did not produce proper pts, making some up\E |
                            \Quse the -update option\E )/x
                          )
                        {
                            fail 'no warnings';
                        }
                    }
                }
            );
        }
    );
    Gtk3->main;

    like( capture(qw(pdfinfo test.pdf)), qr/A4/, 'PDF is A4' );

    unlink 'test.pnm', 'test.pdf', <$dir/*>;
    rmdir $dir;
    Gscan2pdf::Document->quit();
}

my $unpaper =
  Gscan2pdf::Unpaper->new( { 'output-pages' => 2, layout => 'double' } );
$Gscan2pdf::Unpaper::UNPAPER_VERSION = version->parse('0.3');
is(
    $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --deskew-scan-direction left,right --layout double --output-pages 2 --white-threshold 0.9 --overwrite --input-file-sequence %s --output-file-sequence %s %s',
    'cmdline v0.3'
);
$Gscan2pdf::Unpaper::UNPAPER_VERSION = version->parse('0.4');
is(
    $unpaper->get_cmdline,
'unpaper --black-threshold 0.33 --deskew-scan-direction left,right --layout double --output-pages 2 --white-threshold 0.9 --overwrite %s %s %s',
    'cmdline v0.4'
);
