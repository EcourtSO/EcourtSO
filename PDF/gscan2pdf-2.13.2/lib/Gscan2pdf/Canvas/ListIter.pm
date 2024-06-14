package Gscan2pdf::Canvas::ListIter;

use strict;
use warnings;
use POSIX qw/ceil/;
use Readonly;
Readonly my $EMPTY_LIST => -1;
our $VERSION = '2.13.2';

sub new {
    my ($class) = @_;
    my $self = {};
    $self->{list}  = [];
    $self->{index} = $EMPTY_LIST;
    return bless $self, $class;
}

sub get_first_bbox {
    my ($self) = @_;
    $self->{index} = 0;
    return $self->get_current_bbox( $self->{index} );
}

sub get_previous_bbox {
    my ($self) = @_;
    if ( $self->{index} > 0 ) {
        $self->{index} -= 1;
    }
    return $self->get_current_bbox( $self->{index} );
}

sub get_next_bbox {
    my ($self) = @_;
    if ( $self->{index} < $#{ $self->{list} } ) {
        $self->{index} += 1;
    }
    return $self->get_current_bbox( $self->{index} );
}

sub get_last_bbox {
    my ($self) = @_;
    $self->{index} = $#{ $self->{list} };
    return $self->get_current_bbox( $self->{index} );
}

sub get_current_bbox {
    my ($self) = @_;
    if ( $self->{index} > $EMPTY_LIST ) {
        return $self->{list}[ $self->{index} ][0];
    }
    return;
}

sub set_index_by_bbox {
    my ( $self, $bbox, $value ) = @_;

    # There may be multiple boxes with the same value, so use a binary
    # search to find the next smallest confidence, and then a linear search to
    # find the box
    my $l = $self->get_index_for_value( $value - 1 );
    for my $i ( $l .. $#{ $self->{list} } ) {
        if ( $self->{list}->[$i][0] == $bbox ) {
            $self->{index} = $i;
            return $i;
        }
    }
    $self->{index} = $EMPTY_LIST;
    return $EMPTY_LIST;
}

# Return index of value using binary search
# https://en.wikipedia.org/wiki/Binary_search_algorithm#Alternative_procedure

sub get_index_for_value {
    my ( $self, $value ) = @_;
    my $l = 0;
    my $r = $#{ $self->{list} };
    if ( $r == $EMPTY_LIST ) { return 0 }
    while ( $l != $r ) {
        my $m = ceil( ( $l + $r ) / 2 );
        if ( $self->{list}->[$m][1] > $value ) {
            $r = $m - 1;
        }
        else {
            $l = $m;
        }
    }
    if ( $self->{list}->[$l][1] < $value ) {
        $l += 1;
    }
    return $l;
}

sub insert_after_position {
    my ( $self, $bbox, $i, $value ) = @_;
    if ( not defined $bbox ) {
        Glib->warning( __PACKAGE__,
            'Attempted to add undefined box to confidence list' );
        return;
    }
    if ( $i > $#{ $self->{list} } ) {
        Glib->warning( __PACKAGE__,
            "insert_after_position: position $i does not exist in index" );
        return;
    }
    splice @{ $self->{list} }, $i + 1, 0, [ $bbox, $value ];
    return;
}

sub insert_after_box {
    my ( $self, $bbox ) = @_;
    if ( not defined $bbox ) {
        Glib->warning( __PACKAGE__,
            'Attempted to add undefined box to confidence list' );
        return;
    }
}

sub insert_before_position {
    my ( $self, $bbox, $i, $value ) = @_;
    if ( not defined $bbox ) {
        Glib->warning( __PACKAGE__,
            'Attempted to add undefined box to confidence list' );
        return;
    }
    if ( $i > $#{ $self->{list} } ) {
        Glib->warning( __PACKAGE__,
            "insert_before_position: position $i does not exist in index" );
        return;
    }
    splice @{ $self->{list} }, $i, 0, [ $bbox, $value ];
    return;
}

sub insert_before_box {
    my ( $self, $bbox ) = @_;
    if ( not defined $bbox ) {
        Glib->warning( __PACKAGE__,
            'Attempted to add undefined box to confidence list' );
        return;
    }
    return;
}

# insert into list sorted by confidence level using a binary search

sub add_box_to_index {
    my ( $self, $bbox, $value ) = @_;
    if ( not defined $bbox ) {
        Glib->warning( __PACKAGE__,
            'Attempted to add undefined box to confidence list' );
        return;
    }
    my $i = $self->get_index_for_value($value);
    if ( $i > $#{ $self->{list} } ) {
        push @{ $self->{list} }, [ $bbox, $value ];
        return;
    }
    $self->insert_before_position( $bbox, $i, $value );
    return;
}

sub remove_current_box_from_index {
    my ($self) = @_;
    use Data::Dumper;
    if ( not defined $self->{index} or $self->{index} < 0 ) {
        Glib->warning( __PACKAGE__,
            'Attempted to delete undefined index from confidence list' );
        return;
    }
    splice @{ $self->{list} }, $self->{index}, 1;
    if ( $self->{index} > $#{ $self->{list} } ) {
        $self->{index} = $#{ $self->{list} };
    }
    return;
}

1;
