use warnings;
use strict;
use utf8;
use IPC::System::Simple qw(system capture);
use Test::More tests => 3;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
    use PDF::Builder;
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
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->{data}[0][2]->import_text('äöü');
        $slist->save_pdf(
            path           => 'test.pdf',
            list_of_pages  => [ $slist->{data}[0][2]{uuid} ],
            options        => { font => 'removed' },
            error_callback => sub {
                my ( $uuid, $process, $message ) = @_;
                is $process, 'Save file', 'expected process';
                is $message,
                  "Unable to find font 'removed'. Defaulting to core font.",
                  'expected error message';
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

my $out = capture(qw(pdftotext test.pdf -));
utf8::decode($out);
like $out, qr/äöü/, 'PDF with expected text';

#########################

unlink 'test.pnm', 'test.pdf';
Gscan2pdf::Document->quit();
