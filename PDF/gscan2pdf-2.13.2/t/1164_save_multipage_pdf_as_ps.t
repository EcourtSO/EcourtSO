use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 2;

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
system(qw(convert rose: test.pnm));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => [ 'test.pnm', 'test.pnm' ],
    finished_callback => sub {
        $slist->save_pdf(
            path          => 'test.pdf',
            list_of_pages =>
              [ $slist->{data}[0][2]{uuid}, $slist->{data}[1][2]{uuid} ],
            options => {
                ps                     => 'te st.ps',
                pstool                 => 'pdftops',
                post_save_hook         => 'cp %i test2.ps',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

cmp_ok( -s 'te st.ps', '>', 17500, 'non-empty postscript created' );
cmp_ok( -s 'test2.ps', '>', 17500, 'ran post-save hook' );

#########################

unlink 'test.pnm', 'test.pdf', 'test2.ps', 'te st.ps';
Gscan2pdf::Document->quit();
