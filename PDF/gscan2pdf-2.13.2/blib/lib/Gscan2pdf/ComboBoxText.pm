package Gscan2pdf::ComboBoxText;

use warnings;
use strict;
use Gtk3;
use Glib 1.220 qw(TRUE FALSE);    # To get TRUE and FALSE
use Readonly;
Readonly my $NO_INDEX => -1;

our $VERSION = '2.13.2';

use Glib::Object::Subclass Gtk3::ComboBoxText::, properties => [
    Glib::ParamSpec->int(
        'index-column',                             # name
        'Index column',                             # nickname
        'Column with which the data is indexed',    # blurb
        0,                                          # min 0 implies all
        2,                                          # max
        0,                                          # default
        [qw/readable writable/]                     # flags
    ),
    Glib::ParamSpec->int(
        'text-column',                              # name
        'Text column',                              # nickname
        'Column of text to be displayed',           # blurb
        0,                                          # min 0 implies all
        2,                                          # max
        1,                                          # default
        [qw/readable writable/]                     # flags
    ),
];

# Create a combobox, displaying text from the text column of the array

sub new_from_array {
    my ( $class, @data ) = @_;
    my $self = Gscan2pdf::ComboBoxText->new;
    my $col  = $self->get('text-column');
    for (@data) {
        $self->append_text( $_->[$col] );
    }
    $self->{data} = \@data;
    return $self;
}

# Set the current active item of a combobox
# based on the index column of the array

sub set_active_index {
    my ( $self, $index ) = @_;
    my $col = $self->get('index-column');
    my $i   = 0;
    my $o   = 0;
    if ( defined $index ) {
        for ( @{ $self->{data} } ) {
            if ( defined $_->[$col] and $_->[$col] eq $index ) {
                $o = $i;
                last;
            }
            ++$i;
        }
    }
    $self->set_active($o);
    return;
}

# Set the current active item of a combobox
# based on the index column of the array

sub get_active_index {
    my ($self) = @_;
    return $self->{data}->[ $self->get_active ][ $self->get('index-column') ];
}

# Get row number with $text

sub get_row_by_text {
    my ( $self, $text ) = @_;
    my $o = $NO_INDEX;
    my $i = 0;
    if (    defined( $self->get_model )
        and defined $text )
    {
        $self->get_model->foreach(
            sub {
                my ( $model, $path, $iter ) = @_;
                if ( $model->get( $iter, 0 ) eq $text ) {
                    $o = $i;
                    return TRUE;    # found - stop the foreach()
                }
                else {
                    ++$i;
                    return FALSE;    # not found - continue the foreach()
                }
            }
        );
    }
    return $o;
}

sub set_active_by_text {
    my ( $self, $text ) = @_;
    my $index = $self->get_row_by_text($text);
    if ( $index > $NO_INDEX or not defined $text ) {
        $self->set_active($index);
        return TRUE;
    }
    return;
}

sub get_num_rows {
    my ($self) = @_;
    my $i = 0;
    if ( defined( $self->get_model ) ) {
        $self->get_model->foreach(
            sub {
                ++$i;
                return FALSE;    # continue the foreach()
            }
        );
    }
    return $i;
}

sub remove_item_by_text {
    my ( $self, $text ) = @_;
    if ( defined $text ) {
        my $i = $self->get_row_by_text($text);
        if ( $i > $NO_INDEX ) {
            if ( $self->get_active == $i ) {
                $self->set_active($NO_INDEX);
            }
            $self->remove($i);
        }
    }
    return;
}

1;

__END__
