use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 1;

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
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->{data}[0][2]->import_text('пени способствовала сохранению');
        $slist->save_text(
            path              => 'test.txt',
            list_of_pages     => [ $slist->{data}[0][2]{uuid} ],
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

is( capture(qw(cat test.txt)), 'пени способствовала сохранению', 'saved UTF8' );

#########################

unlink 'test.pnm', 'test.txt';
Gscan2pdf::Document->quit();
