use warnings;
use strict;
use IPC::Cmd            qw(can_run);
use IPC::System::Simple qw(system);
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'pdf2ps not installed', 2 unless can_run('pdf2ps');
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

                # metadata and timestamp should be ignored: debian #962151
                metadata => {},
                options  => {
                    ps                     => 'te st.ps',
                    pstool                 => 'pdf2ps',
                    post_save_hook         => 'cp %i test2.ps',
                    post_save_hook_options => 'fg',
                    set_timestamp          => 1,
                },
                finished_callback => sub { Gtk3->main_quit }
            );
        }
    );
    Gtk3->main;

    ok( -s 'te st.ps' > 194000, 'non-empty postscript created' );
    ok( -s 'test2.ps' > 194000, 'ran post-save hook' );

#########################

    unlink 'test.pnm', 'test2.ps', 'te st.ps';
    Gscan2pdf::Document->quit();
}
