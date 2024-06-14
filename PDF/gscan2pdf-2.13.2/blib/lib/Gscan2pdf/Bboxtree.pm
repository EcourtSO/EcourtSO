package Gscan2pdf::Bboxtree;

use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use HTML::TokeParser;
use Encode qw(decode_utf8 encode_utf8);
use Glib   qw(TRUE FALSE);                # To get TRUE and FALSE
use Gscan2pdf::Document;
use Carp;
use JSON::PP;

#use Text::Balanced qw ( extract_bracketed );
use Readonly;
Readonly my $EMPTY_LIST => -1;
Readonly my $HALF       => 0.5;
my $EMPTY         = q{};
my $SPACE         = q{ };
my $DOUBLE_QUOTES = q{"};
my $BBOX_REGEX    = qr{(\d+)\s+(\d+)\s+(\d+)\s+(\d+)}xsm;
my $HILITE_REGEX  = qr{[(]hilite\s+[#][A-Fa-f\d]{6}[)]\s+[(]xor[)]}xsm;

BEGIN {
    use Exporter ();
    our ( $VERSION, @EXPORT_OK, %EXPORT_TAGS );

    $VERSION = '2.13.2';

    use base qw(Exporter);
    %EXPORT_TAGS = ();    # eg: TAG => [ qw!name1 name2! ],

    # your exported package globals go here,
    # as well as any optionally exported functions
    @EXPORT_OK = qw();
}
our @EXPORT_OK;

sub new {
    my ( $class, $json ) = @_;
    my $self = [];
    if ( defined $json ) {
        $self = JSON::PP->new->allow_nonref->decode($json);
    }
    return bless $self, $class;
}

sub valid {
    my ( $class, $json ) = @_;
    my $self = $class->new($json);
    my $iter = $self->get_bbox_iter();
    while ( my $bbox = $iter->() ) {
        my ( $x1, $y1, $x2, $y2 ) = @{ $bbox->{bbox} };
        if ( $bbox->{type} eq 'page' ) {
            if ( $x2 == 0 or $y2 == 0 ) { return FALSE }
            return TRUE;
        }
    }
    return FALSE;
}

sub json {
    my ($self) = @_;
    my @boxes;
    for my $box ( @{$self} ) {
        push @boxes, JSON::PP->new->convert_blessed->encode($box);
    }
    my $json = join q{,}, @boxes;
    return "[$json]";
}

sub from_hocr {
    my ( $self, $hocr ) = @_;
    if ( not defined $hocr or $hocr !~ /<body>[\s\S]*<\/body>/xsm ) { return }
    my $box_tree = _hocr2boxes($hocr);
    _prune_empty_branches($box_tree);
    if ( $#{$box_tree} > $EMPTY_LIST ) {
        _walk_bboxes(
            $box_tree->[0],
            sub {
                my ($oldbox) = @_;

                # clone bbox without children
                my %newbox = map { $_ => $oldbox->{$_} } keys %{$oldbox};
                delete $newbox{contents};
                push @{$self}, \%newbox;
            }
        );
    }
    return;
}

sub from_text {
    my ( $self, $text, $width, $height ) = @_;
    push @{$self},
      {
        type  => 'page',
        bbox  => [ 0, 0, $width, $height ],
        text  => $text,
        depth => 0,
      };
    return;
}

# an iterator for parsing bboxes
# iterator returns bbox
# my $iter = $self->get_bbox_iter();
# while (my $bbox = $iter->()) {}

sub get_bbox_iter {
    my ($self) = @_;
    my $iter = 0;
    return sub {
        return $self->[ $iter++ ];
    };
}

sub _hocr2boxes {
    my ($hocr) = @_;
    my $p = HTML::TokeParser->new( \$hocr );
    my ( $data, @stack, $boxes );
    while ( my $token = $p->get_token ) {
        given ( $token->[0] ) {
            when ('S') {
                my ( $tag, %attrs ) = ( $token->[1], %{ $token->[2] } );

                # new data point
                $data = {};

                if ( defined $attrs{class} and defined $attrs{title} ) {
                    _parse_tag_data( $attrs{title}, $data );
                    given ( $attrs{class} ) {
                        when (/_page$/xsm) {
                            $data->{type} = 'page';
                            push @{$boxes}, $data;
                        }
                        when (/_carea$/xsm) {
                            $data->{type} = 'column';
                        }
                        when (/_par$/xsm) {
                            $data->{type} = 'para';
                        }
                        when (/_header$/xsm) {
                            $data->{type} = 'header';
                        }
                        when (/_footer$/xsm) {
                            $data->{type} = 'footer';
                        }
                        when (/_caption$/xsm) {
                            $data->{type} = 'caption';
                        }
                        when (/_line$/xsm) {
                            $data->{type} = 'line';
                        }
                        when (/_word$/xsm) {
                            $data->{type} = 'word';
                        }
                    }

                    # pick up previous pointer to add style
                    if ( not defined $data->{type} ) {
                        $data = $stack[-1];
                    }

                    # put information xocr_word information in parent ocr_word
                    if (    $data->{type} eq 'word'
                        and $stack[-1]{type} eq 'word' )
                    {
                        for ( keys %{$data} ) {
                            if ( not defined $stack[-1]{$_} ) {
                                $stack[-1]{$_} = $data->{$_};
                            }
                        }

                        # pick up previous pointer to add any later text
                        $data = $stack[-1];
                    }
                    else {
                        if ( defined $attrs{id} ) {
                            $data->{id} = $attrs{id};
                        }

                        # if we have previous data, add the new data to the
                        # contents of the previous data point
                        if (    defined $stack[-1]
                            and $data != $stack[-1]
                            and defined $data->{bbox} )
                        {
                            push @{ $stack[-1]{contents} }, $data;
                        }
                    }
                }

                # pick up previous pointer
                # so that unknown tags don't break the chain
                else {
                    $data = $stack[-1];
                }
                if ( defined $data ) {
                    if ( $tag eq 'strong' ) { push @{ $data->{style} }, 'Bold' }
                    if ( $tag eq 'em' ) { push @{ $data->{style} }, 'Italic' }
                }

                # put the new data point on the stack
                push @stack, $data;
            }
            when ('T') {
                if ( $token->[1] !~ /^\s*$/xsm ) {
                    $data->{text} = _decode_hocr( $token->[1] );
                    chomp $data->{text};
                }
            }
            when ('E') {

                # up a level
                $data = pop @stack;
            }
        }

    }
    return $boxes;
}

sub _parse_tag_data {
    my ( $title, $data ) = @_;
    if ( $title =~ /\bbbox\s+$BBOX_REGEX/xsm ) {
        if ( $1 != $3 and $2 != $4 ) { $data->{bbox} = [ $1, $2, $3, $4 ] }
    }
    if ( $title =~ /\btextangle\s+(\d+)/xsm ) { $data->{textangle}  = $1 }
    if ( $title =~ /\bx_wconf\s+(-?\d+)/xsm ) { $data->{confidence} = $1 }
    if ( $title =~ /\bbaseline\s+((?:-?\d+(?:[.]\d+)?\s+)*-?\d+)/xsm ) {
        my @values = split /\s+/sm, $1;

        # make sure we at least have 2 coefficients
        if ( $#values <= 0 ) { unshift @values, 0; }
        $data->{baseline} = \@values;
    }
    return;
}

sub _prune_empty_branches {
    my ($boxes) = @_;
    if ( defined $boxes ) {
        my $i = 0;
        while ( $i <= $#{$boxes} ) {
            my $child = $boxes->[$i];
            _prune_empty_branches( $child->{contents} );
            if ( $#{ $child->{contents} } == $EMPTY_LIST ) {
                delete $child->{contents};
            }
            if ( $#{$boxes} > $EMPTY_LIST
                and not( defined $child->{contents} or defined $child->{text} )
              )
            {
                splice @{$boxes}, $i, 1;
            }
            else {
                $i++;
            }
        }
    }
    return;
}

# Unfortunately, there seems to be a case (tested in t/31_ocropus_utf8.t)
# where decode_entities doesn't work cleanly, so encode/decode to finally
# get good UTF-8

sub _decode_hocr {
    my ($hocr) = @_;
    return decode_utf8( encode_utf8( HTML::Entities::decode_entities($hocr) ) );
}

# walk through tree of boxes, calling $callback on each bbox

sub _walk_bboxes {
    my ( $bbox, $callback, $depth ) = @_;
    if ( not defined $depth ) { $depth = 0 }
    $bbox->{depth} = $depth++;
    if ( defined $callback ) {
        $callback->($bbox);
    }
    if ( defined $bbox->{contents} ) {
        for my $child ( @{ $bbox->{contents} } ) {
            _walk_bboxes( $child, $callback, $depth );
        }
    }
    return;
}

sub to_djvu_txt {
    my ($self) = @_;
    my $string = $EMPTY;
    my ( $prev_depth, $h );
    my $iter = $self->get_bbox_iter();
    while ( my $bbox = $iter->() ) {
        if ( defined $prev_depth ) {
            while ( $prev_depth-- >= $bbox->{depth} ) { $string .= ')' }
        }
        $prev_depth = $bbox->{depth};
        my $type = $bbox->{type};
        if ( $type !~ /^(?:page|column|para|line|word)$/xsm ) {
            if ( $bbox->{id} =~ /([[:alpha:]]+)/xsm ) {
                $type = $1;
            }
            else {
                $type = 'line';
            }
        }
        if ( $type eq 'page' ) { $h = $bbox->{bbox}[-1] }
        my ( $x1, $y1, $x2, $y2 ) = @{ $bbox->{bbox} };
        if ( $bbox->{depth} != 0 ) { $string .= "\n" }
        for ( 1 .. $bbox->{depth} * 2 ) { $string .= $SPACE }
        $string .= sprintf "($type %d %d %d %d", $x1, $h - $y2, $x2, $h - $y1;
        if ( defined $bbox->{text} ) {
            $string .=
                $SPACE
              . $DOUBLE_QUOTES
              . _escape_text( $bbox->{text} )
              . $DOUBLE_QUOTES;
        }
    }
    if ( defined $prev_depth ) {
        while ( $prev_depth-- >= 0 ) { $string .= ')' }
    }
    if ( $string ne $EMPTY ) { $string .= "\n" }
    return $string;
}

sub to_djvu_ann {
    my ($self) = @_;
    my $string = $EMPTY;
    my $h;
    my $iter = $self->get_bbox_iter();
    while ( my $bbox = $iter->() ) {
        if ( $bbox->{type} eq 'page' ) { $h = $bbox->{bbox}[-1] }
        if ( defined $bbox->{text} ) {
            my ( $x1, $y1, $x2, $y2 ) = @{ $bbox->{bbox} };
            $string .=
              sprintf
              "(maparea \"\" \"%s\" (rect %d %d %d %d) (hilite #%s) (xor))\n",
              _escape_text( $bbox->{text} ), $x1, $h - $y2, $x2 - $x1,
              $y2 - $y1, $Gscan2pdf::Document::ANNOTATION_COLOR;
        }
    }
    return $string;
}

sub from_djvu_ann {
    my ( $self, $djvuann, $imagew, $imageh ) = @_;
    push @{$self},
      {
        type  => 'page',
        bbox  => [ 0, 0, $imagew, $imageh, ],
        depth => 0,
      };
    for my $line ( split /\n/xsm, $djvuann ) {
        if (
            $line =~ m{[(]maparea\s+".*" # url
\s+"(.*)" # text field enclosed in inverted commas
\s+[(]rect\s+$BBOX_REGEX[)] # bounding box
\s+$HILITE_REGEX # highlight color
[)]}xsm
          )
        {
            push @{$self},
              {
                type  => 'word',
                depth => 1,
                text  => $1,
                bbox  => [ $2, $imageh - $3 - $5, $2 + $4, $imageh - $3 ]
              };
        }
        else {
            croak "Error parsing djvu annotation $line";
        }
    }
    return;
}

# Escape backslashes and inverted commas
sub _escape_text {
    my ($txt) = @_;
    $txt =~ s/\\/\\\\/gxsm;
    $txt =~ s/"/\\\"/gxsm;
    return $txt;
}

# return as plain text

sub to_text {
    my ($self) = @_;
    my $string = $EMPTY;
    my $iter   = $self->get_bbox_iter();
    while ( my $bbox = $iter->() ) {
        if ( $string ne $EMPTY ) {
            if ( $bbox->{type} eq 'line' and $string =~ /\S$/xsm ) {
                $string .= $SPACE;
            }
            if ( $bbox->{type} eq 'para' ) {
                $string .= "\n\n";
            }
        }
        if ( defined $bbox->{text} ) { $string .= $bbox->{text} . $SPACE }
    }

    # squash whitespace at the end of any line
    $string =~ s/[ ]+$//xsmg;
    return $string;
}

sub from_djvu_txt {
    my ( $self, $djvutext ) = @_;
    my $h;
    my $depth = 0;
    for my $line ( split /\n/xsm, $djvutext ) {
        if ( $line =~ /^\s*([(]+)(\w+)\s+$BBOX_REGEX(.*?)([)]*)$/xsm ) {
            my %bbox;
            $depth += length $1;
            $bbox{depth} = $depth - 1;
            $bbox{type}  = $2;
            if ( $2 eq 'page' ) { $h = $6 }
            $bbox{bbox} = [ $3, $h - $6, $5, $h - $4 ];
            my $text = $7;
            if ($8) { $depth -= length $8 }

            if ( $text =~ /\A\s*"(.*)"\s*\z/xsm ) {
                $bbox{text} = $1;
            }
            push @{$self}, \%bbox;
        }
        else {
            croak "Error parsing djvu line $line";
        }
    }
    return;
}

sub _pdftotext2boxes {
    my ( $html, $xresolution, $yresolution, $imagew, $imageh ) = @_;
    my $p = HTML::TokeParser->new( \$html );
    my ( $data, @stack, $boxes );
    my $offset = 0;
    while ( my $token = $p->get_token ) {
        given ( $token->[0] ) {
            when ('S') {
                my ( $tag, %attrs ) = ( $token->[1], %{ $token->[2] } );

                # new data point
                $data = {};

                if ( $tag eq 'page' ) {
                    $data->{type} = $tag;
                    if ( defined $attrs{width} and defined $attrs{height} ) {
                        my $width  = scale( $attrs{width},  $xresolution );
                        my $height = scale( $attrs{height}, $yresolution );
                        if ( $width == 2 * $imagew && $height == $imageh ) {
                            $offset = $imagew;
                        }
                        $data->{bbox} = [ 0, 0, $width - $offset, $height ];
                    }
                    push @{$boxes}, $data;
                }
                elsif ( $tag eq 'word' ) {
                    $data->{type} = $tag;
                    if (    defined $attrs{xmin}
                        and defined $attrs{ymin}
                        and defined $attrs{xmax}
                        and defined $attrs{ymax} )
                    {
                        $data->{bbox} = [
                            scale( $attrs{xmin}, $xresolution ) - $offset,
                            scale( $attrs{ymin}, $yresolution ),
                            scale( $attrs{xmax}, $xresolution ) - $offset,
                            scale( $attrs{ymax}, $yresolution )
                        ];
                    }
                }

                # if we have previous data, add the new data to the
                # contents of the previous data point
                if (    defined $stack[-1]
                    and $data != $stack[-1]
                    and defined $data->{bbox} )
                {
                    push @{ $stack[-1]{contents} }, $data;
                }

                # put the new data point on the stack
                if ( defined $data->{bbox} ) { push @stack, $data }
            }
            when ('T') {
                if ( $token->[1] !~ /^\s*$/xsm ) {
                    $data->{text} = _decode_hocr( $token->[1] );
                    chomp $data->{text};
                }
            }
            when ('E') {

                # up a level
                $data = pop @stack;
            }
        }

    }
    return $boxes;
}

sub scale {
    my ( $f, $resolution ) = @_;
    return
      int( $f * $resolution / $Gscan2pdf::Document::POINTS_PER_INCH + $HALF );
}

sub from_pdftotext {
    my ( $self, $html, @image_data ) = @_;
    my ( $xresolution, $yresolution, $imagew, $imageh ) = @image_data;
    if ( $html !~ /<body>[\s\S]*<\/body>/xsm ) { return }
    my $box_tree =
      _pdftotext2boxes( $html, $xresolution, $yresolution, $imagew, $imageh );
    _prune_empty_branches($box_tree);
    if ( $#{$box_tree} > $EMPTY_LIST ) {
        _walk_bboxes(
            $box_tree->[0],
            sub {
                my ($oldbox) = @_;

                # clone bbox without children
                my %newbox = map { $_ => $oldbox->{$_} } keys %{$oldbox};
                delete $newbox{contents};
                push @{$self}, \%newbox;
            }
        );
    }
    return;
}

sub to_hocr {
    my ($self) = @_;
    my $string = <<"EOS";
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
 "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <meta http-equiv="Content-Type" content="text/html;charset=utf-8" />
  <meta name='ocr-system' content='gscan2pdf $Gscan2pdf::Page::VERSION' />
  <meta name='ocr-capabilities' content='ocr_page ocr_carea ocr_par ocr_line ocr_word'/>
 </head>
 <body>
EOS
    my ( $prev_depth, @tags );
    my $iter = $self->get_bbox_iter();
    while ( my $bbox = $iter->() ) {
        $string .= _bbox_to_hocr( $bbox, \$prev_depth, \@tags );
    }
    if (@tags) { $string .= '</' . pop(@tags) . ">\n" }
    $prev_depth--;
    while ( $prev_depth-- >= 0 ) {
        $string .= $SPACE x ( 2 + $prev_depth + 1 ) . '</' . pop(@tags) . ">\n";
    }
    $string .= " </body>\n</html>\n";
    return $string;
}

sub _bbox_to_hocr {
    my ( $bbox, $prev_depth, $tags ) = @_;
    my $string = q{};
    if ( defined ${$prev_depth} ) {
        if ( ${$prev_depth} >= $bbox->{depth} ) {
            if ( @{$tags} ) { $string .= '</' . pop( @{$tags} ) . ">\n" }
            ${$prev_depth}--;
            while ( ${$prev_depth}-- >= $bbox->{depth} ) {
                $string .= $SPACE x ( 2 + ${$prev_depth} + 1 ) . '</'
                  . pop( @{$tags} ) . ">\n";
            }
        }
        else {
            $string .= "\n";
        }
    }
    ${$prev_depth} = $bbox->{depth};
    my ( $x1, $y1, $x2, $y2 ) = @{ $bbox->{bbox} };
    my $type = 'ocr_' . $bbox->{type};
    my $tag  = 'span';
    given ( $bbox->{type} ) {
        when ('page') {
            $tag = 'div';
        }
        when (/^(?:carea|column)$/xsm) {
            $type = 'ocr_carea';
            $tag  = 'div';
        }
        when ('para') {
            $type = 'ocr_par';
            $tag  = 'p';
        }
    }
    $string .= $SPACE x ( 2 + $bbox->{depth} ) . "<$tag class='$type'";
    if ( defined $bbox->{id} ) { $string .= " id='$bbox->{id}'" }
    $string .= " title='bbox $x1 $y1 $x2 $y2";
    if ( defined $bbox->{baseline} ) {
        $string .= '; baseline ' . join $SPACE, @{ $bbox->{baseline} };
    }
    if ( defined $bbox->{textangle} ) {
        $string .= "; textangle $bbox->{textangle}";
    }
    if ( defined $bbox->{confidence} ) {
        $string .= "; x_wconf $bbox->{confidence}";
    }
    $string .= "'>";
    if ( defined $bbox->{text} ) {
        if ( defined $bbox->{style} ) {
            for my $tag ( @{ $bbox->{style} } ) {
                if    ( $tag eq 'Bold' )   { $string .= '<strong>' }
                elsif ( $tag eq 'Italic' ) { $string .= '<em>' }
            }
        }
        $string .= HTML::Entities::encode( $bbox->{text}, "<>&\"'" );
        if ( defined $bbox->{style} ) {
            for my $tag ( reverse @{ $bbox->{style} } ) {
                if    ( $tag eq 'Bold' )   { $string .= '</strong>' }
                elsif ( $tag eq 'Italic' ) { $string .= '</em>' }
            }
        }
    }
    push @{$tags}, $tag;
    return $string;
}

sub crop {
    my ( $self, $x, $y, $w, $h ) = @_;
    my $i = 0;
    while ( $i <= $#{$self} ) {
        my $bbox = $self->[$i];
        my ( $text_x1, $text_y1, $text_x2, $text_y2 ) = @{ $bbox->{bbox} };
        ( $text_x1, $text_x2 ) = _crop_axis( $text_x1, $text_x2, $x, $x + $w );
        ( $text_y1, $text_y2 ) = _crop_axis( $text_y1, $text_y2, $y, $y + $h );

        # cropped outside box, so remove box
        if ( not defined $text_x1 or not defined $text_y1 ) {
            splice @{$self}, $i, 1;
            next;
        }

        # update box
        $bbox->{bbox} = [ $text_x1, $text_y1, $text_x2, $text_y2 ];
        $i++;
    }
    return $self;
}

# More trouble that it's worth to refactor this as a dispatch table, as it would
# require converting the inequalities into a string of binaries, which would be
# less easy to understand. In this case the if-else cascade is better.

sub _crop_axis {
    my ( $text1, $text2, $crop1, $crop2 ) = @_;
    if ( $text1 > $crop2 or $text2 < $crop1 ) { return }

    # crop inside edges of box
    if ( $text1 <= $crop1 and $text2 >= $crop2 )
    {    ## no critic (ProhibitCascadingIfElse)
        $text1 = 0;
        $text2 = $crop2 - $crop1;
    }

    # crop outside edges of box
    elsif ( $text1 >= $crop1 and $text2 <= $crop2 ) {
        $text1 -= $crop1;
        $text2 -= $crop1;
    }

    # crop over 2nd edge of box
    elsif ( $text2 >= $crop1 and $text2 <= $crop2 ) {
        $text1 = 0;
        $text2 -= $crop1;
    }

    # crop over 1st edge of box
    elsif ( $text1 >= $crop1 and $text1 <= $crop2 ) {
        $text1 -= $crop1;
        $text2 = $crop2 - $crop1;
    }
    return $text1, $text2;
}

1;

__END__
