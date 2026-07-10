use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 12;

BEGIN {
    use_ok('Gscan2pdf::Page');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($ERROR);

# Create test image
system(qw(convert rose: test.pnm));

Gscan2pdf::Page->set_logger(Log::Log4perl::get_logger);
my $page = Gscan2pdf::Page->new(
    filename   => 'test.pnm',
    format     => 'Portable anymap',
    resolution => 72,
    dir        => File::Temp->newdir,
);

#########################

my %paper_sizes = (
    A4 => {
        x => 210,
        y => 297,
        l => 0,
        t => 0,
    },
    'US Letter' => {
        x => 216,
        y => 279,
        l => 0,
        t => 0,
    },
    'US Legal' => {
        x => 216,
        y => 356,
        l => 0,
        t => 0,
    },
);

system(qw(convert -size 210x297 xc:white test.pnm));
$page = Gscan2pdf::Page->new(
    filename => 'test.pnm',
    format   => 'Portable anymap',
    dir      => File::Temp->newdir,
);
is_deeply(
    $page->matching_paper_sizes( \%paper_sizes ),
    { A4 => 25.4 },
    'basic portrait'
);
system(qw(convert -size 297x210 xc:white test.pnm));
$page = Gscan2pdf::Page->new(
    filename => 'test.pnm',
    format   => 'Portable anymap',
    dir      => File::Temp->newdir,
);
is_deeply(
    $page->matching_paper_sizes( \%paper_sizes ),
    { A4 => 25.4 },
    'basic landscape'
);

#########################

is( $page->get_resolution( \%paper_sizes ), 25.4, 'resolution' );

system(qw(convert -units PixelsPerInch -density 300 xc:white test.jpg));
$page = Gscan2pdf::Page->new(
    filename => 'test.jpg',
    format   => 'Joint Photographic Experts Group JFIF format',
    dir      => File::Temp->newdir,
);
is( $page->get_resolution( \%paper_sizes ), 300, 'inches' );

system(qw(convert -units PixelsPerCentimeter -density 118 xc:white test.jpg));
$page = Gscan2pdf::Page->new(
    filename => 'test.jpg',
    format   => 'Joint Photographic Experts Group JFIF format',
    dir      => File::Temp->newdir,
);
is( $page->get_resolution( \%paper_sizes ), 299.72, 'centimetres' );

system(qw(convert -units Undefined -density 300 xc:white test.jpg));
$page = Gscan2pdf::Page->new(
    filename => 'test.jpg',
    format   => 'Joint Photographic Experts Group JFIF format',
    dir      => File::Temp->newdir,
);
is( $page->get_resolution( \%paper_sizes ), 300, 'undefined' );

#########################

system(qw(convert -size 210x297 xc:white test.pnm));
$page = Gscan2pdf::Page->new(
    filename => 'test.pnm',
    format   => 'Portable anymap',
    dir      => File::Temp->newdir,
    size     => [ 105, 148, 'pts' ],
);
is( $page->get_resolution, 144.486486486486, 'from pdfinfo paper size' );

#########################

is_deeply [ Gscan2pdf::Page::_prepare_scale( 1000, 100, 1, 100, 100 ) ],
  [ 100, 10 ], 'scale x, ratio 1';
is_deeply [ Gscan2pdf::Page::_prepare_scale( 100, 1000, 1, 100, 100 ) ],
  [ 10, 100 ], 'scale y, ratio 1';
is_deeply [ Gscan2pdf::Page::_prepare_scale( 1000, 100, 2, 100, 100 ) ],
  [ 100, 20 ], 'scale x, ratio 2';
is_deeply [ Gscan2pdf::Page::_prepare_scale( 100, 1000, 2, 100, 100 ) ],
  [ 5, 100 ], 'scale y, ratio 2';

#########################

unlink 'test.pnm', 'test.jpg';

__END__
