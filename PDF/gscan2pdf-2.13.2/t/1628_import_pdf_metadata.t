use warnings;
use strict;
use Gscan2pdf::Document;
use Gtk3 -init;    # Could just call init separately
use Date::Calc          qw(Add_Delta_DHMS);
use IPC::System::Simple qw(system);
use Test::More tests => 5;

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

Gscan2pdf::Document->setup($logger);

# Create b&w test image
system(
    qw(convert +matte -depth 1 -colorspace Gray),
    '-family', 'DejaVu Sans',
    qw(-pointsize 12 -density 300),
    'label:The quick brown fox', 'test.tif'
);
system(
    qw(tiff2pdf -o test.pdf -e 20181231120000 -a Authör -t Title -s Sübject -k Keywörds test.tif)
);

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.pdf'],
    metadata_callback => sub {
        my ($metadata) = @_;
        my @tz         = ( 0, -$metadata->{tz}[3], -$metadata->{tz}[4], 0 );
        my @gmt        = Add_Delta_DHMS( @{ $metadata->{datetime} }, @tz );
        is_deeply \@gmt, [ 2018, 12, 31, 12, 0, 0 ], 'datetime - timezone';
        is $metadata->{author},   'Authör',   'author';
        is $metadata->{subject},  'Sübject',  'subject';
        is $metadata->{keywords}, 'Keywörds', 'keywords';
        is $metadata->{title},    'Title',    'title';
    },
    finished_callback => sub {
        Gtk3->main_quit;
    }
);
Gtk3->main;

#########################

unlink 'test.pdf', 'test.png', 'test.tif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
