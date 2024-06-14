use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 1;
use Gtk3 -init;    # Could just call init separately

BEGIN {
    use Gscan2pdf::Document;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(qw(convert rose: -density 100x200 test.png));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.png'],
    finished_callback => sub {
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
            finished_callback => sub {
                like(
                    capture("pdfinfo test.pdf"),
                    qr/Page size:\s+50.4 x 16.56 pts/,
                    'valid PDF created'
                );
                Gtk3->main_quit;
            }
        );
    }
);
Gtk3->main;

#########################

unlink 'test.png', 'test.pdf';
Gscan2pdf::Document->quit();
