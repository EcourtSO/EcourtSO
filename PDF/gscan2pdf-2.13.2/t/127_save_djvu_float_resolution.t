use warnings;
use strict;
use IPC::Cmd            qw(can_run);
use IPC::System::Simple qw(system);
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

SKIP: {
    skip 'DjVuLibre not installed', 1 unless can_run('cjb2');
    Gscan2pdf::Translation::set_domain('gscan2pdf');
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    system(qw(convert rose: test.png));

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => ['test.png'],
        finished_callback => sub {
            $slist->{data}[0][2]{xresolution} = 299.72;
            $slist->{data}[0][2]{yresolution} = 299.72;
            $slist->save_djvu(
                path              => 'test.djvu',
                list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
                finished_callback => sub {
                    is( -s 'test.djvu',
                        1054, 'DjVu created with expected size' );
                    Gtk3->main_quit;
                }
            );
        }
    );
    Gtk3->main;

#########################

    unlink 'test.png', 'test.djvu';
    Gscan2pdf::Document->quit();
}
