use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 3;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(qw(convert rose: test.pnm));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => [ 'test.pnm', 'test.pnm' ],
    finished_callback => sub {
        $slist->save_tiff(
            path          => 'test.tif',
            list_of_pages =>
              [ $slist->{data}[0][2]{uuid}, $slist->{data}[1][2]{uuid} ],
            options => {
                ps                     => 'te st.ps',
                post_save_hook         => 'ps2pdf %i test.pdf',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

is capture( 'file', 'te st.ps' ),
"te st.ps: PostScript document text conforming DSC level 3.0, type EPS, Level 3\n",
  'valid postscript created';
like capture(qw(pdfinfo test.pdf)), qr/tiff2ps/, 'ran post-save hook';

#########################

unlink 'test.pnm', 'test.tif', 'test.pdf', 'te st.ps';
Gscan2pdf::Document->quit();
