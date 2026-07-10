use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 72;
use Glib 1.210 qw(TRUE FALSE);
use Gtk3 -init;    # Could just call init separately
use Encode;
use PDF::Builder;
use File::stat;
use Date::Calc qw(Time_to_Date);

BEGIN {
    use_ok('Gscan2pdf::Document');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

my $slist = Gscan2pdf::Document->new;
is( $slist->pages_possible( 1, 1 ),
    -1, 'pages_possible infinite forwards in empty document' );
is( $slist->pages_possible( 2, -1 ),
    2, 'pages_possible finite backwards in empty document' );
is( $slist->pages_possible( 1, -2 ),
    1, 'pages_possible finite backwards in empty document #2' );

my @selected = $slist->get_page_index( 'all', sub { pass('error in all') } );
is_deeply( \@selected, [], 'no pages' );

$slist->get_model->signal_handler_block( $slist->{row_changed_signal} );
@{ $slist->{data} } = ( [ 2, undef, undef ] );
@selected =
  $slist->get_page_index( 'selected', sub { pass('error in selected') } );
is_deeply( \@selected, [], 'none selected' );

$slist->select(0);
@selected =
  $slist->get_page_index( 'selected', sub { fail('no error in selected') } );
is_deeply( \@selected, [0], 'selected' );
@selected = $slist->get_page_index( 'all', sub { fail('no error in all') } );
is_deeply( \@selected, [0], 'all' );

is( $slist->pages_possible( 2, 1 ), 0,
    'pages_possible 0 due to existing page' );
is( $slist->pages_possible( 1, 1 ),
    1, 'pages_possible finite forwards in non-empty document' );
is( $slist->pages_possible( 1, -1 ),
    1, 'pages_possible finite backwards in non-empty document' );

$slist->{data}[0][0] = 1;
is( $slist->pages_possible( 2, 1 ),
    -1, 'pages_possible infinite forwards in non-empty document' );

@{ $slist->{data} } =
  ( [ 1, undef, undef ], [ 2, undef, undef ], [ 3, undef, undef ] );
is( $slist->pages_possible( 2, -2 ),
    0, 'pages_possible several existing pages and negative step' );

@{ $slist->{data} } =
  ( [ 1, undef, undef ], [ 3, undef, undef ], [ 5, undef, undef ] );
is( $slist->pages_possible( 2, 1 ),
    1, 'pages_possible finite forwards starting in middle of range' );
is( $slist->pages_possible( 2, -1 ),
    1, 'pages_possible finite backwards starting in middle of range' );
is( $slist->pages_possible( 6, -2 ),
    3, 'pages_possible finite backwards starting at end of range' );
is( $slist->pages_possible( 2, 2 ),
    -1, 'pages_possible infinite forwards starting in middle of range' );

#########################

is( $slist->valid_renumber( 1, 1,  'all' ), TRUE, 'valid_renumber all step 1' );
is( $slist->valid_renumber( 3, -1, 'all' ),
    TRUE, 'valid_renumber all start 3 step -1' );
is( $slist->valid_renumber( 2, -1, 'all' ),
    FALSE, 'valid_renumber all start 2 step -1' );

$slist->select(0);
is( $slist->valid_renumber( 1, 1, 'selected' ),
    TRUE, 'valid_renumber selected ok' );
is( $slist->valid_renumber( 3, 1, 'selected' ),
    FALSE, 'valid_renumber selected nok' );

#########################

$slist->renumber( 1, 1, 'all' );
is_deeply(
    $slist->{data},
    [ [ 1, undef, undef ], [ 2, undef, undef ], [ 3, undef, undef ] ],
    'renumber start 1 step 1'
);

#########################

@{ $slist->{data} } = (
    [ 1, undef, undef ],
    [ 6, undef, undef ],
    [ 7, undef, undef ],
    [ 8, undef, undef ]
);
is( $slist->pages_possible( 2, 1 ),
    4, 'pages_possible finite forwards starting in middle of range2' );

#########################

@{ $slist->{data} } = (
    [ 1,  undef, undef ],
    [ 3,  undef, undef ],
    [ 5,  undef, undef ],
    [ 7,  undef, undef ],
    [ 9,  undef, undef ],
    [ 11, undef, undef ],
    [ 13, undef, undef ],
    [ 15, undef, undef ],
    [ 17, undef, undef ],
    [ 19, undef, undef ]
);
is $slist->index_for_page( 12, 0, 11, 1 ),
  -1, 'index_for_page correctly returns no index';
is $#{ $slist->{data} }, 9, 'index_for_page does not inadvertanty create pages';

#########################

is $slist->find_page_by_uuid('someuuid'),
  undef, "no warning if a page has no uuid for some reason";

#########################

@{ $slist->{data} } =
  ( [ 1, undef, { uuid => 'aa' } ], [ 2, undef, { uuid => 'ab' } ] );
$slist->select(0);
$slist->get_model->signal_handler_unblock( $slist->{row_changed_signal} );
$slist->{data}[0][0] = 3;
is_deeply( [ $slist->get_selected_indices ],
    [1], 'correctly selected page after manual renumber' );

Gscan2pdf::Document->quit();

#########################

( undef, my $fonts ) =
  Gscan2pdf::Document::exec_command( ['fc-list : family style file'] );
like( $fonts, qr/\w+/, 'exec_command produces some output from fc-list' );

( undef, $fonts ) =
  Gscan2pdf::Document::exec_command( [ 'perl', '-e', 'print "a" x 65537' ] );
is( length $fonts, 65537, 'exec_command returns more than 65537 bytes' );

#########################

my @date = Gscan2pdf::Document::text_to_datetime('2016-02-01');
is_deeply( \@date, [ 2016, 2, 1, 0, 0, 0 ], 'text_to_datetime just date' );

@date = Gscan2pdf::Document::text_to_datetime('2016-02-01 10:11:12');
is_deeply( \@date, [ 2016, 2, 1, 10, 11, 12 ], 'text_to_datetime' );

@date = Gscan2pdf::Document::text_to_datetime( '', 2016, 2, 1 );
is_deeply( \@date, [ 2016, 2, 1, 0, 0, 0 ], 'text_to_datetime empty string' );

@date = Gscan2pdf::Document::text_to_datetime( '0000-00-00', 2016, 2, 1 );
is_deeply( \@date, [ 2016, 2, 1, 0, 0, 0 ], 'text_to_datetime invalid date' );

#########################

is Gscan2pdf::Document::expand_metadata_pattern(
    template      => '%Da %Dt %Ds %Dk %DY %Y %Dm %m %Dd %d %H %M %S.%De',
    author        => 'a.n.other',
    title         => 'title',
    subject       => 'subject',
    keywords      => 'keywords',
    docdate       => [ 2016, 02, 01 ],
    today_and_now => [ 1970, 01, 12, 14, 46, 39 ],
    extension     => 'png',
  ),
  'a.n.other title subject keywords 2016 1970 02 01 01 12 14 46 39.png',
  'expand_metadata_pattern';

is(
    Gscan2pdf::Document::expand_metadata_pattern(
        template => '%Da %Dt %DY %Y %Dm %m %Dd %d %H %M %S %DH %DM %DS.%De',
        author   => 'a.n.other',
        title    => 'title',
        docdate       => [ 2016, 02, 01, 10, 11, 12 ],
        today_and_now => [ 1970, 01, 12, 14, 46, 39 ],
        extension     => 'tif',
    ),
    'a.n.other title 2016 1970 02 01 01 12 14 46 39 10 11 12.tif',
    'expand_metadata_pattern with doc time'
);

is(
    Gscan2pdf::Document::expand_metadata_pattern(
        template      => '%Da %Dt %DY %Y %Dm %m %Dd %d %H %M %S.%De',
        author        => 'a.n.other',
        title         => 'title',
        docdate       => [ 1816, 02, 01 ],
        today_and_now => [ 1970, 01, 12, 14, 46, 39 ],
        extension     => 'djvu',
    ),
    'a.n.other title 1816 1970 02 01 01 12 14 46 39.djvu',
    'expand_metadata_pattern before 1900'
);

is(
    Gscan2pdf::Document::expand_metadata_pattern(
        template           => '%Da %Dt %DY %Y %Dm %m %Dd %d %H %M %S.%De',
        convert_whitespace => TRUE,
        author             => 'a.n.other',
        title              => 'title',
        docdate            => [ 2016, 02, 01 ],
        today_and_now      => [ 1970, 01, 12, 14, 46, 39 ],
        extension          => 'pdf',
    ),
    'a.n.other_title_2016_1970_02_01_01_12_14_46_39.pdf',
    'expand_metadata_pattern with underscores'
);

#########################

is_deeply(
    Gscan2pdf::Document::prepare_output_metadata(
        'PDF',
        {
            datetime   => [ 2016, 2, 10, 0, 0, 0 ],
            author     => 'a.n.other',
            title      => 'title',
            'subject'  => 'subject',
            'keywords' => 'keywords'
        }
    ),
    {
        ModDate      => "D:20160210000000+00'00'",
        Creator      => "gscan2pdf v$Gscan2pdf::Document::VERSION",
        Author       => 'a.n.other',
        Title        => 'title',
        Subject      => 'subject',
        Keywords     => 'keywords',
        CreationDate => "D:20160210000000+00'00'"
    },
    'prepare_output_metadata'
);

is_deeply(
    Gscan2pdf::Document::prepare_output_metadata(
        'PDF',
        {
            datetime   => [ 2016, 2, 10, 0, 0, 0 ],
            tz         => [ 0,    0, 0,  1, 0, 0, 0 ],
            author     => 'a.n.other',
            title      => 'title',
            'subject'  => 'subject',
            'keywords' => 'keywords'
        }
    ),
    {
        ModDate      => "D:20160210000000+01'00'",
        Creator      => "gscan2pdf v$Gscan2pdf::Document::VERSION",
        Author       => 'a.n.other',
        Title        => 'title',
        Subject      => 'subject',
        Keywords     => 'keywords',
        CreationDate => "D:20160210000000+01'00'"
    },
    'prepare_output_metadata with tz'
);

is_deeply(
    Gscan2pdf::Document::prepare_output_metadata(
        'PDF',
        {
            datetime   => [ 2016, 2, 10, 19, 59, 5 ],
            tz         => [ 0,    0, 0,  1,  0,  0, 0 ],
            author     => 'a.n.other',
            title      => 'title',
            'subject'  => 'subject',
            'keywords' => 'keywords'
        }
    ),
    {
        ModDate      => "D:20160210195905+01'00'",
        Creator      => "gscan2pdf v$Gscan2pdf::Document::VERSION",
        Author       => 'a.n.other',
        Title        => 'title',
        Subject      => 'subject',
        Keywords     => 'keywords',
        CreationDate => "D:20160210195905+01'00'"
    },
    'prepare_output_metadata with time'
);

#########################

my %settings = (
    author            => 'a.n.other',
    title             => 'title',
    subject           => 'subject',
    keywords          => 'keywords',
    'datetime offset' => [ 2, 0, 59, 59 ],
    'timezone offset' => [ 0, 0, 0,  0, 0, 0, 0 ],
);
my @today_and_now = ( 2016, 2,  10, 1, 2, 3 );
my @timezone      = ( 0,    0,  0,  1, 0, 0, 0 );
my @time          = ( 19,   59, 5 );
is_deeply(
    Gscan2pdf::Document::collate_metadata(
        \%settings, \@today_and_now, \@timezone
    ),
    {
        datetime   => [ 2016, 2, 12, 0, 0, 0 ],
        author     => 'a.n.other',
        title      => 'title',
        'subject'  => 'subject',
        'keywords' => 'keywords'
    },
    'collate basic metadata'
);

$settings{'use_timezone'} = TRUE;
is_deeply(
    Gscan2pdf::Document::collate_metadata(
        \%settings, \@today_and_now, \@timezone
    ),
    {
        datetime   => [ 2016, 2, 12, 0, 0, 0 ],
        tz         => [ 0,    0, 0,  1, 0, 0, 0 ],
        author     => 'a.n.other',
        title      => 'title',
        'subject'  => 'subject',
        'keywords' => 'keywords'
    },
    'collate timezone'
);

$settings{'use_time'} = TRUE;
is_deeply(
    Gscan2pdf::Document::collate_metadata(
        \%settings, \@today_and_now, \@timezone
    ),
    {
        datetime   => [ 2016, 2, 12, 2, 2, 2 ],
        tz         => [ 0,    0, 0,  1, 0, 0, 0 ],
        author     => 'a.n.other',
        title      => 'title',
        'subject'  => 'subject',
        'keywords' => 'keywords'
    },
    'collate time'
);

@today_and_now               = ( 2016, 6, 10, 1, 2, 3 );
@timezone                    = ( 0,    0, 0,  2, 0, 0, 1 );
$settings{'datetime offset'} = [ -119, 0, 59, 59 ];
$settings{'timezone offset'} = [ 0,    0, 0,  -1, 0, 0, -1 ];
is_deeply(
    Gscan2pdf::Document::collate_metadata(
        \%settings, \@today_and_now, \@timezone
    ),
    {
        datetime   => [ 2016, 2, 12, 2, 2, 2 ],
        tz         => [ 0,    0, 0,  1, 0, 0, 0 ],
        author     => 'a.n.other',
        title      => 'title',
        'subject'  => 'subject',
        'keywords' => 'keywords'
    },
    'collate dst at time of docdate'
);

#########################

my @tz1      = ( 0, 0, 0, 2,  0, 0, 1 );
my @tz_delta = ( 0, 0, 0, -1, 0, 0, -1 );
my @tz2      = Gscan2pdf::Document::add_delta_timezone( @tz1, @tz_delta );
is_deeply \@tz2, [ 0, 0, 0, 1, 0, 0, 0 ], 'Add_Delta_Timezone';

@tz_delta = Gscan2pdf::Document::delta_timezone( @tz1, @tz2 );
is_deeply \@tz_delta, [ 0, 0, 0, -1, 0, 0, -1 ], 'Delta_Timezone';

# can't test exact result, as depends on timezone of test machine
is Gscan2pdf::Document::delta_timezone_to_current( [ 2016, 1, 1, 2, 2, 2 ] ),
  7, 'delta_timezone_to_current()';
is_deeply [
    Gscan2pdf::Document::delta_timezone_to_current( [ 1966, 1, 1, 2, 2, 2 ] ) ],
  [ 0, 0, 0, 0, 0, 0, 0 ], 'delta_timezone_to_current() for <1970';

#########################

is_deeply(
    Gscan2pdf::Document::_extract_metadata(
        {
            format   => 'Portable Document Format',
            datetime => '2016-08-06T02:00:00Z'
        }
    ),
    {
        datetime => [ 2016,  8,     6,     2, 0, 0 ],
        tz       => [ undef, undef, undef, 0, 0, undef, undef ],
    },
    '_extract_metadata'
);

is_deeply(
    Gscan2pdf::Document::_extract_metadata(
        {
            format   => 'Portable Document Format',
            datetime => '2016-08-06T02:00:00+02'
        }
    ),
    {
        datetime => [ 2016,  8,     6,     2, 0, 0 ],
        tz       => [ undef, undef, undef, 2, 0, undef, undef ],
    },
    '_extract_metadata'
);

is_deeply(
    Gscan2pdf::Document::_extract_metadata(
        {
            format   => 'Portable Document Format',
            datetime => '2019-01-01T02:00:00+14'
        }
    ),
    {
        datetime => [ 2019,  1,     1,     2,  0, 0 ],
        tz       => [ undef, undef, undef, 14, 0, undef, undef ],
    },
    '_extract_metadata GMT+14'
);

is_deeply(
    Gscan2pdf::Document::_extract_metadata(
        {
            format   => 'Portable Document Format',
            datetime => 'non-parsable date'
        }
    ),
    {},
    '_extract_metadata on error'
);

is_deeply(
    Gscan2pdf::Document::_extract_metadata(
        {
            format   => 'Portable Document Format',
            datetime => 'non-parsable-string'
        }
    ),
    {},
    '_extract_metadata on error 2'
);

#########################

my $filename = 'test.txt';
system( 'touch', $filename );
my %options = (
    path     => $filename,
    options  => { set_timestamp => TRUE },
    metadata => { datetime      => [ 2016, 2, 10, 0, 0, 0 ], }
);
Gscan2pdf::Document::_set_timestamp( undef, %options );
my $sb = stat($filename);
is_deeply [ Time_to_Date( $sb->mtime ) ], [ 2016, 2, 10, 0, 0, 0 ],
  'timestamp no timezone';

$options{metadata}{tz} = [ undef, undef, undef, 14, 0, undef, undef ];
Gscan2pdf::Document::_set_timestamp( undef, %options );
$sb = stat($filename);
is_deeply [ Time_to_Date( $sb->mtime ) ], [ 2016, 2, 9, 10, 0, 0 ],
  'timestamp with timezone';

#########################

is(
    Gscan2pdf::Document::_program_version(
        'stdout', qr/file-(\d+\.\d+)/xsm, 0, "file-5.22\nmagic file from"
    ),
    '5.22',
    'file version'
);
is(
    Gscan2pdf::Document::_program_version(
        'stdout', qr/Version:\sImageMagick\s([\d.-]+)/xsm,
        0,        "Version: ImageMagick 6.9.0-3 Q16"
    ),
    '6.9.0-3',
    'imagemagick version'
);
is(
    Gscan2pdf::Document::_program_version(
        'stdout', qr/Version:\sImageMagick\s([\d.-]+)/xsm,
        0,        "Version:ImageMagick 6.9.0-3 Q16"
    ),
    undef,
    'unable to parse version'
);
is(
    Gscan2pdf::Document::_program_version(
        'stdout', qr/Version:\sImageMagick\s([\d.-]+)/xsm,
        -1, "", 'convert: command not found'
    ),
    -1,
    'command not found'
);
is(
    Gscan2pdf::Document::_program_version(
        'stdout', qr/Version:\sImageMagick\s([\d.-]+)/xsm,
        -1, undef, 'convert: command not found'
    ),
    -1,
    'catch undefined stdout'
);

my ( $status, $out, $err ) =
  Gscan2pdf::Document::exec_command( ['/command/not/found'] );
is( $status, -1, 'status open3 running unknown command' );
is(
    $err,
    '/command/not/found: command not found',
    'stderr open3 running unknown command'
);

my $pdf  = PDF::Builder->new;
my $font = $pdf->corefont('Times-Roman');
is( Gscan2pdf::Document::font_can_char( $font, decode_utf8('a') ),
    TRUE, '_font_can_char a' );
is( Gscan2pdf::Document::font_can_char( $font, decode_utf8('ö') ),
    TRUE, '_font_can_char ö' );
is( Gscan2pdf::Document::font_can_char( $font, decode_utf8('п') ),
    FALSE, '_font_can_char п' );

#########################

my $fclist = <<'EOS';
/usr/local/share/fonts/Cairo-ExtraLight.ttf: Cairo,Cairo ExtraLight:style=ExtraLight,Regular
/usr/local/share/fonts/FaustinaVFBeta-Italic.ttf: Faustina VF Beta
EOS
is_deeply Gscan2pdf::Document::parse_truetype_fonts($fclist),
  {
    'by_family' => {
        'Cairo' => {
            'ExtraLight' => '/usr/local/share/fonts/Cairo-ExtraLight.ttf'
        }
    },
    'by_file' => {
        '/usr/local/share/fonts/Cairo-ExtraLight.ttf' =>
          [ 'Cairo', 'ExtraLight' ]
    }
  },
  'parse_truetype_fonts() only returns fonts for which we have a style';

#########################

is Gscan2pdf::Document::get_tmp_dir(
    '/tmp/gscan2pdf-wxyz/gscan2pdf-wxyz/gscan2pdf-wxyz',
    'gscan2pdf-\w\w\w\w'
  ),
  '/tmp', 'get_tmp_dir';
is Gscan2pdf::Document::get_tmp_dir( undef, 'gscan2pdf-\w\w\w\w' ), undef,
  'get_tmp_dir undef';

#########################

is_deeply Gscan2pdf::Document::_bbox2markup( 300, 300, 500, 0, 0, 452, 57 ),
  [ 0, 486.32, 108.48, 486.32, 0, 500, 108.48, 500 ],
  'converted bbox to markup coords';

#########################

__END__
