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
    qw(convert rose: -define tiff:rows-per-strip=1 -compress group4 test.tif));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.tif'],
    finished_callback => sub {
        $slist->save_pdf(
            path          => 'test.pdf',
            list_of_pages => [ $slist->{data}[0][2]{uuid} ],
            options       => {
                compression => 'g4',
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

system(
"gs -q -dNOPAUSE -dBATCH -sDEVICE=pnggray -g70x46 -dPDFFitPage -dUseCropBox -sOutputFile=test.png test.pdf"
);
my $example  = `convert test.png -depth 1 -alpha off txt:-`;
my $expected = `convert test.tif -depth 1 -alpha off txt:-`;
is( $example, $expected, 'valid G4 PDF created from multi-strip TIFF' );

#########################

unlink 'test.pdf', 'test.tif', 'test.png';
Gscan2pdf::Document->quit();
