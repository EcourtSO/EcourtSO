use warnings;
use strict;
use Encode;
use Test::More tests => 31;

BEGIN {
    use_ok('Gscan2pdf::Bboxtree');
}

#########################

my $hocr = <<'EOS';
                  '<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
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
 <span class='ocr_word' id='word_1_1' title="bbox 1 14 77 48"><span class='xocr_word' id='xword_1_1' title="x_wconf -3">The</span></span>
 <span class='ocr_word' id='word_1_2' title="bbox 92 14 202 59"><span class='xocr_word' id='xword_1_2' title="x_wconf -3">quick</span></span>
 <span class='ocr_word' id='word_1_3' title="bbox 214 14 341 48"><span class='xocr_word' id='xword_1_3' title="x_wconf -3">brown</span></span>
 <span class='ocr_word' id='word_1_4' title="bbox 355 14 420 48"><span class='xocr_word' id='xword_1_4' title="x_wconf -4">fox</span></span>
</span>
</p>
</div>
</div>
</body>
</html>
EOS
my $tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
my $iter = $tree->get_bbox_iter($hocr);
my $bbox = $iter->();
is_deeply $bbox,
  {
    type  => 'page',
    id    => 'page_1',
    bbox  => [ 0, 0, 422, 61 ],
    depth => 0,
  },
  'page from tesseract 3.00';
$bbox = $iter->();
is_deeply $bbox,
  {
    type  => 'column',
    id    => 'block_1_1',
    bbox  => [ 1, 14, 420, 59 ],
    depth => 1,
  },
  'column from tesseract 3.00';
$bbox = $iter->();
is_deeply $bbox,
  {
    type  => 'line',
    id    => 'line_1_1',
    bbox  => [ 1, 14, 420, 59 ],
    depth => 2,
  },
  'line from tesseract 3.00';
is_deeply $iter->(),
  {
    type       => 'word',
    id         => 'word_1_1',
    bbox       => [ 1, 14, 77, 48 ],
    text       => 'The',
    confidence => -3,
    depth      => 3,
  },
  'The from tesseract 3.00';
is_deeply $iter->(),
  {
    type       => 'word',
    id         => 'word_1_2',
    bbox       => [ 92, 14, 202, 59 ],
    text       => 'quick',
    confidence => -3,
    depth      => 3,
  },
  'quick from tesseract 3.00';
is_deeply $iter->(),
  {
    type       => 'word',
    id         => 'word_1_3',
    bbox       => [ 214, 14, 341, 48 ],
    text       => 'brown',
    confidence => -3,
    depth      => 3,
  },
  'brown from tesseract 3.00';
is_deeply $iter->(),
  {
    type       => 'word',
    id         => 'word_1_4',
    bbox       => [ 355, 14, 420, 48 ],
    text       => 'fox',
    confidence => -4,
    depth      => 3,
  },
  'fox from tesseract 3.00';
is $iter->(), undef, 'no more';

#########################

my $expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Bboxtree::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 422 61'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 14 420 59'>
    <span class='ocr_line' id='line_1_1' title='bbox 1 14 420 59'>
     <span class='ocr_word' id='word_1_1' title='bbox 1 14 77 48; x_wconf -3'>The</span>
     <span class='ocr_word' id='word_1_2' title='bbox 92 14 202 59; x_wconf -3'>quick</span>
     <span class='ocr_word' id='word_1_3' title='bbox 214 14 341 48; x_wconf -3'>brown</span>
     <span class='ocr_word' id='word_1_4' title='bbox 355 14 420 48; x_wconf -4'>fox</span>
    </span>
   </div>
  </div>
 </body>
</html>
EOS
is $tree->to_hocr, $expected, 'to_hocr basic functionality';

#########################

$tree = Gscan2pdf::Bboxtree->new;
$tree->from_text( 'The quick brown fox', 422, 61 );
$iter = $tree->get_bbox_iter();
$bbox = $iter->();
is_deeply $bbox,
  {
    type  => 'page',
    bbox  => [ 0, 0, 422, 61 ],
    text  => 'The quick brown fox',
    depth => 0,
  },
  'page from plain text';

$expected = <<'EOS';
(page 0 0 422 61 "The quick brown fox")
EOS
is_deeply $tree->to_djvu_txt, $expected, 'to_djvu_txt from simple text';

#########################

$hocr = <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title></title>
  <meta http-equiv="Content-Type" content="text/html; charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.02.01' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='image "test.png"; bbox 0 0 494 57; ppageno 0'>
   <div class='ocr_carea' id='block_1_1' title="bbox 1 9 490 55">
    <p class='ocr_par' dir='ltr' id='par_1' title="bbox 1 9 490 55">
     <span class='ocr_line' id='line_1' title="bbox 1 9 490 55"><span class='ocrx_word' id='word_1' title="bbox 1 9 88 45"><strong>The</strong></span> <span class='ocrx_word' id='word_2' title="bbox 106 9 235 55">quick</span> <span class='ocrx_word' id='word_3' title="bbox 253 9 397 45"><strong>brown</strong></span> <span class='ocrx_word' id='word_4' title="bbox 416 9 490 45"><strong>fox</strong></span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
my @boxes = (
    {
        type  => 'page',
        id    => 'page_1',
        bbox  => [ 0, 0, 494, 57 ],
        depth => 0,
    },
    {
        type  => 'column',
        id    => 'block_1_1',
        bbox  => [ 1, 9, 490, 55 ],
        depth => 1,
    },
    {
        type  => 'para',
        id    => 'par_1',
        bbox  => [ 1, 9, 490, 55 ],
        depth => 2,
    },
    {
        type  => 'line',
        id    => 'line_1',
        bbox  => [ 1, 9, 490, 55 ],
        depth => 3,
    },
    {
        type  => 'word',
        id    => 'word_1',
        bbox  => [ 1, 9, 88, 45 ],
        text  => 'The',
        depth => 4,
        style => ['Bold']
    },
    {
        type  => 'word',
        id    => 'word_2',
        bbox  => [ 106, 9, 235, 55 ],
        depth => 4,
        text  => 'quick'
    },
    {
        type  => 'word',
        id    => 'word_3',
        bbox  => [ 253, 9, 397, 45 ],
        text  => 'brown',
        depth => 4,
        style => ['Bold']
    },
    {
        type  => 'word',
        id    => 'word_4',
        bbox  => [ 416, 9, 490, 45 ],
        text  => 'fox',
        depth => 4,
        style => ['Bold']
    },
);
is_deeply $tree, \@boxes, 'Boxes from tesseract 3.02.01';

#########################

$expected = <<"EOS";
<\?xml version="1.0" encoding="UTF-8"\?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Bboxtree::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='bbox 0 0 494 57'>
   <div class='ocr_carea' id='block_1_1' title='bbox 1 9 490 55'>
    <p class='ocr_par' id='par_1' title='bbox 1 9 490 55'>
     <span class='ocr_line' id='line_1' title='bbox 1 9 490 55'>
      <span class='ocr_word' id='word_1' title='bbox 1 9 88 45'><strong>The</strong></span>
      <span class='ocr_word' id='word_2' title='bbox 106 9 235 55'>quick</span>
      <span class='ocr_word' id='word_3' title='bbox 253 9 397 45'><strong>brown</strong></span>
      <span class='ocr_word' id='word_4' title='bbox 416 9 490 45'><strong>fox</strong></span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
is $tree->to_hocr, $expected, 'to_hocr with par and style';

#########################

$hocr = <<'EOS';
<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
    http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><meta content="ocr_line ocr_page" name="ocr-capabilities"/><meta content="en" name="ocr-langs"/><meta content="Latn" name="ocr-scripts"/><meta content="" name="ocr-microformats"/><title>OCR Output</title></head>
<body><div class="ocr_page" title="bbox 0 0 274 58; image test.png"><span class="ocr_line" title="bbox 3 1 271 47">&#246;&#246;&#228;ii&#252;&#252;&#223; &#8364;
</span></div></body></html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 274, 58 ],
        depth => 0,
    },
    {
        type  => 'line',
        bbox  => [ 3, 1, 271, 47 ],
        text  => decode_utf8('ööäiiüüß €'),
        depth => 1,
    },
);
is_deeply $tree, \@boxes, 'Boxes from ocropus 0.3 with UTF8';

#########################

$hocr = <<'EOS';
<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
    http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><meta content="ocr_line ocr_page" name="ocr-capabilities"/><meta content="en" name="ocr-langs"/><meta content="Latn" name="ocr-scripts"/><meta content="" name="ocr-microformats"/><title>OCR Output</title></head>
<body><div class="ocr_page" title="bbox 0 0 202 114; image /tmp/GgRiywY66V/qg_kooDQKE.pnm"><span class="ocr_line" title="bbox 22 26 107 39">&#164;&#246;A&#228;U&#252;&#223;'
</span><span class="ocr_line" title="bbox 21 74 155 87">Test Test Test E
</span></div></body></html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 202, 114 ],
        depth => 0,
    },
    {
        type  => 'line',
        bbox  => [ 22, 26, 107, 39 ],
        text  => "\x{a4}\x{f6}A\x{e4}U\x{fc}\x{df}'",
        depth => 1,
    },
    {
        type  => 'line',
        bbox  => [ 21, 74, 155, 87 ],
        text  => 'Test Test Test E',
        depth => 1,
    },
);
is_deeply $tree, \@boxes, 'More boxes from ocropus 0.3 with UTF8';

#########################

$hocr = <<'EOS';
<!DOCTYPE html
    PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN
    http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml"><head><meta content="ocr_line ocr_page" name="ocr-capabilities"/><meta content="en" name="ocr-langs"/><meta content="Latn" name="ocr-scripts"/><meta content="" name="ocr-microformats"/><title>OCR Output</title></head>
<body><div class="ocr_page" title="bbox 0 0 422 61; image test.png"><span class="ocr_line" title="bbox 1 14 420 59">The quick brown fox
</span></div></body></html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 422, 61 ],
        depth => 0,
    },
    {
        type  => 'line',
        bbox  => [ 1, 14, 420, 59 ],
        text  => 'The quick brown fox',
        depth => 1,
    },
);
is_deeply $tree, \@boxes, 'Boxes from ocropus 0.4';

#########################

$hocr = <<'EOS';
<!DOCTYPE html PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd">
<html><head><title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" >
<meta name='ocr-system' content='openocr'>
</head>
<body><div class='ocr_page' id='page_1' title='image "test.bmp"; bbox 0 0 422 61'>
<p><span class='ocr_line' id='line_1' title="bbox 1 15 420 60">The quick brown fox<span class='ocr_cinfo' title="x_bboxes 1 15 30 49 31 15 55 49 57 27 77 49 -1 -1 -1 -1 92 27 114 60 116 27 139 49 141 15 153 49 155 27 175 49 176 15 202 49 -1 -1 -1 -1 214 15 237 49 239 27 256 49 257 27 279 49 282 27 315 49 317 27 341 49 -1 -1 -1 -1 355 15 373 49 372 27 394 49 397 27 420 49 "></span></span>
</p>
<p><span class='ocr_line' id='line_2' title="bbox 0 0 0 0"></span>
</p>
</div></body></html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
@boxes = (
    {
        type  => 'page',
        id    => 'page_1',
        bbox  => [ 0, 0, 422, 61 ],
        depth => 0,
    },
    {
        type  => 'line',
        id    => 'line_1',
        bbox  => [ 1, 15, 420, 60 ],
        text  => 'The quick brown fox',
        depth => 1,
    },
);
is_deeply $tree, \@boxes, 'Boxes from cuneiform 1.0.0';

#########################

$expected = <<'EOS';
(page 0 0 422 61
  (line 1 1 420 46 "The quick brown fox"))
EOS

is_deeply $tree->to_djvu_txt, $expected, 'djvu from cuneiform 1.0.0';

#########################

$hocr = <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>
</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.03' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
</head>
<body>
  <div class='ocr_page' id='page_1' title='image "0020_1L.tif"; bbox 0 0 2236 3185; ppageno 0'>
   <div class='ocr_carea' id='block_1_1' title="bbox 157 80 1725 174">
    <p class='ocr_par' dir='ltr' id='par_1_1' title="bbox 157 84 1725 171">
     <span class='ocr_line' id='line_1_1' title="bbox 157 84 1725 171; baseline -0.003 -17">
      <span class='ocrx_word' id='word_1_1' title='bbox 157 90 241 155; x_wconf 85' lang='fra'>28</span>
      <span class='ocrx_word' id='word_1_2' title='bbox 533 86 645 152; x_wconf 90' lang='fra' dir='ltr'>LA</span>
      <span class='ocrx_word' id='word_1_3' title='bbox 695 86 1188 171; x_wconf 75' lang='fra' dir='ltr'>MARQUISE</span>
      <span class='ocrx_word' id='word_1_4' title='bbox 1229 87 1365 151; x_wconf 90' lang='fra' dir='ltr'>DE</span>
      <span class='ocrx_word' id='word_1_5' title='bbox 1409 84 1725 154; x_wconf 82' lang='fra' dir='ltr'><em>GANGE</em></span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);
$expected = <<'EOS';
(page 0 0 2236 3185
  (column 157 3011 1725 3105
    (para 157 3014 1725 3101
      (line 157 3014 1725 3101
        (word 157 3030 241 3095 "28")
        (word 533 3033 645 3099 "LA")
        (word 695 3014 1188 3099 "MARQUISE")
        (word 1229 3034 1365 3098 "DE")
        (word 1409 3031 1725 3101 "GANGE")))))
EOS

is_deeply $tree->to_djvu_txt, $expected, 'djvu_txt with hiearchy';

#########################

$hocr = <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>
</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.03' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
</head>
<body>
  <div class='ocr_page' id='page_1' title='image "0020_1L.tif"; bbox 0 0 2236 3185; ppageno 0'>
   <div class='ocr_carea' id='block_1_5' title="bbox 1808 552 2290 1020">
    <p class='ocr_par' dir='ltr' id='par_1_6' title="bbox 1810 552 2288 1020">
     <span class='ocr_line' id='line_1_9' title="bbox 1810 552 2288 1020; baseline 0 2487"><span class='ocrx_word' id='word_1_17' title='bbox 1810 552 2288 1020; x_wconf 95' lang='deu' dir='ltr'> </span> 
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);

is_deeply $tree->to_djvu_txt, '', 'ignore hierachy with no contents';

#########################

$hocr = <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>
</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.03' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
</head>
<body>
  <div class='ocr_page' id='page_1' title='image "/tmp/gscan2pdf-Ay0J/nUVvJ79mSJ.pnm"; bbox 0 0 2480 3507; ppageno 0'>
   <div class='ocr_carea' id='block_1_1' title="bbox 295 263 546 440">
    <p class='ocr_par' dir='ltr' id='par_1_1' title="bbox 297 263 545 440">
     <span class='ocr_line' id='line_1_1' title="bbox 368 263 527 310; baseline 0 3197"><span class='ocrx_word' id='word_1_1' title='bbox 368 263 527 310; x_wconf 95' lang='deu' dir='ltr'> </span> 
     </span>
     <span class='ocr_line' id='line_1_2' title="bbox 297 310 545 440; baseline 0 0"><span class='ocrx_word' id='word_1_2' title='bbox 297 310 545 440; x_wconf 95' lang='deu' dir='ltr'>  </span> 
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);

is_deeply $tree->to_djvu_txt, '', 'ignore hierachy with no contents 2';

#########################

$hocr = <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>
</title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.03' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
</head>
<body>
  <div class='ocr_page' id='page_1' title='image "/tmp/gscan2pdf-jzAZ/YHm7vp6nUp.pnm"; bbox 0 0 2480 3507; ppageno 0'>
   <div class='ocr_carea' id='block_1_10' title="bbox 305 2194 2082 2573">
    <p class='ocr_par' dir='ltr' id='par_1_13' title="bbox 306 2195 2079 2568">
     <span class='ocr_line' id='line_1_43' title="bbox 311 2382 1920 2428; baseline -0.009 -3">
      <span class='ocrx_word' id='word_1_401' title='bbox 1198 2386 1363 2418; x_wconf 77' lang='deu' dir='ltr'><strong>Kauﬂ&lt;raft</strong></span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);

$expected = <<'EOS';
(page 0 0 2480 3507
  (column 305 934 2082 1313
    (para 306 939 2079 1312
      (line 311 1079 1920 1125
        (word 1198 1089 1363 1121 "Kauﬂ<raft")))))
EOS

is_deeply $tree->to_djvu_txt, $expected, 'deal with encoded characters';

#########################

$hocr = <<'EOS';
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title></title>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8"/>
  <meta name='ocr-system' content='tesseract 4.1.1' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word ocrp_wconf'/>
 </head>
 <body>
  <div class='ocr_page' id='page_1' title='image "bug.tif"; bbox 0 0 2480 3507; ppageno 0'>
   <div class='ocr_carea' id='block_1_3' title="bbox 253 443 782 528">
    <p class='ocr_par' id='par_1_3' lang='deu' title="bbox 253 443 782 528">
     <span class='ocr_header' id='line_1_3' title="bbox 255 443 782 480; baseline -0.009 0; x_size 38.437073; x_descenders 5.4370708; x_ascenders 9">
      <span class='ocrx_word' id='word_1_6' title='bbox 255 447 335 480; x_wconf 93'>GLS</span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);

$expected = <<'EOS';
(page 0 0 2480 3507
  (column 253 2979 782 3064
    (para 253 2979 782 3064
      (line 255 3027 782 3064
        (word 255 3027 335 3060 "GLS")))))
EOS

is_deeply $tree->to_djvu_txt, $expected, 'deal with unsupported box types';

#########################

# hOCR created with:
# convert +matte -depth 1 -pointsize 12 -units PixelsPerInch -density 300 label:"The\nquick brown fox\n\njumps over the lazy dog." test.png
# tesseract -l eng -c tessedit_create_hocr=1 test.png stdout
$hocr = <<'EOS';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
    "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title></title>
<meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='tesseract 3.05.01' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocrx_word'/>
</head>
<body>
  <div class='ocr_page' id='page_1' title='image "test.png"; bbox 0 0 545 229; ppageno 0'>
   <div class='ocr_carea' id='block_1_1' title="bbox 1 10 348 113">
    <p class='ocr_par' id='par_1_1' lang='eng' title="bbox 1 10 348 113">
     <span class='ocr_line' id='line_1_1' title="bbox 1 10 85 46; baseline 0 0; x_size 46.247379; x_descenders 10.247379; x_ascenders 10"><span class='ocrx_word' id='word_1_1' title='bbox 1 10 85 46; x_wconf 90'>The</span>
     </span>
     <span class='ocr_line' id='line_1_2' title="bbox 2 67 348 113; baseline 0 -10; x_size 46; x_descenders 10; x_ascenders 10"><span class='ocrx_word' id='word_1_2' title='bbox 2 67 116 113; x_wconf 89'>quick</span> <span class='ocrx_word' id='word_1_3' title='bbox 134 67 264 103; x_wconf 94'>brown</span> <span class='ocrx_word' id='word_1_4' title='bbox 282 67 348 103; x_wconf 94'>fox</span>
     </span>
    </p>
   </div>
   <div class='ocr_carea' id='block_1_2' title="bbox 0 181 541 227">
    <p class='ocr_par' id='par_1_2' lang='eng' title="bbox 0 181 541 227">
     <span class='ocr_line' id='line_1_3' title="bbox 0 181 541 227; baseline 0 -10; x_size 46; x_descenders 10; x_ascenders 10">
      <span class='ocrx_word' id='word_1_5' title='bbox 0 181 132 227; x_wconf 90'>jumps</span>
      <span class='ocrx_word' id='word_1_6' title='bbox 150 191 246 217; x_wconf 90'>over</span>
      <span class='ocrx_word' id='word_1_7' title='bbox 261 181 328 217; x_wconf 90'>the</span>
      <span class='ocrx_word' id='word_1_8' title='bbox 347 181 432 227; x_wconf 90'>lazy</span>
      <span class='ocrx_word' id='word_1_9' title='bbox 449 181 541 227; x_wconf 93'>dog.</span>
     </span>
    </p>
   </div>
  </div>
 </body>
</html>
EOS
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_hocr($hocr);

is_deeply $tree->to_text, "The quick brown fox\n\njumps over the lazy dog.",
  'string with paragraphs';

#########################

my $djvu = <<'EOS';
(page 0 0 2236 3185
  (column 157 3011 1725 3105
    (para 157 3014 1725 3101
      (line 157 3014 1725 3101
        (word 157 3030 241 3095 "28")
        (word 533 3033 645 3099 "LA")
        (word 695 3014 1188 3099 "MARQUISE")
        (word 1229 3034 1365 3098 "DE")
        (word 1409 3031 1725 3101 "GANGE")))))
EOS

@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 2236, 3185, ],
        depth => 0,
    },
    {
        type  => 'column',
        bbox  => [ 157, 80, 1725, 174, ],
        depth => 1,
    },
    {
        type  => 'para',
        bbox  => [ 157, 84, 1725, 171, ],
        depth => 2,
    },
    {
        type  => 'line',
        bbox  => [ 157, 84, 1725, 171, ],
        depth => 3,
    },
    {
        type  => 'word',
        bbox  => [ 157, 90, 241, 155, ],
        depth => 4,
        text  => "28",
    },
    {
        type  => 'word',
        bbox  => [ 533, 86, 645, 152, ],
        depth => 4,
        text  => "LA",
    },
    {
        type  => 'word',
        bbox  => [ 695, 86, 1188, 171, ],
        depth => 4,
        text  => "MARQUISE",
    },
    {
        type  => 'word',
        bbox  => [ 1229, 87, 1365, 151, ],
        depth => 4,
        text  => "DE",
    },
    {
        type  => 'word',
        bbox  => [ 1409, 84, 1725, 154, ],
        depth => 4,
        text  => "GANGE",
    },
);
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_djvu_txt($djvu);
is_deeply $tree, \@boxes, 'from_djvu_txt() basic functionality';

#########################

$djvu = <<'EOS';
(page 0 0 2480 3507
  (word 157 3030 241 3095 "()"))
EOS

@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 2480, 3507, ],
        depth => 0,
    },
    {
        type  => 'word',
        bbox  => [ 157, 412, 241, 477, ],
        depth => 1,
        text  => "()",
    },
);
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_djvu_txt($djvu);
is_deeply $tree, \@boxes, 'from_djvu_txt() with quoted brackets';

my $ann = <<'EOS';
(maparea "" "()" (rect 157 3030 84 65) (hilite #cccf00) (xor))
EOS
is_deeply $tree->to_djvu_ann, $ann, 'to_djvu_ann() basic functionality';

$tree = Gscan2pdf::Bboxtree->new;
$tree->from_djvu_ann( $ann, 2480, 3507 );
is_deeply $tree, \@boxes, 'from_djvu_ann() basic functionality';

#########################

my $pdftext = <<'EOS';
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd"><html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title></title>
<meta name="Producer" content="Tesseract 3.03"/>
<meta name="CreationDate" content=""/>
</head>
<body>
<doc>
  <page width="464.910000" height="58.630000">
    <word xMin="1.029000" yMin="22.787000" xMax="87.429570" yMax="46.334000">The</word>
    <word xMin="105.029000" yMin="22.787000" xMax="222.286950" yMax="46.334000">quick</word>
    <word xMin="241.029000" yMin="22.787000" xMax="374.744000" yMax="46.334000">brown</word>
    <word xMin="393.029000" yMin="22.787000" xMax="460.914860" yMax="46.334000">fox</word>
  </page>
</doc>
</body>
</html>
EOS

@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 465, 59, ],
        depth => 0,
    },
    {
        type  => 'word',
        bbox  => [ 1, 23, 87, 46, ],
        depth => 1,
        text  => "The",
    },
    {
        type  => 'word',
        bbox  => [ 105, 23, 222, 46, ],
        depth => 1,
        text  => "quick",
    },
    {
        type  => 'word',
        bbox  => [ 241, 23, 375, 46, ],
        depth => 1,
        text  => "brown",
    },
    {
        type  => 'word',
        bbox  => [ 393, 23, 461, 46, ],
        depth => 1,
        text  => "fox",
    },
);
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_pdftotext( $pdftext, 72, 72, 59, 465 );
is_deeply $tree, \@boxes, 'from_pdftotext() basic functionality';

#########################

@boxes = (
    {
        type  => 'page',
        bbox  => [ 0, 0, 1937, 244, ],
        depth => 0,
    },
    {
        type  => 'word',
        bbox  => [ 4, 95, 364, 193, ],
        depth => 1,
        text  => "The",
    },
    {
        type  => 'word',
        bbox  => [ 438, 95, 926, 193, ],
        depth => 1,
        text  => "quick",
    },
    {
        type  => 'word',
        bbox  => [ 1004, 95, 1561, 193, ],
        depth => 1,
        text  => "brown",
    },
    {
        type  => 'word',
        bbox  => [ 1638, 95, 1920, 193, ],
        depth => 1,
        text  => "fox",
    },
);
$tree = Gscan2pdf::Bboxtree->new;
$tree->from_pdftotext( $pdftext, 300, 300, 244, 1937 );
is_deeply $tree, \@boxes, 'from_pdftotext() with resolution';

#########################

__END__
