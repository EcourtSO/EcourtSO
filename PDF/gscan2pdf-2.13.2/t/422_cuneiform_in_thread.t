use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use IPC::System::Simple qw(system);
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use_ok('Gscan2pdf::Cuneiform');
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);
my $logger = Log::Log4perl::get_logger;

SKIP: {
    skip 'Cuneiform not installed', 2
      unless Gscan2pdf::Cuneiform->setup($logger);

    Gscan2pdf::Document->setup($logger);

    # Create test image
    system(
        qw(convert +matte -depth 1),
        '-family',
        'DejaVu Sans',
        qw(-pointsize 12 -density 300),
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
            $slist->cuneiform(
                page              => $slist->{data}[0][2]{uuid},
                language          => 'eng',
                finished_callback => sub {
                    like(
                        $slist->{data}[0][2]{hocr},
                        qr/The quick brown fox/,
                        'Cuneiform returned sensible text'
                    );
                    is( dirname("$slist->{data}[0][2]{filename}"),
                        "$dir", 'using session directory' );
                    Gtk3->main_quit;
                }
            );
        }
    );
    Gtk3->main;

    unlink 'test.png', <$dir/*>;
    rmdir $dir;
    Gscan2pdf::Document->quit();
}
