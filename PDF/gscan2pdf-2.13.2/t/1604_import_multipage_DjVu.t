use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use Gscan2pdf::Document;
use Gtk3 -init;        # Could just call init separately
use IPC::Cmd            qw(can_run);
use IPC::System::Simple qw(system);
use Test::More tests => 2;

#########################

SKIP: {
    skip 'DjVuLibre not installed', 2 unless can_run('cjb2');
    Gscan2pdf::Translation::set_domain('gscan2pdf');
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    system(qw(convert rose: test.jpg));
    system(qw(c44 test.jpg test.djvu));
    system(qw(djvm -c test2.djvu test.djvu test.djvu));

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths            => ['test2.djvu'],
        started_callback => sub {
            my ( $n, $process_name, $jobs_completed, $jobs_total, $message,
                $progress )
              = @_;
            pass 'started callback';
        },
        error_callback    => sub { fail 'error thrown'; Gtk3->main_quit },
        finished_callback => sub {
            is $#{ $slist->{data} }, 1, '2 pages imported';
            Gtk3->main_quit;
        }
    );
    Gtk3->main;

#########################

    unlink 'test.djvu', 'test2.djvu', 'test.jpg', <$dir/*>;
    rmdir $dir;
    Gscan2pdf::Document->quit();
}
