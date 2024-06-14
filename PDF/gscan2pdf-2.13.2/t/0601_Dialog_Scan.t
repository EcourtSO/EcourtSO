use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 14;
use Gscan2pdf::Document;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;             # Could just call init separately

BEGIN {
    use_ok('Gscan2pdf::Dialog::Scan');
}

#########################

my $window = Gtk3::Window->new;

Gscan2pdf::Translation::set_domain('gscan2pdf');
use Log::Log4perl qw(:easy);
Log::Log4perl->easy_init($WARN);
my $logger = Log::Log4perl::get_logger;

ok(
    my $dialog = Gscan2pdf::Dialog::Scan->new(
        title           => 'title',
        'transient-for' => $window,
        'logger'        => $logger
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::Scan' );

$dialog->set( 'sided',        'double' );
$dialog->set( 'side-to-scan', 'reverse' );

# After having scanned some double-sided pages on a simplex scanner,
# selecting single-sided again should also select facing page.

$dialog->set( 'sided', 'single' );
is $dialog->get('side-to-scan'), 'facing',
  'selecting single sided also selects facing';

$dialog->{checkx}->set_active(TRUE);
$dialog->set( 'page-number-increment', 3 );
$dialog->{checkx}->set_active(FALSE);
is $dialog->get('page-number-increment'), 2,
  'turning off extended page numbering resets increment';

is $dialog->get('allow-batch-flatbed'), 0, 'default allow-batch-flatbed';
$dialog->set( 'allow-batch-flatbed', TRUE );
$dialog->set( 'num-pages',           2 );
is $dialog->get('num-pages'), 2, 'num-pages';
ok $dialog->{framen}->is_sensitive, 'num-page gui not ghosted';
$dialog->set( 'allow-batch-flatbed', FALSE );
is $dialog->get('num-pages'), 2,
  'with no source, num-pages not affected by allow-batch-flatbed';
ok $dialog->{framen}->is_sensitive, 'with no source, num-page gui not ghosted';

Gscan2pdf::Document->setup($logger);
my $slist = Gscan2pdf::Document->new;
$dialog = Gscan2pdf::Dialog::Scan->new(
    title           => 'title',
    'transient-for' => $window,
    'document'      => $slist,
    'logger'        => $logger,
);
system(qw(convert rose: test.pnm));
my $dir     = File::Temp->newdir;
my %options = (
    filename    => 'test.pnm',
    xresolution => 72,
    yresolution => 72,
    page        => 1,
    dir         => $dir,
);
$slist->import_scan(%options);
$options{page} = 2;
$slist->import_scan(%options);
$options{page} = 4;
$slist->import_scan(%options);
$options{page}              = 5;
$options{finished_callback} = sub {
    is $dialog->get('page-number-start'), 3,
      'adding pages should update page-number-start';
    is $dialog->get('num-pages'), 1, 'adding pages should update num-pages';
    Gtk3->main_quit;
};
$slist->import_scan(%options);
Gtk3->main;

# v2.6.3 had the bug where scanning 10 pages on single-sided, followed by
# 10 pages double-sided reverse resulted in the reverse pages being numbered:
# 11, 9, 7, 5, 3, 1, -1, -3, -5, -7
$dialog->set( 'allow-batch-flatbed', TRUE );
$slist->{data} =
  [ [ 1, undef, undef ], [ 3, undef, undef ], [ 5, undef, undef ] ];
$dialog->set( 'page-number-start', 6 );
$dialog->set( 'num-pages',         0 );
$dialog->set( 'side-to-scan',      'reverse' );
is $dialog->get('num-pages'), 3,
  'selecting reverse should automatically limit the number of pages to scan';
is $dialog->get('max-pages'), 3,
'selecting reverse should automatically limit the max number of pages to scan';

unlink 'test.pnm';
rmdir $dir;
Gscan2pdf::Document->quit();

__END__
