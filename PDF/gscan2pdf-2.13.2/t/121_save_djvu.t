use warnings;
use strict;
use IPC::Cmd            qw(can_run);
use IPC::System::Simple qw(system capture);
use Test::More tests => 4;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk3 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'DjVuLibre not installed', 3 unless can_run('cjb2');

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
        paths             => ['test.pnm'],
        finished_callback => sub {
            $slist->save_djvu(
                path          => 'test.djvu',
                list_of_pages => [ $slist->{data}[0][2]{uuid} ],
                options       => {
                    post_save_hook         => 'convert %i test2.png',
                    post_save_hook_options => 'fg',
                },
                finished_callback => sub {
                    is( -s 'test.djvu',
                        1054, 'DjVu created with expected size' );
                    is( $slist->scans_saved, 1, 'pages tagged as saved' );
                    Gtk3->main_quit;
                }
            );
        }
    );
    Gtk3->main;

    like(
        capture(qw(identify test2.png)),
        qr/test2.png PNG 70x46 70x46\+0\+0 8-bit sRGB/,
        'ran post-save hook'
    );

#########################

    unlink 'test.pnm', 'test.djvu', 'test2.png';
    Gscan2pdf::Document->quit();
}
