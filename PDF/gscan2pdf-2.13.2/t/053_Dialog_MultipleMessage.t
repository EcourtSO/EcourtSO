use warnings;
use strict;
use Test::More tests => 23;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use Gtk3 -init;

BEGIN {
    use_ok('Gscan2pdf::Dialog::MultipleMessage');
}

#########################

Gscan2pdf::Translation::set_domain('gscan2pdf');
my $window = Gtk3::Window->new;

ok(
    my $dialog = Gscan2pdf::Dialog::MultipleMessage->new(
        title           => 'title',
        'transient-for' => $window
    ),
    'Created dialog'
);
isa_ok( $dialog, 'Gscan2pdf::Dialog::MultipleMessage' );

$dialog->add_row(
    page             => 1,
    process          => 'scan',
    type             => 'error',
    text             => 'message',
    'store-response' => TRUE
);
is( $dialog->{grid_rows}, 2, '1 message' );

$dialog->add_row(
    page    => 2,
    process => 'scan',
    type    => 'warning',
    text    => 'message2'
);
is( $dialog->{grid_rows}, 3, '2 messages' );

$dialog->{cb}->set_active(TRUE);
is_deeply( [ $dialog->list_messages_to_ignore('ok') ],
    ['message'], 'list_messages_to_ignore' );

$dialog->add_row(
    page             => 1,
    process          => 'scan',
    type             => 'error',
    text             => "my message3\n",
    'store-response' => TRUE
);
is( $dialog->{cb}->get_inconsistent, TRUE, 'inconsistent if states different' );
$dialog->{cb}->set_active(FALSE);
$dialog->{cb}->set_active(TRUE);
is_deeply(
    [ $dialog->list_messages_to_ignore('ok') ],
    [ 'message', 'my message3' ],
    'chop trailing whitespace'
);

$dialog = Gscan2pdf::Dialog::MultipleMessage->new(
    title           => 'title',
    'transient-for' => $window
  ),
  $dialog->add_message(
    page    => 1,
    process => 'scan',
    type    => 'error',
    text    =>
'[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.',
  );
is( $dialog->{grid_rows}, 2, 'add_message single message' );

my $responses = {};
$dialog = Gscan2pdf::Dialog::MultipleMessage->new(
    title           => 'title',
    'transient-for' => $window
  ),
  $dialog->add_message(
    page             => 1,
    process          => 'scan',
    type             => 'error',
    'store-response' => TRUE,
    responses        => $responses,
    text             => <<'EOS',
[image2 @ 0xc596e0] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.
[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.
EOS
  );
is( $dialog->{grid_rows}, 3, 'add_message added 2 messages' );
$dialog->{grid}->get_child_at( 4, 1 )->set_active(TRUE);
is( $dialog->{cb}->get_inconsistent, TRUE, 'inconsistent if states different' );

$dialog->{grid}->get_child_at( 4, 2 )->set_active(TRUE);
$dialog->store_responses( 'ok', $responses );
is( scalar keys %{$responses}, 2, 'stored 2 responses' );

is( $dialog->{cb}->get_inconsistent, FALSE, 'consistent as states same' );

$dialog = Gscan2pdf::Dialog::MultipleMessage->new(
    title           => 'title',
    'transient-for' => $window
  ),
  $dialog->add_message(
    page             => 1,
    process          => 'scan',
    type             => 'error',
    'store-response' => TRUE,
    responses        => $responses,
    text             => <<'EOS',
[image2 @ 0xc596e0] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.
[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.
EOS
  );
is( $dialog->{grid_rows}, 1, 'add_message added no messages' );

is_deeply(
    Gscan2pdf::Dialog::MultipleMessage::munge_message(
        <<'EOS',
(gimp:26514): GLib-GObject-WARNING : g_object_set_valist: object class 'GeglConfig' has no property named 'cache-size'
(gimp:26514): GEGL-gegl-operation.c-WARNING : Cannot change name of operation class 0xE0FD30 from "gimp:point-layer-mode" to "gimp:dissolve-mode"
EOS
    ),
    [
"(gimp:26514): GLib-GObject-WARNING : g_object_set_valist: object class 'GeglConfig' has no property named 'cache-size'",
'(gimp:26514): GEGL-gegl-operation.c-WARNING : Cannot change name of operation class 0xE0FD30 from "gimp:point-layer-mode" to "gimp:dissolve-mode"'
    ],
    'split gimp messages'
);

is_deeply(
    Gscan2pdf::Dialog::MultipleMessage::munge_message(
        <<'EOS',
[image2 @ 0xc596e0] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.
[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.
EOS
    ),
    [
'[image2 @ 0xc596e0] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.',
'[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.'
    ],
    'split unpaper messages'
);

my $expected = <<'EOS';
Exception 400: memory allocation failed

This error is normally due to ImageMagick exceeding its resource limits. These can be extended by editing its policy file, which on my system is found at /etc/ImageMagick-6/policy.xml Please see https://imagemagick.org/script/resources.php for more information
EOS
chomp $expected;
is_deeply(
    Gscan2pdf::Dialog::MultipleMessage::munge_message(
        'Exception 400: memory allocation failed'),
    $expected,
    'extend imagemagick Exception 400'
);

is(
    Gscan2pdf::Dialog::MultipleMessage::filter_message(
'[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.'
    ),
    '[image2 @ %%x] Encoder did not produce proper pts, making some up.',
    'Filter out memory address from unpaper warning'
);

$expected = <<'EOS';
[image2 @ %%x] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.
[image2 @ %%x] Encoder did not produce proper pts, making some up.
EOS
chomp $expected;
is(
    Gscan2pdf::Dialog::MultipleMessage::filter_message(<<'EOS'),
[image2 @ 0xc596e0] Using AVStream.codec to pass codec parameters to muxers is deprecated, use AVStream.codecpar instead.
[image2 @ 0x1338180] Encoder did not produce proper pts, making some up.
EOS
    $expected, 'Filter out double memory address from unpaper warning'
);

is(
    Gscan2pdf::Dialog::MultipleMessage::filter_message(
        'Error processing with tesseract: Detected 440 diacritics'),
    'Error processing with tesseract: Detected %%d diacritics',
    'Filter out integer from tesseract warning'
);

is(
    Gscan2pdf::Dialog::MultipleMessage::filter_message(
'Error processing with tesseract: Warning. Invalid resolution 0 dpi. Using 70 instead.'
    ),
'Error processing with tesseract: Warning. Invalid resolution %%d dpi. Using %%d instead.',
    'Filter out 1 and 2 digit integers from tesseract warning'
);

is(
    Gscan2pdf::Dialog::MultipleMessage::filter_message(
"[image2 @ 0x1338180] Encoder did not produce proper pts, making some up. \n "
    ),
    '[image2 @ %%x] Encoder did not produce proper pts, making some up.',
    'Filter out trailing whitespace'
);

is(
    Gscan2pdf::Dialog::MultipleMessage::filter_message(
"[image2 @ 0x56054e417040] The specified filename '/tmp/gscan2pdf-ldks/OHSk_wKy5v.pnm' does not contain an image sequence pattern or a pattern is invalid."
    ),
"[image2 @ %%x] The specified filename '/tmp/%%t.pnm' does not contain an image sequence pattern or a pattern is invalid.",
    'Filter out temporary filename from unpaper warning'
);

__END__
