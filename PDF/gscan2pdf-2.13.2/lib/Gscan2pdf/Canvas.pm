package Gscan2pdf::Canvas;

use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use GooCanvas2;
use Gscan2pdf::Canvas::Bbox;
use Gscan2pdf::Canvas::ListIter;
use Gscan2pdf::Canvas::TreeIter;
use Glib 1.220 ':constants';
use HTML::Entities;
use Carp;
use Readonly;
Readonly my $_360_DEGREES    => 360;
Readonly my $MAX_COLOR_INT   => 65_535;
Readonly my $COLOR_TOLERANCE => 0.00001;
Readonly my $COLOR_GREEN     => 2;
Readonly my $COLOR_BLUE      => 4;
Readonly my $COLOR_YELLOW    => 6;
Readonly my $_60_DEGREES     => 60;
Readonly my $MAX_ZOOM        => 15;
Readonly my $EMPTY_LIST      => -1;
my $device;

my ( $_100_PERCENT, $MAX_CONFIDENCE_DEFAULT, $MIN_CONFIDENCE_DEFAULT );

BEGIN {
    Readonly $_100_PERCENT           => 100;
    Readonly $MAX_CONFIDENCE_DEFAULT => 95;
    Readonly $MIN_CONFIDENCE_DEFAULT => 50;
}
our $VERSION = '2.13.2';

use Glib::Object::Subclass GooCanvas2::Canvas::, signals => {
    'zoom-changed' => {
        param_types => ['Glib::Float'],    # new zoom
    },
    'offset-changed' => {
        param_types => [ 'Glib::Int', 'Glib::Int' ],    # new offset
    },
  },
  properties => [
    Glib::ParamSpec->scalar(
        'offset',                                       # name
        'Image offset',                                 # nick
        'Gdk::Rectangle hash of x, y',                  # blurb
        G_PARAM_READWRITE                               # flags
    ),
    Glib::ParamSpec->string(
        'max-color',                                    # name
        'Maximum color',                                # nick
        'Color for maximum confidence',                 # blurb
        'black',                                        # default
        G_PARAM_READWRITE,                              # flags
    ),
    Glib::ParamSpec->scalar(
        'max-color-hsv',                                # name
        'Maximum color (HSV)',                          # nick
        'HSV Color for maximum confidence',             # blurb
        G_PARAM_READWRITE,                              # flags
    ),
    Glib::ParamSpec->string(
        'min-color',                                    # name
        'Minimum color',                                # nick
        'Color for minimum confidence',                 # blurb
        'red',                                          # default
        G_PARAM_READWRITE,                              # flags
    ),
    Glib::ParamSpec->scalar(
        'min-color-hsv',                                # name
        'Minimum color (HSV)',                          # nick
        'HSV Color for minimum confidence',             # blurb
        G_PARAM_READWRITE,                              # flags
    ),
    Glib::ParamSpec->int(
        'max-confidence',                               # name
        'Maximum confidence',                           # nick
        'Confidence threshold for max-color',           # blurb
        0,                                              # min
        $_100_PERCENT,                                  # max
        $MAX_CONFIDENCE_DEFAULT,                        # default
        G_PARAM_READWRITE,                              # flags
    ),
    Glib::ParamSpec->int(
        'min-confidence',                               # name
        'Minimum confidence',                           # nick
        'Confidence threshold for min-color',           # blurb
        0,                                              # min
        $_100_PERCENT,                                  # max
        $MIN_CONFIDENCE_DEFAULT,                        # default
        G_PARAM_READWRITE,                              # flags
    ),
  ];

sub INIT_INSTANCE {
    my $self = shift;

    my $display = Gtk3::Gdk::Display::get_default;
    my $manager = $display->get_device_manager;
    $device = $manager->get_client_pointer;

    # Set up the canvas
    $self->signal_connect( 'button-press-event'   => \&_button_pressed );
    $self->signal_connect( 'button-release-event' => \&_button_released );
    $self->signal_connect( 'motion-notify-event'  => \&_motion );
    $self->signal_connect( 'scroll-event'         => \&_scroll );
    if (
        $Glib::Object::Introspection::VERSION <
        0.043    ## no critic (ProhibitMagicNumbers)
      )
    {
        $self->add_events(
            ${ Gtk3::Gdk::EventMask->new(qw/exposure-mask/) } |
              ${ Gtk3::Gdk::EventMask->new(qw/button-press-mask/) } |
              ${ Gtk3::Gdk::EventMask->new(qw/button-release-mask/) } |
              ${ Gtk3::Gdk::EventMask->new(qw/pointer-motion-mask/) } |
              ${ Gtk3::Gdk::EventMask->new(qw/scroll-mask/) } );
    }
    else {
        $self->add_events(
            Glib::Object::Introspection->convert_sv_to_flags(
                'Gtk3::Gdk::EventMask', 'exposure-mask' ) |
              Glib::Object::Introspection->convert_sv_to_flags(
                'Gtk3::Gdk::EventMask', 'button-press-mask' ) |
              Glib::Object::Introspection->convert_sv_to_flags(
                'Gtk3::Gdk::EventMask', 'button-release-mask' ) |
              Glib::Object::Introspection->convert_sv_to_flags(
                'Gtk3::Gdk::EventMask', 'pointer-motion-mask' ) |
              Glib::Object::Introspection->convert_sv_to_flags(
                'Gtk3::Gdk::EventMask', 'scroll-mask'
              )
        );
    }
    $self->{offset}{x} = 0;
    $self->{offset}{y} = 0;

    $self->{current_index} = 'position';

    # allow the widget to accessed via CSS
    $self->set_name('gscan2pdf-ocr-canvas');
    return $self;
}

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name   = $pspec->get_name;
    my $oldval = $self->get($name);
    if (   ( defined $newval and defined $oldval and $newval ne $oldval )
        or ( defined $newval xor defined $oldval ) )
    {
        given ($name) {
            when ('offset') {
                if (   ( defined $newval xor defined $oldval )
                    or $oldval->{x} != $newval->{x}
                    or $oldval->{y} != $newval->{y} )
                {
                    $self->{$name} = $newval;
                    $self->scroll_to( -$newval->{x}, -$newval->{y} );
                    $self->signal_emit( 'offset-changed', $newval->{x},
                        $newval->{y} );
                }
            }
            when ('max_color') {
                $self->{$name} = $newval;
                $self->{max_color_hsv} = string2hsv($newval);
            }
            when ('min_color') {
                $self->{$name} = $newval;
                $self->{min_color_hsv} = string2hsv($newval);
            }
            default {
                $self->{$name} = $newval;

                #                $self->SUPER::SET_PROPERTY( $pspec, $newval );
            }
        }
    }
    return;
}

sub get_max_color_hsv {
    my ($self) = @_;
    my $val = $self->{max_color_hsv};
    if ( not defined $val ) {
        $self->{max_color_hsv} = string2hsv( $self->get('max-color') );
        return $self->{max_color_hsv};
    }
    return $val;
}

sub get_min_color_hsv {
    my ($self) = @_;
    my $val = $self->{min_color_hsv};
    if ( not defined $val ) {
        $self->{min_color_hsv} = string2hsv( $self->get('min-color') );
        return $self->{min_color_hsv};
    }
    return $val;
}

sub rgb2hsv {
    my (%in) = @_;
    ( $in{r}, $in{g}, $in{b}, ) = (
        $in{r} / $MAX_COLOR_INT,
        $in{g} / $MAX_COLOR_INT,
        $in{b} / $MAX_COLOR_INT,
    );

    my $min = $in{r} < $in{g} ? $in{r} : $in{g};
    $min = $min < $in{b} ? $min : $in{b};

    my $max = $in{r} > $in{g} ? $in{r} : $in{g};
    $max = $max > $in{b} ? $max : $in{b};

    my %out;
    $out{v} = $max;
    my $delta = $max - $min;
    if ( $delta < $COLOR_TOLERANCE ) {
        $out{s} = 0;
        $out{h} = 0;    # undefined, maybe nan?
        return %out;
    }
    if ( $max > 0 ) {    # NOTE: if Max is == 0, this divide would cause a crash
        $out{s} = ( $delta / $max );
    }
    else {
        # if max is 0, then r = g = b = 0
        # s = 0, h is undefined
        $out{s} = 0;
        $out{h} = 0;    # undefined
        return %out;
    }
    if ( $in{r} >= $max ) {    # > is bogus, just keeps compiler happy
        $out{h} =
          ( ( $in{g} - $in{b} ) / $delta )
          % $COLOR_YELLOW;     # between yellow & magenta
    }
    elsif ( $in{g} >= $max ) {
        $out{h} =
          $COLOR_GREEN + ( $in{b} - $in{r} ) / $delta;   # between cyan & yellow
    }
    else {
        $out{h} =
          $COLOR_BLUE + ( $in{r} - $in{g} ) / $delta;   # between magenta & cyan
    }
    $out{h} *= $_60_DEGREES;

    if ( $out{h} < 0.0 ) {
        $out{h} += $_360_DEGREES;
    }
    return %out;
}

sub string2hsv {
    my ($spec) = @_;
    my %rgb;
    ( $rgb{r}, $rgb{g}, $rgb{b} ) = string2rgb($spec);
    return { rgb2hsv(%rgb) };
}

sub string2rgb {
    my ($spec) = @_;
    my $color  = Gtk3::Gdk::Color::parse($spec)->to_string;
    my @color  = unpack 'xA4A4A4', $color;
    for (@color) { $_ = hex }
    return @color;
}

sub set_text {    # FIXME: why is this called twice when running OCR from tools?
    my ( $self, $page, $layer, $edit_callback, $idle, $finished_callback ) = @_;
    if ( not defined $idle ) {
        $idle = TRUE;
    }
    if ( $self->{old_idles} ) {
        while ( my ( $box, $source ) = each %{ $self->{old_idles} } ) {
            Glib::Source->remove($source);
            delete $self->{old_idles}{$box};
        }
    }
    delete $self->{position_index};
    my $root = GooCanvas2::CanvasGroup->new;
    my ( $width, $height ) = $page->get_size;
    my ( $xres,  $yres )   = $page->get_resolution;

    # Commenting out the scaling factor, as it segfaults in GooCanvas2 v0.06
    # $root->set_scale($yres / $xres, 1);
    $self->set_root_item($root);
    $self->{pixbuf_size} = { width => $width, height => $height };
    $self->set_bounds( 0, 0, $width, $height );

    # Attach the text to the canvas
    $self->{confidence_index} = Gscan2pdf::Canvas::ListIter->new();
    my $tree = Gscan2pdf::Bboxtree->new( $page->{$layer} );
    my $iter = $tree->get_bbox_iter;
    my $box  = $iter->();
    if ( not defined $box ) { return }
    my %options = (
        iter              => $iter,
        box               => $box,
        parents           => [$root],
        transformations   => [ [ 0, 0, 0 ] ],
        edit_callback     => $edit_callback,
        idle              => $idle,
        finished_callback => $finished_callback,
    );
    if ($idle) {
        $self->{old_idles}{$box} = Glib::Idle->add(
            sub {
                $self->_boxed_text(%options);
                delete $self->{old_idles}{$box};
                return Glib::SOURCE_REMOVE;
            }
        );
    }
    else {
        $self->_boxed_text(%options);
    }
    return;
}

sub get_first_bbox {
    my ($self) = @_;
    my $bbox;
    if ( $self->{current_index} eq 'confidence' ) {
        $bbox = $self->{confidence_index}->get_first_bbox;
    }
    else {
        $bbox = $self->{position_index}->first_word;
    }
    $self->set_other_index($bbox);
    return $bbox;
}

sub get_previous_bbox {
    my ($self) = @_;
    my $bbox;
    if ( $self->{current_index} eq 'confidence' ) {
        $bbox = $self->{confidence_index}->get_previous_bbox;
    }
    else {
        $bbox = $self->{position_index}->previous_word;
    }
    $self->set_other_index($bbox);
    return $bbox;
}

sub get_next_bbox {
    my ($self) = @_;
    my $bbox;
    if ( $self->{current_index} eq 'confidence' ) {
        $bbox = $self->{confidence_index}->get_next_bbox;
    }
    else {
        $bbox = $self->{position_index}->next_word;
    }
    $self->set_other_index($bbox);
    return $bbox;
}

sub get_last_bbox {
    my ($self) = @_;
    my $bbox;
    if ( $self->{current_index} eq 'confidence' ) {
        $bbox = $self->{confidence_index}->get_last_bbox;
    }
    else {
        $bbox = $self->{position_index}->last_word;
    }
    $self->set_other_index($bbox);
    return $bbox;
}

sub get_current_bbox {
    my ($self) = @_;
    my $bbox;
    if ( $self->{current_index} eq 'confidence' ) {
        $bbox = $self->{confidence_index}->get_current_bbox;
    }
    else {
        $bbox = $self->{position_index}->get_current_bbox;
    }
    $self->set_other_index($bbox);
    return $bbox;
}

sub set_index_by_bbox {
    my ( $self, $bbox ) = @_;
    if ( not defined $bbox ) { return }
    if ( $self->{current_index} eq 'confidence' ) {
        return $self->{confidence_index}
          ->set_index_by_bbox( $bbox, $bbox->get('confidence') );
    }
    $self->{position_index} = Gscan2pdf::Canvas::TreeIter->new($bbox);
    return;
}

sub set_other_index {
    my ( $self, $bbox ) = @_;
    if ( not defined $bbox ) { return }
    if ( $self->{current_index} eq 'confidence' ) {
        $self->{position_index} = Gscan2pdf::Canvas::TreeIter->new($bbox);
    }
    else {
        $self->{confidence_index}
          ->set_index_by_bbox( $bbox, $bbox->get('confidence') );
    }
    return;
}

sub get_pixbuf_size {
    my ($self) = @_;
    return $self->{pixbuf_size};
}

sub clear_text {
    my ($self) = @_;
    $self->set_root_item( GooCanvas2::CanvasGroup->new );
    delete $self->{pixbuf_size};
    return;
}

sub set_offset {
    my ( $self, $offset_x, $offset_y ) = @_;
    if ( not defined $self->get_pixbuf_size ) { return }

    # Convert the widget size to image scale to make the comparisons easier
    my $allocation = $self->get_allocation;
    ( $allocation->{width}, $allocation->{height} ) =
      $self->_to_image_distance( $allocation->{width}, $allocation->{height} );
    my $pixbuf_size = $self->get_pixbuf_size;

    $offset_x = _clamp_direction( $offset_x, $allocation->{width},
        $pixbuf_size->{width} );
    $offset_y = _clamp_direction( $offset_y, $allocation->{height},
        $pixbuf_size->{height} );

    my $min_x = 0;
    my $min_y = 0;
    if ( $offset_x > 0 ) {
        $min_x = -$offset_x;
    }
    if ( $offset_y > 0 ) {
        $min_y = -$offset_y;
    }
    $self->set_bounds(
        $min_x, $min_y,
        $pixbuf_size->{width} - $min_x,
        $pixbuf_size->{height} - $min_y
    );

    $self->set( 'offset', { x => $offset_x, y => $offset_y } );
    return;
}

sub get_offset {
    my ($self) = @_;
    return $self->get('offset');
}

sub get_bbox_at {
    my ( $self, $selection ) = @_;
    my $x      = $selection->{x} + $selection->{width} / 2;
    my $y      = $selection->{y} + $selection->{height} / 2;
    my $parent = $self->get_item_at( $x, $y, FALSE );
    while ( defined $parent
        and ( not defined $parent->{type} or $parent->{type} eq 'word' ) )
    {
        $parent = $parent->get_property('parent');
    }
    return $parent;
}

sub add_box {
    my ( $self, $text, $selection, $edit_callback, %options ) = @_;

    my $parent = $options{parent};
    if ( not defined $parent ) {
        $parent = $self->get_bbox_at($selection);
        if ( not defined $parent ) { return }
    }

    my @transformation = ( 0, 0, 0 );
    if ( $parent->isa('Gscan2pdf::Canvas::Bbox') ) {
        my $parent_box       = $parent->get('bbox');
        my $parent_textangle = $parent->get('textangle');
        @transformation =
          ( $parent_textangle, $parent_box->{x}, $parent_box->{y} );
    }
    my %options2 = (
        parent         => $parent,
        bbox           => $selection,
        transformation => \@transformation,
    );
    if ( length $text ) { $options2{text} = $text }

    # copy parameters from box from OCR output
    for my $key (qw(baseline confidence id text textangle type)) {
        if ( defined $options{$key} ) {
            $options2{$key} = $options{$key};
        }
    }
    if ( not defined $options2{textangle} ) { $options2{textangle} = 0 }
    if ( not defined $options2{type} )      { $options2{type}      = 'word' }
    if ( not defined $options2{confidence} and $options2{type} eq 'word' ) {
        $options2{confidence} = $_100_PERCENT;
    }

    my $bbox = Gscan2pdf::Canvas::Bbox->new(%options2);
    if ( not defined $self->{position_index} ) {
        $self->{position_index} = Gscan2pdf::Canvas::TreeIter->new($bbox);
    }

    if ( defined $bbox and length $text ) {
        $self->{confidence_index}
          ->add_box_to_index( $bbox, $bbox->get('confidence') );

        # clicking text box produces a dialog to edit the text
        if ($edit_callback) {
            $bbox->signal_connect(
                'button-press-event' => sub {
                    my ( $widget, $target, $event ) = @_;
                    if ( $event->button == 1 ) {
                        $parent->get_parent->{dragging} = FALSE;
                        $edit_callback->( $widget, $target, $event, $bbox );
                    }
                }
            );
        }
    }
    return $bbox;
}

# Draw text on the canvas with a box around it

sub _boxed_text {
    my ( $self, %options ) = @_;
    my $box           = $options{box};
    my $edit_callback = $options{edit_callback};

    # each call should use own copy of arrays to prevent race conditions
    my @transformations = @{ $options{transformations} };
    my @parents         = @{ $options{parents} };
    my $transformation  = $transformations[ $box->{depth} ];
    my ( $rotation, $x0, $y0 ) = @{$transformation};
    my ( $x1, $y1, $x2, $y2 ) = @{ $box->{bbox} };
    my $textangle = $box->{textangle} || 0;

    # copy box parameters from method arguments
    my %options2 = (
        parent         => $parents[ $box->{depth} ],
        transformation => $transformation
    );

    # copy parameters from box from OCR output
    for my $key (qw(baseline confidence id textangle type)) {
        if ( defined $box->{$key} ) {
            $options2{$key} = $box->{$key};
        }
    }

    my %bbox = (
        x      => $x1,
        y      => $y1,
        width  => abs $x2 - $x1,
        height => abs $y2 - $y1,
    );
    my $bbox =
      $self->add_box( $box->{text}, \%bbox, $edit_callback, %options2 );

    # always one more parent, as the page has a root
    if ( $box->{depth} + 1 > $#parents ) {
        push @parents, $bbox;
    }
    else {
        $parents[ $box->{depth} + 1 ] = $bbox;
    }

    push @transformations, [ $textangle + $rotation, $x1, $y1 ];
    my $child = $options{iter}->();
    if ( not defined $child ) {
        if ( $options{finished_callback} ) { $options{finished_callback}->() }
        return;
    }

    my %options3 = (
        box               => $child,
        iter              => $options{iter},
        parents           => \@parents,
        transformations   => \@transformations,
        edit_callback     => $edit_callback,
        idle              => $options{idle},
        finished_callback => $options{finished_callback},
    );
    if ( $options{idle} ) {
        $self->{old_idles}{$child} = Glib::Idle->add(
            sub {
                $self->_boxed_text(%options3);
                delete $self->{old_idles}{$child};
                return Glib::SOURCE_REMOVE;
            }
        );
    }
    else {
        $self->_boxed_text(%options3);
    }

    # $rect->signal_connect(
    #  'button-press-event' => sub {
    #   my ( $widget, $target, $ev ) = @_;
    #   print "rect button-press-event\n";
    #   #  return TRUE;
    #  }
    # );
    # $g->signal_connect(
    #  'button-press-event' => sub {
    #   my ( $widget, $target, $ev ) = @_;
    #   print "group $widget button-press-event\n";
    #   my $n = $widget->get_n_children;
    #   for ( my $i = 0 ; $i < $n ; $i++ ) {
    #    my $item = $widget->get_child($i);
    #    if ( $item->isa('GooCanvas2::CanvasText') ) {
    #     print "contains $item\n", $item->get('text'), "\n";
    #     last;
    #    }
    #   }
    #   #  return TRUE;
    #  }
    # );
    return;
}

# Convert the canvas into hocr

sub hocr {
    my ($self) = @_;
    if ( not defined $self->get_pixbuf_size ) { return }
    my $root   = $self->get_root_item;
    my $string = $root->get_child(0)->to_hocr(2);
    return <<"EOS";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Canvas::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
$string </body>
</html>
EOS
}

# convert x, y in widget distance to image distance
sub _to_image_distance {
    my ( $self, $x, $y ) = @_;
    my $zoom = $self->get_scale;
    return $x / $zoom, $y / $zoom;
}

# set zoom with centre in image coordinates
sub _set_zoom_with_center {
    my ( $self, $zoom, $center_x, $center_y ) = @_;
    if ( $zoom > $MAX_ZOOM ) { $zoom = $MAX_ZOOM }
    my $allocation = $self->get_allocation;
    my $offset_x   = $allocation->{width} / 2 / $zoom - $center_x;
    my $offset_y   = $allocation->{height} / 2 / $zoom - $center_y;
    $self->set_scale($zoom);
    $self->signal_emit( 'zoom-changed', $zoom );
    $self->set_offset( $offset_x, $offset_y );
    return;
}

sub _clamp_direction {
    my ( $offset, $allocation, $pixbuf_size ) = @_;

    # Centre the image if it is smaller than the widget
    if ( $allocation > $pixbuf_size ) {
        $offset = ( $allocation - $pixbuf_size ) / 2;
    }

    # Otherwise don't allow the LH/top edge of the image to be visible
    elsif ( $offset > 0 ) {
        $offset = 0;
    }

    # Otherwise don't allow the RH/bottom edge of the image to be visible
    elsif ( $offset < $allocation - $pixbuf_size ) {
        $offset = $allocation - $pixbuf_size;
    }
    return $offset;
}

sub _button_pressed {
    my ( $self, $event ) = @_;

    # middle mouse button
    if ( $event->button == 2 ) {

        # Using the root window x,y position for dragging the canvas, as the
        # values returned by $event->x and y cause a bouncing effect, and
        # only the value since the last event is required.
        my ( $screen, $x, $y ) = $device->get_position;
        $self->{drag_start} = { x => $x, y => $y };
        $self->{dragging}   = TRUE;

        #    $self->update_cursor( $event->x, $event->y );
    }

    # allow the event to propagate in case the user was clicking on text to edit
    return;
}

sub _button_released {
    my ( $self, $event ) = @_;
    if ( $event->button == 2 ) { $self->{dragging} = FALSE }

    #    $self->update_cursor( $event->x, $event->y );
    return;
}

sub _motion {
    my ( $self, $event ) = @_;
    if ( not $self->{dragging} ) { return FALSE }

    my $offset = $self->get_offset;
    my $zoom   = $self->get_scale;
    my ( $screen, $x, $y ) = $device->get_position;
    my $offset_x = $offset->{x} + ( $x - $self->{drag_start}{x} ) / $zoom;
    my $offset_y = $offset->{y} + ( $y - $self->{drag_start}{y} ) / $zoom;
    ( $self->{drag_start}{x}, $self->{drag_start}{y} ) = ( $x, $y );
    $self->set_offset( $offset_x, $offset_y );
    return;
}

sub _scroll {
    my ( $self, $event ) = @_;
    my ( $center_x, $center_y ) =
      $self->convert_from_pixels( $event->x, $event->y );

    my $zoom;
    if ( $event->direction eq 'up' ) {
        $zoom = $self->get_scale * 2;
    }
    else {
        $zoom = $self->get_scale / 2;
    }
    $self->_set_zoom_with_center( $zoom, $center_x, $center_y );

    # don't allow the event to propagate, as this pans it in y
    return TRUE;
}

sub sort_by_confidence {
    my ($self) = @_;
    $self->{current_index} = 'confidence';
    return;
}

sub sort_by_position {
    my ($self) = @_;
    $self->{current_index} = 'position';
    return;
}

1;

__END__
