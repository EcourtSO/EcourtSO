use warnings;
use strict;
use IPC::System::Simple qw(system);
use IPC::Cmd            qw(can_run);
use Test::More tests => 5;
use Gtk3 -init;    # Could just call init separately
use Gscan2pdf::Tesseract;
use Gscan2pdf::Document;
use Gscan2pdf::Unpaper;

#########################

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

Gscan2pdf::Translation::set_domain('gscan2pdf');

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

SKIP: {
    skip 'Tesseract not installed', 5
      unless Gscan2pdf::Tesseract->setup($logger);
    skip 'unpaper not installed', 5 unless can_run('unpaper');

    my $unpaper = Gscan2pdf::Unpaper->new;
    my $vbox    = Gtk3::VBox->new;
    $unpaper->add_options($vbox);

    # Create b&w test image
    system(
        qw(convert +matte -depth 1 -colorspace Gray),
        '-family',
        'DejaVu Sans',
        qw(-pointsize 12 -density 300),
        'label:The quick brown fox',
        qw(-rotate -90 test.pnm)
    );

    $slist->import_scan(
        filename          => 'test.pnm',
        page              => 1,
        to_png            => 1,
        rotate            => 90,
        unpaper           => $unpaper,
        ocr               => 1,
        resolution        => 300,
        delete            => 1,
        dir               => $dir,
        engine            => 'tesseract',
        language          => 'eng',
        finished_callback => sub {
            like $slist->{data}[0][2]{filename}, qr/png$/, 'convert PNM to PNG';
            my $hocr = $slist->{data}[0][2]->export_hocr;
            like $hocr, qr/T[hn]e/,  'Tesseract returned "The"';
            like $hocr, qr/quick/,   'Tesseract returned "quick"';
            like $hocr, qr/brown/,   'Tesseract returned "brown"';
            like $hocr, qr/f(o|0)x/, 'Tesseract returned "fox"';
            Gtk3->main_quit;
        }
    );
    Gtk3->main;
}

#########################

unlink 'test.pnm';
Gscan2pdf::Document->quit();
