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
    skip 'DjVuLibre not installed', 1 unless can_run('c44');
    Gscan2pdf::Translation::set_domain('gscan2pdf');
    use Log::Log4perl qw(:easy);
    Log::Log4perl->easy_init($WARN);
    my $logger = Log::Log4perl::get_logger;
    Gscan2pdf::Document->setup($logger);

    # Create test image
    system(qw(convert rose: test.pnm));
    system( qw(c44 test.pnm), 'te st.djvu' );

    my $slist = Gscan2pdf::Document->new;
    $slist->import_files(
        paths             => ['te st.djvu'],
        finished_callback => sub {
            is( $#{ $slist->{data} }, 0,
                'Imported correctly DjVu with spaces' );
            Gtk3->main_quit;
        }
    );
    Gtk3->main;

#########################

    unlink 'test.pnm', 'te st.djvu';
    Gscan2pdf::Document->quit();
}
