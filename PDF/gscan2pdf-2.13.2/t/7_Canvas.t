use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 36;
use Glib 1.220 qw(TRUE FALSE);    # To get TRUE and FALSE
use Gscan2pdf::Page;
use Gtk3 -init;

BEGIN {
    use_ok('Gscan2pdf::Canvas');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');

use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

# Create test image
system(qw(convert rose: test.pnm));

Gscan2pdf::Page->set_logger(Log::Log4perl::get_logger);
my $page = Gscan2pdf::Page->new(
    filename   => 'test.pnm',
    format     => 'Portable anymap',
    resolution => 72,
    dir        => File::Temp->newdir,
);

$page->import_hocr( <<'EOS');
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<meta name='ocr-system' content='tesseract'>
</head>
 <body>
  <div class='ocr_page' id='page_1' title='image "test.tif"; bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title="bbox 1 14 420 59">
    <p class='ocr_par'>
     <span class='ocr_line' id='line_1_1' title="bbox 1 14 420 59">
      <span class='ocr_word' id='word_1_1' title="bbox 1 14 77 48">
       <span class='xocr_word' id='xword_1_1' title="x_wconf 3">The—</span>
      </span>
      <span class='ocr_word' id='word_1_2' title="bbox 92 14 202 48">
       <span class='xocr_word' id='xword_1_2' title="x_wconf 74">quick</span>
      </span>
      <span class='ocr_word' id='word_1_3' title="bbox 214 14 341 48">
       <span class='xocr_word' id='xword_1_3' title="x_wconf 75">brown</span>
      </span>
      <span class='ocr_word' id='word_1_4' title="bbox 250 14 420 48">
       <span class='xocr_word' id='xword_1_4' title="x_wconf 71">fox</span>
      </span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS

my $canvas = Gscan2pdf::Canvas->new;
$canvas->sort_by_confidence;
$canvas->set_text( $page, 'text_layer', undef, FALSE );

my $bbox = $canvas->get_first_bbox;
is $bbox->get('text'), 'The—', 'get_first_bbox';
is $canvas->set_index_by_bbox( $bbox, $bbox->get('confidence') ), 0,
  'set_index_by_bbox 1';
$bbox = $canvas->get_next_bbox;
is $bbox->get('text'), 'fox', 'get_next_bbox';
is $canvas->set_index_by_bbox( $bbox, $bbox->get('confidence') ), 1,
  'set_index_by_bbox 2';
is $canvas->get_previous_bbox->get('text'), 'The—', 'get_previous_text';
$bbox = $canvas->get_last_bbox;
is $bbox->get('text'), 'brown', 'get_last_text';
is $canvas->set_index_by_bbox( $bbox, $bbox->get('confidence') ), 3,
  'set_index_by_bbox 3';

$bbox->delete_box;
is $canvas->get_last_bbox->get('text'), 'quick', 'get_last_bbox after deletion';

my $group = $canvas->get_root_item;
$group = $group->get_child(0);
($group) = $group->get_children;
($group) = $group->get_children;
($group) = $group->get_children;

$group->update_box( 'No', { x => 2, y => 15, width => 74, height => 32 } );

$canvas->add_box( 'foo', { x => 355, y => 15, width => 74, height => 32 } );

my $expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 420 59'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 420 59'>
     <span class='ocr_word' id='word_1_1' title='bbox 2 15 76 47; x_wconf 100'>No</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 48; x_wconf 74'>quick</span>
     <span class='ocr_word' id='word_1_4' title='bbox 250 14 420 48; x_wconf 71'>fox</span>
     <span class='ocr_word'  title='bbox 355 15 429 47; x_wconf 100'>foo</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

is( $canvas->hocr, $expected, 'updated hocr' );

$canvas->sort_by_position;
$bbox = $canvas->get_first_bbox;
is $bbox->get('text'),         'No',  'get_first_bbox position';
is $canvas->get_previous_bbox, undef, 'before get_first_bbox position';
$bbox = $canvas->get_next_bbox;
is $bbox->get('text'), 'quick', 'get_next_bbox position';
$bbox = $canvas->get_previous_bbox;
is $bbox->get('text'), 'No', 'get_previous_bbox position';
$bbox = $canvas->get_last_bbox;
is $bbox->get('text'),     'foo', 'get_last_bbox position';
is $canvas->get_next_bbox, undef, 'after get_last_bbox position';

#########################

# v2.10.0 had a bug where adding a word box manually where there was an overlap
# with another word box picked up the existing word box as the parent.
# A another bug prevented adding the text '0'
$canvas->add_box( '0', { x => 356, y => 15, width => 74, height => 32 } );

$expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 420 59'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 420 59'>
     <span class='ocr_word' id='word_1_1' title='bbox 2 15 76 47; x_wconf 100'>No</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 48; x_wconf 74'>quick</span>
     <span class='ocr_word' id='word_1_4' title='bbox 250 14 420 48; x_wconf 71'>fox</span>
     <span class='ocr_word'  title='bbox 355 15 429 47; x_wconf 100'>foo</span>
     <span class='ocr_word'  title='bbox 356 15 430 47; x_wconf 100'>0</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

is( $canvas->hocr, $expected,
    'the parent of a box should not be of the same class' );

#########################

$canvas->sort_by_confidence;
$canvas->get_last_bbox->update_box( 'No',
    { x => 2, y => 15, width => 75, height => 32 } );
is $canvas->get_last_bbox->get('text'), 'No',
  "don't sort if confidence hasn't changed";

#########################

is_deeply( [ $canvas->get_bounds ], [ 0, 0, 70, 46 ], 'get_bounds' );
is_deeply( $canvas->get_scale,      1,                'get_scale' );
$canvas->_set_zoom_with_center( 2, 35, 26 );
is_deeply( [ $canvas->get_bounds ], [ 0, 0, 70, 46 ], 'get_bounds after zoom' );
is_deeply(
    [ $canvas->convert_from_pixels( 0, 0 ) ],
    [ 0, 0 ],
    'convert_from_pixels'
);
my ( $width, $height ) = $page->get_size;
$canvas->set_bounds( -10, -10, $width + 10, $height + 10 );
is_deeply(
    [ $canvas->get_bounds ],
    [ -10, -10, 80, 56 ],
    'get_bounds after set'
);
is_deeply(
    [ $canvas->convert_from_pixels( 0, 0 ) ],
    [ -10, -10 ],
    'convert_from_pixels2'
);

#########################

$group->set( 'confidence', 100 );
$canvas->set( 'max-confidence', 90 );
$canvas->set( 'min-confidence', 50 );
is $group->confidence2color, 'black', '> max';
$group->set( 'confidence', 70 );
is $group->confidence2color, '#7fff3fff3fff', 'mid way';
$group->set( 'confidence', 40 );
is $group->confidence2color, 'red', '< min';

#########################

$group->update_box( '<em>No</em>',
    { x => 2, y => 15, width => 74, height => 32 } );

$expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 420 59'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 420 59'>
     <span class='ocr_word' id='word_1_1' title='bbox 2 15 76 47; x_wconf 100'>&lt;em&gt;No&lt;/em&gt;</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 48; x_wconf 74'>quick</span>
     <span class='ocr_word' id='word_1_4' title='bbox 250 14 420 48; x_wconf 71'>fox</span>
     <span class='ocr_word'  title='bbox 355 15 429 47; x_wconf 100'>foo</span>
     <span class='ocr_word'  title='bbox 356 15 430 47; x_wconf 100'>0</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

is( $canvas->hocr, $expected, 'updated hocr with HTML-escape characters' );

#########################

$page = Gscan2pdf::Page->new(
    filename   => 'test.pnm',
    format     => 'Portable anymap',
    resolution => 72,
    dir        => File::Temp->newdir,
);

$page->import_hocr( <<'EOS');
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html>
<head>
<title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<meta name='ocr-system' content='tesseract'>
</head>
 <body>
  <div class='ocr_page' id='page_1' title='image "test.tif"; bbox 0 0 204 288'>
   <div class='ocr_carea' id='block_1_1' title="bbox 1 14 202 286">
    <p class='ocr_par'>
     <span class='ocr_line' id='line_1_1' title="bbox 1 14 202 59; baseline 0.008 -9 ">
      <span class='ocr_word' id='word_1_1' title="bbox 1 14 77 48">
       <span class='xocr_word' id='xword_1_1' title="x_wconf 3">The</span>
      </span>
      <span class='ocr_word' id='word_1_2' title="bbox 92 14 202 59">
       <span class='xocr_word' id='xword_1_2' title="x_wconf 3">quick</span>
      </span>
     </span>
    </p>
    <p class='ocr_par'>
     <span class='ocr_line' id='line_1_2' title="bbox 1 80 35 286; textangle 90">
      <span class='ocr_word' id='word_1_4' title="bbox 1 80 35 195">
       <span class='xocr_word' id='xword_1_4' title="x_wconf 4">fox</span>
      </span>
      <span class='ocr_word' id='word_1_3' title="bbox 1 159 35 286">
       <span class='xocr_word' id='xword_1_3' title="x_wconf 3">brown</span>
      </span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS

$canvas = Gscan2pdf::Canvas->new;
$canvas->set_text( $page, 'text_layer', undef, FALSE );
$canvas->sort_by_confidence;

$expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 204 288'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 202 286'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 202 59; baseline 0.008 -9'>
     <span class='ocr_word' id='word_1_1' title='bbox 1 14 77 48; x_wconf 3'>The</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 59; x_wconf 3'>quick</span>
    </span>
    <span class='ocr_line' id='line_1_2' title='bbox 1 80 35 286; textangle 90'>
     <span class='ocr_word' id='word_1_3' title='bbox 1 159 35 286; x_wconf 3'>brown</span>
     <span class='ocr_word' id='word_1_4' title='bbox 1 80 35 195; x_wconf 4'>fox</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS

is( $canvas->hocr, $expected, 'updated hocr with extended hOCR properties' );

#########################

$group = $canvas->get_root_item;

# get page 'page_1'
$group = $group->get_child(0);

# get column/carea 'block_1'
$group = $group->get_child(1);

# get line 'line_1_2'
$group = $group->get_child(2);

# get word 'word_1_3'
$bbox = $group->get_child(1);

isa_ok( $bbox, 'Gscan2pdf::Canvas::Bbox' );
is( $bbox->{textangle},           0,  "word_1_3's textangle is 0" );
is( $bbox->{transformation}->[0], 90, "word_1_3's (inherited) rotation is 90" );

my $textwidget = $bbox->get_text_widget;

isa_ok( $textwidget, 'GooCanvas2::CanvasText' );

my @transform = $textwidget->get_simple_transform();

is( $transform[-1], 270,
    "word_1_3's text widget rotation matches the 90° rotation" );

#########################

$bbox = $canvas->get_first_bbox;
$bbox->delete_box;
$bbox = $canvas->get_next_bbox;
$bbox->delete_box;
$bbox = $canvas->get_next_bbox;
$bbox->delete_box;
$bbox = $canvas->get_next_bbox;
$bbox->delete_box;
is $canvas->get_last_bbox, undef, 'get_last_bbox() returns undef if no boxes';

#########################

$page = Gscan2pdf::Page->new(
    filename   => 'test.pnm',
    format     => 'Portable anymap',
    resolution => 72,
    dir        => File::Temp->newdir,
);
$page->import_text('The quick brown fox');

$canvas = Gscan2pdf::Canvas->new;
$canvas->set_text( $page, 'text_layer', undef, FALSE );
$expected = <<"EOS";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page'  title='bbox 0 0 70 46'>The quick brown fox</div>
 </body>
</html>
EOS

is( $canvas->hocr, $expected, 'canvas2hocr from simple text' );

#########################

unlink 'test.pnm';

__END__
