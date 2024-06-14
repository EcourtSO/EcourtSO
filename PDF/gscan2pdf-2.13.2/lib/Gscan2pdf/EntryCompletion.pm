package Gscan2pdf::EntryCompletion;

use strict;
use warnings;
use Gtk3;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '2.13.2';

    use base qw(Exporter Gtk3::Entry);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}

sub new {
    my ( $class, $text, $suggestions ) = @_;
    my $self       = Gtk3::Entry->new;
    my $completion = Gtk3::EntryCompletion->new;
    $completion->set_inline_completion(TRUE);
    $completion->set_text_column(0);
    $self->set_completion($completion);
    my $model = Gtk3::ListStore->new('Glib::String');
    $completion->set_model($model);
    $self->set_activates_default(TRUE);
    bless $self, $class;
    if ( defined $text )        { $self->set_text($text) }
    if ( defined $suggestions ) { $self->add_to_suggestions($suggestions) }
    return $self;
}

sub get_suggestions {
    my ($self) = @_;
    my $completion = $self->get_completion;
    my @suggestions;
    $completion->get_model->foreach(
        sub {
            my ( $model, $path, $iter ) = @_;
            my $suggestion = $model->get( $iter, 0 );
            push @suggestions, $suggestion;
            return FALSE;    # FALSE=continue
        }
    );
    return \@suggestions;
}

sub add_to_suggestions {
    my ( $self, $suggestions ) = @_;
    my $completion = $self->get_completion;
    my $model      = $completion->get_model;
    for my $text ( @{$suggestions} ) {
        my $flag = FALSE;
        $model->foreach(
            sub {
                ( $model, my $path, my $iter ) = @_;
                my $suggestion = $model->get( $iter, 0 );
                if ( $suggestion eq $text ) { $flag = TRUE }
                return $flag;    # FALSE=continue
            }
        );
        if ( not $flag ) {
            $model->set( $model->append, 0, $text );
        }
    }
    return;
}

1;

__END__
