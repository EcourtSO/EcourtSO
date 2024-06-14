package Gscan2pdf::Dialog::MultipleMessage;

use warnings;
use strict;
use Gtk3;
use Glib 1.220 qw(TRUE FALSE);      # To get TRUE and FALSE
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Gscan2pdf::Dialog;
use Glib::Object::Subclass Gscan2pdf::Dialog::;
use Readonly;
Readonly my $COL_MESSAGE  => 3;
Readonly my $COL_CHECKBOX => 4;

my %types;

our $VERSION = '2.13.2';
my $SPACE    = q{ };
my $HEXREGEX = qr{^(.*)           # start of message
                  \b0x[[:xdigit:]]+\b # hex (e.g. address)
                  (.*)$           # rest of message
                 }xsm;
my $INTREGEX = qr{^(.*)           # start of message
                  \b[[:digit:]]+\b # integer
                  (.*)$           # rest of message
                 }xsm;
my $TEMPFILEREGEX = qr{^(.*)           # start of message
                  gscan2pdf[-][[:alnum:]]+/[[:word:]]+ # temp filename
                  (.*)$           # rest of message
                 }xsm;

sub INIT_INSTANCE {
    my $self = shift;
    %types = (
        error   => __('Error'),
        warning => __('Warning'),
    );
    $self->set_position('center-on-parent');
    my $vbox = $self->get_content_area;

    # to ensure dialog can't grow too big if we have too many messages
    my $scwin = Gtk3::ScrolledWindow->new;
    $vbox->pack_start( $scwin, TRUE, TRUE, 0 );
    $self->{grid}             = Gtk3::Grid->new;
    $self->{grid_rows}        = 0;
    $self->{stored_responses} = [];
    $self->{grid}
      ->attach( Gtk3::Label->new( __('Page') ), 0, $self->{grid_rows}, 1, 1 );
    $self->{grid}
      ->attach( Gtk3::Label->new( __('Process') ), 1, $self->{grid_rows}, 1,
        1 );
    $self->{grid}->attach( Gtk3::Label->new( __('Message type') ),
        2, $self->{grid_rows}, 1, 1 );
    $self->{grid}->attach( Gtk3::Label->new( __('Message') ),
        $COL_MESSAGE, $self->{grid_rows}, 1, 1 );
    $self->{grid}->attach(
        Gtk3::Label->new( __('Hide') ),
        $COL_CHECKBOX, $self->{grid_rows}++,
        1,             1
    );
    $self->{cbl} = Gtk3::Label->new( __("Don't show this message again") );
    $self->{cbl}->set_halign('end');
    $self->{grid}
      ->attach( $self->{cbl}, $COL_MESSAGE, $self->{grid_rows}, 1, 1 );
    $self->{cb} = Gtk3::CheckButton->new;
    $self->{cb}->set_halign('center');
    $self->{grid}
      ->attach( $self->{cb}, $COL_CHECKBOX, $self->{grid_rows}, 1, 1 );
    $scwin->add( $self->{grid} );
    $self->{cb}->signal_connect(
        toggled => sub {
            my $state = $self->{cb}->get_active;
            for my $cb ( $self->_list_checkboxes ) {
                $cb->set_active($state);
            }
        }
    );

    $self->add_actions( 'gtk-close', \&close_callback );
    return $self;
}

sub add_row {
    my ( $self, %options ) = @_;

    $self->{grid}->insert_row( $self->{grid_rows} );
    $self->{grid}->attach( Gtk3::Label->new( $options{page} ),
        0, $self->{grid_rows}, 1, 1 );
    $self->{grid}->attach( Gtk3::Label->new( $options{process} ),
        1, $self->{grid_rows}, 1, 1 );
    $self->{grid}->attach( Gtk3::Label->new( $types{ $options{type} } ),
        2, $self->{grid_rows}, 1, 1 );
    my $view   = Gtk3::TextView->new;
    my $buffer = $view->get_buffer;

    # strip newlines from the end of the string, but not the end of the line
    $options{text} =~ s/\s+\z//xsm;
    $buffer->set_text( $options{text} );
    $view->set_editable(FALSE);
    $view->set_wrap_mode('word-char');
    $view->set( 'expand', TRUE );
    $self->{grid}->attach( $view, $COL_MESSAGE, $self->{grid_rows}++, 1, 1 );

    if ( $options{'store-response'} ) {
        my $button = Gtk3::CheckButton->new();
        $button->signal_connect( toggled => \&_checkbutton_consistency, $self );
        $button->set_halign('center');
        $self->{grid}
          ->attach( $button, $COL_CHECKBOX, $self->{grid_rows} - 1, 1, 1 );
        if ( $options{'stored-responses'} ) {
            $self->{stored_responses}[ $self->{grid_rows} - 1 ] =
              $options{'stored-responses'};
        }
        _checkbutton_consistency( $button, $self );
    }
    if ( $self->{grid_rows} > 2 ) {
        $self->{cbl}->set_label( __("Don't show these messages again") );
    }
    return;
}

sub _checkbutton_consistency {
    my ( $widget, $self ) = @_;
    my $state;
    for my $cb ( $self->_list_checkboxes ) {
        if ( not defined $state ) {
            $state = $cb->get_active;
        }
        elsif ( $state != $cb->get_active ) {
            undef $state;
            last;
        }
    }
    if ( defined $state ) {
        $self->{cb}->set_inconsistent(FALSE);
        $self->{cb}->set_active($state);
    }
    else {
        $self->{cb}->set_inconsistent(TRUE);
    }
    return;
}

sub add_message {
    my ( $self, %options ) = @_;

    # possibly split messages or explain them
    my $text = munge_message( $options{text} );
    if ( ref($text) eq 'ARRAY' ) {
        for ( @{$text} ) {
            $text = filter_message($_);
            if ( not response_stored( $text, $options{responses} ) ) {
                $options{text} = $_;
                $self->add_row(%options);
            }
        }
    }
    else {
        my $filter = filter_message($text);
        if ( not response_stored( $filter, $options{responses} ) ) {
            $options{text} = $text;
            $self->add_row(%options);
        }
    }
    return;
}

sub store_responses {
    my ( $self, $response, $responses ) = @_;
    for my $text ( $self->list_messages_to_ignore($response) ) {
        $responses->{ filter_message($text) }{response} = $response;
    }
    return;
}

sub response_stored {
    my ( $text, $responses ) = @_;
    return (  defined $responses->{$text}
          and defined $responses->{$text}{response} );
}

sub _list_checkboxes {
    my ($self) = @_;
    my @cbs;
    for my $row ( 1 .. $self->{grid_rows} - 1 ) {
        my $cb = $self->{grid}->get_child_at( $COL_CHECKBOX, $row );
        if ( defined $cb ) {
            push @cbs, $cb;
        }
    }
    return @cbs;
}

sub list_messages_to_ignore {
    my ( $self, $response ) = @_;
    my (@list);
    for my $row ( 1 .. $self->{grid_rows} - 1 ) {
        my $cb = $self->{grid}->get_child_at( $COL_CHECKBOX, $row );
        if ( defined $cb and $cb->get_active ) {
            my $filter = TRUE;
            if ( $self->{stored_responses}[$row] ) {
                $filter = FALSE;
                for ( @{ $self->{stored_responses}[$row] } ) {
                    if ( $_ eq $response ) {
                        $filter = TRUE;
                        last;
                    }
                }
            }
            if ($filter) {
                my $buffer =
                  $self->{grid}->get_child_at( $COL_MESSAGE, $row )->get_buffer;
                push @list,
                  $buffer->get_text( $buffer->get_start_iter,
                    $buffer->get_end_iter, TRUE );
            }
        }
    }
    return @list;
}

# Has to be carried out separately to filter_message in order to show the user
# any addresses, error numbers, etc.

sub munge_message {
    my ($message) = @_;
    my @out = ();

    # split up gimp messages
    while (
        defined $message
        and (  $message =~ /^([(]gimp:\d+[)]:[^\n]+)\n(.*)/xsm
            or $message =~
            /^([[]\S+\s@\s\b0x[[:xdigit:]]+\b\][^\n]+)\n(.*)/xsm )
      )
    {
        push @out, munge_message($1);
        $message = $2;
    }
    if (@out) {
        if ( defined $message and $message !~ /^\s*$/xsm ) {
            push @out, munge_message($message);
        }
        return \@out;
    }

    if ( defined $message
        and $message =~
        /Exception[ ](:?400|445):[ ]memory[ ]allocation[ ]failed/xsm )
    {
        $message .= "\n\n"
          . __(
'This error is normally due to ImageMagick exceeding its resource limits.'
          )
          . $SPACE
          . __(
'These can be extended by editing its policy file, which on my system is found at /etc/ImageMagick-6/policy.xml'
          )
          . $SPACE
          . __(
'Please see https://imagemagick.org/script/resources.php for more information'
          );
    }
    return $message;
}

# External tools sometimes throws warning messages including a number,
# e.g. hex address. As the number is very rarely the same, although the message
# itself is, filter out the number from the message

sub filter_message {
    my ($message) = @_;
    $message =~ s/\s+$//xsm;
    while ( $message =~ /$TEMPFILEREGEX/xsmo ) {
        $message =~ s/$TEMPFILEREGEX/$1%%t$2/xsmo;
    }
    while ( $message =~ /$HEXREGEX/xsmo ) {
        $message =~ s/$HEXREGEX/$1%%x$2/xsmo;
    }
    while ( $message =~ /$INTREGEX/xsmo ) {
        $message =~ s/$INTREGEX/$1%%d$2/xsmo;
    }
    return $message;
}

sub close_callback {
}

1;

__END__
