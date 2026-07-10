use warnings;
use strict;
use Test::More tests => 13;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;
use Scalar::Util;

BEGIN {
    use_ok('Gscan2pdf::Dialog');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
my $window = Gtk3::Window->new;

ok(
    my $dialog =
      Gscan2pdf::Dialog->new( title => 'title', 'transient-for' => $window ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog' );

is( $dialog->get('title'),         'title', 'title' );
is( $dialog->get('transient-for'), $window, 'transient-for' );
ok( $dialog->get('hide-on-delete') == FALSE, 'default destroy' );
is( $dialog->get('page-range'), 'selected', 'default page-range' );

$dialog = Gscan2pdf::Dialog->new;
$dialog->signal_emit( 'delete_event', undef );
Scalar::Util::weaken($dialog);
is( $dialog, undef, 'destroyed on delete_event' );

$dialog = Gscan2pdf::Dialog->new( 'hide-on-delete' => TRUE );
$dialog->signal_emit( 'delete_event', undef );
Scalar::Util::weaken($dialog);
isnt( $dialog, undef, 'hidden on delete_event' );

$dialog = Gscan2pdf::Dialog->new;
my $event = Gtk3::Gdk::Event->new('key-press');
$event->keyval(Gtk3::Gdk::KEY_Escape);
$dialog->signal_emit( 'key_press_event', $event );
Scalar::Util::weaken($dialog);
is( $dialog, undef, 'destroyed on escape' );

$dialog = Gscan2pdf::Dialog->new( 'hide-on-delete' => TRUE );
$dialog->signal_emit( 'key_press_event', $event );
Scalar::Util::weaken($dialog);
isnt( $dialog, undef, 'hidden on escape' );

$dialog = Gscan2pdf::Dialog->new;
$dialog->signal_connect_after(
    key_press_event => sub {
        my ( $widget, $event ) = @_;
        is( $event->keyval, Gtk3::Gdk::KEY_Delete,
            'other key press events still propagate' );
    }
);
$event = Gtk3::Gdk::Event->new('key-press');
$event->keyval(Gtk3::Gdk::KEY_Delete);
$dialog->signal_emit( 'key_press_event', $event );

$dialog = Gscan2pdf::Dialog->new;
$dialog->add_actions( 'gtk-close', sub { } );
$dialog->response(0);    # 0 = GTK_RESPONSE_NONE
pass 'no crash due to undefined response';

__END__
