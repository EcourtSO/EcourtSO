use warnings;
use strict;
use utf8;
use IPC::System::Simple qw(system capture);
use Test::More tests => 1;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
    use PDF::Builder;
    use File::Copy;
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(qw(convert rose: 1.pnm));

# number of pages
my $n = 3;

my %options;
$options{font} = capture('fc-list : file | grep ttf 2> /dev/null | head -n 1');
chomp $options{font};
$options{font} =~ s/: $//;

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

my @files;
for my $i ( 1 .. $n ) {
    copy( '1.pnm', "$i.pnm" ) if ( $i > 1 );
    push @files, "$i.pnm";
}
$slist->import_files(
    paths             => \@files,
    finished_callback => sub {
        my @pages;
        for my $i ( 0 .. $n - 1 ) {
            $slist->{data}[$i][2]
              ->import_text('пени способствовала сохранению');
            push @pages, $slist->{data}[$i][2]{uuid};
        }
        $slist->save_pdf(
            path              => 'test.pdf',
            list_of_pages     => \@pages,
            options           => \%options,
            finished_callback => sub { Gtk3->main_quit }
        );
    }
);
Gtk3->main;

is( capture('pdffonts test.pdf | grep -c TrueType') + 0,
    1, 'font embedded once in multipage PDF' );

#########################

for my $i ( 1 .. $n ) {
    unlink "$i.pnm";
}
unlink 'test.pdf';
Gscan2pdf::Document->quit();
