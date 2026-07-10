use warnings;
use strict;
use IPC::System::Simple qw(system);
use IPC::Cmd            qw(can_run);
use Test::More tests => 2;
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
    skip 'Tesseract not installed', 2
      unless Gscan2pdf::Tesseract->setup($logger);
    skip 'unpaper not installed', 2 unless can_run('unpaper');

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
        filename         => 'test.pnm',
        page             => 1,
        to_png           => 1,
        rotate           => 90,
        unpaper          => $unpaper,
        ocr              => 1,
        resolution       => 300,
        delete           => 0,
        dir              => $dir,
        engine           => 'tesseract',
        language         => 'eng',
        started_callback => sub {
            $slist->select(0);
            $slist->delete_selection;
        },
        error_callback => sub {
            pass "Caught error trying to process deleted page";
            Gtk3->main_quit;
        },
        finished_callback => sub {
            fail "Caught error trying to process deleted page";
            Gtk3->main_quit;
        }
    );
    Gtk3->main;

    # need a new main loop to avoid nesting
    my $loop1 = Glib::MainLoop->new;
    $slist->import_scan(
        filename         => 'test.pnm',
        page             => 2,
        to_png           => 1,
        rotate           => 90,
        ocr              => 1,
        resolution       => 300,
        delete           => 1,
        dir              => $dir,
        engine           => 'tesseract',
        language         => 'eng',
        started_callback => sub {
        },
        error_callback => sub {
            fail "Error processing after deleted page";
            $loop1->quit;
        },
        finished_callback => sub {
            pass "Successfully processed page after deleting";
            $loop1->quit;
        },
    );
    $loop1->run;

}

#########################

unlink 'test.pnm';
Gscan2pdf::Document->quit();
