use warnings;
use strict;
use Test::More tests => 12;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;
use Scalar::Util;
use Date::Calc qw(Today_and_Now);

BEGIN {
    use_ok('Gscan2pdf::Dialog::Save');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
my $window = Gtk3::Window->new;

ok(
    my $dialog = Gscan2pdf::Dialog::Save->new(
        title                       => 'title',
        'transient-for'             => $window,
        'meta-datetime'             => [ 2017, 01, 01 ],
        'select-datetime'           => TRUE,
        'meta-title'                => 'title',
        'meta-title-suggestions'    => ['title-suggestion'],
        'meta-author'               => 'author',
        'meta-author-suggestions'   => ['author-suggestion'],
        'meta-subject'              => 'subject',
        'meta-subject-suggestions'  => ['subject-suggestion'],
        'meta-keywords'             => 'keywords',
        'meta-keywords-suggestions' => ['keyword-suggestion'],
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Save' );

$dialog->add_metadata;
is_deeply( $dialog->get('meta-datetime'), [ 2017, 1, 1, 0, 0, 0 ], 'date' );
is( $dialog->get('meta-author'),   'author',   'author' );
is( $dialog->get('meta-title'),    'title',    'title' );
is( $dialog->get('meta-subject'),  'subject',  'subject' );
is( $dialog->get('meta-keywords'), 'keywords', 'keywords' );

$dialog = Gscan2pdf::Dialog::Save->new(
    'transient-for'   => $window,
    'include-time'    => TRUE,
    'meta-datetime'   => [ 2017, 01, 01, 23, 59, 5 ],
    'select-datetime' => TRUE,
);
$dialog->add_metadata;
is_deeply(
    $dialog->get('meta-datetime'),
    [ 2017, 01, 01, 23, 59, 5 ],
    'date and time'
);

$dialog = Gscan2pdf::Dialog::Save->new(
    'transient-for' => $window,
    'include-time'  => TRUE,
    'meta-datetime' => [ 2017, 01, 01, 23, 59, 5 ],
);
$dialog->add_metadata;
is_deeply( $dialog->get('meta-datetime'), [Today_and_Now], 'now' );

# Build a look-up table of all true-type fonts installed
my ( undef, $stdout ) =
  Gscan2pdf::Document::exec_command( ['fc-list : family style file'] );
my $fonts = Gscan2pdf::Document::parse_truetype_fonts($stdout);

$dialog = Gscan2pdf::Dialog::Save->new(
    'transient-for'   => $window,
    'image-types'     => [qw(pdf gif jpg png pnm ps tif txt hocr session)],
    'ps-backends'     => [qw(libtiff pdf2ps pdftops)],
    'available-fonts' => $fonts,
    'pdf-font'        => '/does/not/exist',
);
$dialog->add_metadata;
$dialog->add_image_type;
is $dialog->get('ps-backend'), 'pdftops',         'default ps backend';
isnt $dialog->get('pdf-font'), '/does/not/exist', 'correct non-existant font';

__END__
