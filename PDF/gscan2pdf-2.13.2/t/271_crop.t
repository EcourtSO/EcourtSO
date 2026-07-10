use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use IPC::System::Simple qw(system capture);
use Test::More tests => 6;

BEGIN {
    use_ok('Gscan2pdf::Document');
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;
Gscan2pdf::Document->setup($logger);

# Create test image
system(qw(convert rose: test.gif));

my $slist = Gscan2pdf::Document->new;

# dir for temporary files
my $dir = File::Temp->newdir;
$slist->set_dir($dir);

$slist->import_files(
    paths             => ['test.gif'],
    finished_callback => sub {
        is_deeply [ $slist->{data}[0][2]{width}, $slist->{data}[0][2]{height} ],
          [ 70, 46 ], 'dimensions before crop';
        $slist->{data}[0][2]->import_hocr( <<'EOS');
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf 2.7.0' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
  <div class='ocr_page' title='bbox 0 0 70 46'>
      <span class='ocr_word' title='bbox 1 1 9 9'>beyond br</span>
      <span class='ocr_word' title='bbox 5 5 15 15'>on br</span>
      <span class='ocr_word' title='bbox 11 11 19 19'>inside</span>
      <span class='ocr_word' title='bbox 15 15 25 25'>on tl</span>
      <span class='ocr_word' title='bbox 21 21 29 29'>beyond tl</span>
  </div>
 </body>
</html>
EOS
        $slist->crop(
            page              => $slist->{data}[0][2]->{uuid},
            x                 => 10,
            y                 => 10,
            w                 => 10,
            h                 => 10,
            finished_callback => sub {
                is_deeply [ $slist->{data}[0][2]{width},
                    $slist->{data}[0][2]{height} ],
                  [ 10, 10 ],
                  'dimensions after crop';
                my $got = capture( qw(identify -format %g),
                    $slist->{data}[0][2]{filename} );
                chomp($got);
                is $got, "10x10+0+0", 'GIF cropped correctly';
                is dirname("$slist->{data}[0][2]{filename}"),
                  "$dir", 'using session directory';
                my $expected_hocr = <<"EOS";
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
  <div class='ocr_page' title='bbox 0 0 10 10'>
   <span class='ocr_word' title='bbox 0 0 5 5'>on br</span>
   <span class='ocr_word' title='bbox 1 1 9 9'>inside</span>
   <span class='ocr_word' title='bbox 5 5 10 10'>on tl</span>
  </div>
 </body>
</html>
EOS
                is $slist->{data}[0][2]->export_hocr, $expected_hocr,
                  'cropped hocr';
                Gtk3->main_quit;
            }
        );
    }
);
Gtk3->main;

#########################

unlink 'test.gif', <$dir/*>;
rmdir $dir;
Gscan2pdf::Document->quit();
