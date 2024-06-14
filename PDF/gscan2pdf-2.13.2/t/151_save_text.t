use warnings;
use strict;
use IPC::System::Simple qw(system capture);
use Test::More tests => 2;

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
        $slist->{data}[0][2]->import_text('The quick brown fox');
        $slist->save_text(
            path          => 'test.txt',
            list_of_pages => [ $slist->{data}[0][2]{uuid} ],
            options       => {
                post_save_hook         => 'cp %i test2.txt',
                post_save_hook_options => 'fg',
            },
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

is( capture(qw(cat test.txt)),  'The quick brown fox', 'saved ASCII' );
is( capture(qw(cat test2.txt)), 'The quick brown fox', 'ran post-save hook' );

#########################

unlink 'test.pnm', 'test.txt', 'test2.txt';
Gscan2pdf::Document->quit();
