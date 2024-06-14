use warnings;
use strict;
use File::Basename;    # Split filename into dir, file, ext
use IPC::System::Simple qw(capture);
use Test::More tests => 2;

BEGIN {
    use Gscan2pdf::Document;
    use Gtk3 -init;    # Could just call init separately
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);

Gscan2pdf::Document->setup(Log::Log4perl::get_logger);
my $slist = Gscan2pdf::Document->new;
my $dir   = File::Temp->newdir;
$slist->set_dir($dir);
$slist->open_session_file( info => 'test.gs2p' );

like capture( 'file', $slist->{data}[0][2]{filename} ),
  qr/PNG image data, 70 x 46, 8-bit\/color RGB, non-interlaced/,
  'PNG extracted with expected size';
is $slist->{data}[0][2]->export_text, 'The quick brown fox',
  'Basic OCR output extracted from bboxtree';

#########################

Gscan2pdf::Document->quit;
unlink 'test.gs2p', 'test.pnm';
