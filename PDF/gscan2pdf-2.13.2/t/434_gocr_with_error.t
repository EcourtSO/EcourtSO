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

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

SKIP: {
    skip 'gocr not installed', 2 unless can_run('gocr');

    # Create test image
    my $filename = 'test.pnm';
    system(
        qw(convert +matte -depth 1),
        '-family', 'DejaVu Sans',
        qw(-pointsize 12 -density 300),
        "label:'The quick brown fox'", $filename
    );

    my $slist = Gscan2pdf::Document->new;

    # dir for temporary files
    my $dir = File::Temp->newdir;
    $slist->set_dir($dir);

    $slist->import_files(
        paths             => [$filename],
        finished_callback => sub {

            # inject error before gocr
            chmod 0500, $dir;    # no write access

            $slist->gocr(
                page           => $slist->{data}[0][2]{uuid},
                error_callback => sub {
                    pass('caught error injected before gocr');
                    chmod 0700, $dir;    # allow write access

                    $slist->gocr(
                        page            => $slist->{data}[0][2]{uuid},
                        queued_callback => sub {

                            # inject error during gocr
                            chmod 0500, $dir;    # no write access
                        },
                        error_callback => sub {
                            pass('gocr caught error injected in queue');
                            chmod 0700, $dir;    # allow write access
                        },
                        finished_callback => sub {
                            chmod 0700, $dir;    # allow write access
                            Gtk3->main_quit;
                        }
                    );

                }
            );
        }
    );
    Gtk3->main;

#########################

    unlink $filename, <$dir/*>;
    rmdir $dir;
}

Gscan2pdf::Document->quit();
