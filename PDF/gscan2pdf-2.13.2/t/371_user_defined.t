use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use IPC::System::Simple qw(system capture);
use Test::More tests => 6;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
Gscan2pdf::Document->setup(Log::Log4perl::get_logger);

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
system(qw(convert -size 210x297 xc:white white.pnm));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);
$slist->set_paper_sizes( \%paper_sizes );

$slist->import_files(
    paths             => ['white.pnm'],
    finished_callback => sub {
        is( int( abs( $slist->{data}[0][2]{xresolution} - 25.4 ) ),
            0, 'Resolution of imported image' );
        $slist->{data}[0][2]{bboxtree} =
'[{"bbox":["0","0","783","1057"],"id":"page_1","type":"page","depth":0},{"depth":1,"id":"word_1_2","type":"word","confidence":"93","text":"ACCOUNT","bbox":["218","84","401","109"]}]';
        $slist->user_defined(
            page              => $slist->{data}[0][2]{uuid},
            command           => 'convert %i -negate %o',
            finished_callback => sub {
                $slist->analyse(
                    list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
                    finished_callback => sub {
                        is( $slist->{data}[0][2]{mean},
                            0, 'User-defined with %i and %o' );
                        is(
                            int(
                                abs( $slist->{data}[0][2]{xresolution} - 25.4 )
                            ),
                            0,
                            'Resolution of converted image'
                        );
                        like $slist->{data}[0][2]{bboxtree}, qr/ACCOUNT/,
                          'OCR output still there';
                        is( dirname("$slist->{data}[0][2]{filename}"),
                            "$dir", 'using session directory' );
                        $slist->save_pdf(
                            path              => 'test.pdf',
                            list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
                            finished_callback => sub { Gtk3->main_quit }
                        );
                    }
                );
            }
        );
    }
);
Gtk3->main;

like( capture(qw(pdfinfo test.pdf)), qr/A4/, 'PDF is A4' );

#########################

unlink 'white.pnm', 'test.pdf', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
