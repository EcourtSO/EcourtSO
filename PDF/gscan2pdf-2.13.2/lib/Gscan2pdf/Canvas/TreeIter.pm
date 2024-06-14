package Gscan2pdf::Canvas::TreeIter;

use strict;
use warnings;
use Carp;
use Readonly;
Readonly my $EMPTY_LIST => -1;
our $VERSION = '2.13.2';

sub new {
    my ( $class, $bbox ) = @_;
    if ( not defined $bbox or not $bbox->isa('Gscan2pdf::Canvas::Bbox') ) {
        croak "$bbox is not a bbox object";
    }
    my $self = { bbox => [$bbox], iter => [] };
    while ( $bbox->{type} ne 'page' ) {
        my $parent = $bbox->get_property('parent');
        unshift @{ $self->{iter} }, $parent->get_child_ordinal($bbox);
        unshift @{ $self->{bbox} }, $parent;
        $bbox = $parent;
    }
    return bless $self, $class;
}

sub first_bbox {
    my ($self) = @_;
    $self->{bbox} = [ $self->{bbox}[0] ];
    $self->{iter} = [];
    return $self->{bbox}[0];
}

sub first_word {
    my ($self) = @_;
    my $bbox = $self->first_bbox;
    if ( $bbox->{type} ne 'word' ) {
        return $self->next_word;
    }
    return $bbox;
}

# depth first

sub next_bbox {
    my ($self) = @_;
    my $current = $self->{bbox}[-1];

    # start from first child if necessary
    if ( @{ $self->{iter} } < @{ $self->{bbox} } ) {
        push @{ $self->{iter} }, 0;
    }

    # look through children
    my $n = $current->get_n_children;
    while ( $self->{iter}[-1] < $n ) {
        my $child = $current->get_child( $self->{iter}[-1] );
        if ( $child->isa('Gscan2pdf::Canvas::Bbox') ) {
            push @{ $self->{bbox} }, $child;
            return $child;
        }
        $self->{iter}[-1] += 1;
    }

    # no children, go up a level and look at next sibling
    if ( @{ $self->{bbox} } > 1 ) {
        pop @{ $self->{bbox} };
        pop @{ $self->{iter} };
        $self->{iter}[-1] += 1;
        return $self->next_bbox;
    }
    return;
}

sub next_word {
    my ($self)  = @_;
    my $current = $self->clone;
    my $bbox    = $self->get_current_bbox;
    $bbox = $self->next_bbox;
    while ( defined $bbox and $bbox->{type} ne 'word' ) {
        $bbox = $self->next_bbox;
    }
    if ( not defined $bbox ) {
        $self->{iter} = $current->{iter};
        $self->{bbox} = $current->{bbox};
        return;
    }
    return $bbox;
}

# depth first

sub previous_bbox {
    my ($self) = @_;

    # if we're not on the first sibling
    if ( $self->{iter}[-1] ) {

        # pick the previous sibling
        while ( --$self->{iter}[-1] > $EMPTY_LIST ) {
            $self->{bbox}[-1] =
              $self->{bbox}[-2]->get_child(  ## no critic (ProhibitMagicNumbers)
                $self->{iter}[-1]
              );
            if ( $self->{bbox}[-1]->isa('Gscan2pdf::Canvas::Bbox') ) {
                return $self->last_leaf;
            }
        }
    }

    # don't pop the root bbox
    if ( @{ $self->{bbox} } > 1 ) {

        # otherwise the previous box is just the parent
        pop @{ $self->{iter} };
        return pop @{ $self->{bbox} };
    }
    return;
}

sub previous_word {
    my ($self)  = @_;
    my $current = $self->clone;
    my $bbox    = $self->get_current_bbox;
    $bbox = $self->previous_bbox;
    while ( defined $bbox
        and ( not defined $bbox->{type} or $bbox->{type} ne 'word' ) )
    {
        $bbox = $self->previous_bbox;
    }
    if ( not defined $bbox or $bbox eq $current->{bbox}[-1] ) {
        $self->{iter} = $current->{iter};
        $self->{bbox} = $current->{bbox};
        return;
    }
    return $bbox;
}

# depth first

sub last_bbox {
    my ($self) = @_;
    $self->{bbox} = [ $self->{bbox}[0] ];
    $self->{iter} = [];
    return $self->last_leaf;
}

sub last_word {
    my ($self) = @_;
    my $bbox = $self->last_bbox;
    while ( defined $bbox and $bbox->{type} ne 'word' ) {
        $bbox = $self->previous_bbox;
    }
    return $bbox;
}

sub last_leaf {
    my ($self) = @_;
    my $n = $self->{bbox}[-1]->get_n_children;
    while ( --$n > $EMPTY_LIST ) {
        my $child = $self->{bbox}[-1]->get_child($n);
        if ( $child->isa('Gscan2pdf::Canvas::Bbox') ) {
            push @{ $self->{iter} }, $n;
            push @{ $self->{bbox} }, $child;
            return $self->last_leaf;
        }
    }
    return $self->{bbox}[-1];
}

sub clone {
    my ($self)       = @_;
    my @current_iter = @{ $self->{iter} };
    my @current_bbox = @{ $self->{bbox} };
    return { iter => \@current_iter, bbox => \@current_bbox };
}

sub get_current_bbox {
    my ($self) = @_;
    return $self->{bbox}[-1];
}

1;

__END__
