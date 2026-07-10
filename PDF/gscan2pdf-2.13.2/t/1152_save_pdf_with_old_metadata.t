use warnings;
use strict;
use Date::Calc qw(Date_to_Time);
use File::stat;
use Glib                qw(TRUE FALSE);       # To get TRUE and FALSE
use IPC::System::Simple qw(system capture);
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;                           # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($FATAL);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
my $pnm = 'test.pnm';
my $pdf = 'test.pdf';
system( qw(convert rose:), $pnm );

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my %metadata =
  ( datetime => [ 1966, 2, 10, 0, 0, 0 ], title => 'metadata title' );
$slist->import_files(
    paths             => [$pnm],
    finished_callback => sub {
        $slist->save_pdf(
            path              => $pdf,
            list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
            metadata          => \%metadata,
            options           => { set_timestamp => TRUE },
            finished_callback => sub { Gtk3->main_quit },
            error_callback    => sub { pass('caught errors setting timestamp') }
        );
    }
);
Gtk3->main;

my $info = capture( qw(pdfinfo -isodates), $pdf );
like $info, qr/1966-02-10T00:00:00Z/, 'metadata ModDate in PDF';

#########################

unlink $pnm, $pdf;
Gscan2pdf::Document->quit();
