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

$slist->import_files(
    paths             => ['test.pnm'],
    finished_callback => sub {
        $slist->{data}[0][2]->import_hocr($hocr);
        $slist->save_hocr(
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

$hocr = <<"EOS";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Document::VERSION' />
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
is( capture(qw(cat test.txt)),  $hocr, 'saved hOCR' );
is( capture(qw(cat test2.txt)), $hocr, 'post-save hook' );

#########################

unlink 'test.pnm', 'test.txt', 'test2.txt';
Gscan2pdf::Document->quit();
