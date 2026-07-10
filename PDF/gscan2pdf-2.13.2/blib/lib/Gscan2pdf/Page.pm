package Gscan2pdf::Page;

use 5.008005;
use strict;
use warnings;
use feature 'switch';
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Carp;
use Glib qw(TRUE FALSE);    # To get TRUE and FALSE
use File::Copy;
use File::Temp;                      # To create temporary files
use Image::Magick;
use POSIX qw(locale_h);
use Data::UUID;
use English qw( -no_match_vars );    # for $ERRNO
use Try::Tiny;
use Gscan2pdf::Document;
use Gscan2pdf::Bboxtree;
use Gscan2pdf::Translation '__';     # easier to extract strings with xgettext
use Readonly;
Readonly my $CM_PER_INCH    => 2.54;
Readonly my $MM_PER_CM      => 10;
Readonly my $MM_PER_INCH    => $CM_PER_INCH * $MM_PER_CM;
Readonly my $PAGE_TOLERANCE => 0.02;
Readonly my $EMPTY_LIST     => -1;
my $EMPTY         = q{};
my $SPACE         = q{ };
my $DOUBLE_QUOTES = q{"};

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

my ($logger);
my $uuid = Data::UUID->new;

sub new {
    my ( $class, %options ) = @_;
    my $self = {};

    if ( not defined $options{filename} ) {
        croak 'Error: filename not supplied';
    }
    if ( not -f $options{filename} ) { croak 'Error: filename not found' }
    if ( not defined $options{format} ) {
        croak 'Error: format not supplied';
    }

    $logger->info(
        "New page filename $options{filename}, format $options{format}");
    for ( keys %options ) {
        $self->{$_} = $options{$_};
    }
    $self->{uuid} = $uuid->create_str();

    # copy or move image to session directory
    my %suffix = (
        'Portable Network Graphics'                    => '.png',
        'Joint Photographic Experts Group JFIF format' => '.jpg',
        'Tagged Image File Format'                     => '.tif',
        'Portable anymap'                              => '.pnm',
        'Portable pixmap format (color)'               => '.ppm',
        'Portable graymap format (gray scale)'         => '.pgm',
        'Portable bitmap format (black and white)'     => '.pbm',
        'CompuServe graphics interchange format'       => '.gif',
    );
    $self->{filename} = File::Temp->new(
        DIR    => $options{dir},
        SUFFIX => $suffix{ $options{format} },
        UNLINK => FALSE,
    );
    if ( defined $options{delete} and $options{delete} ) {
        move( $options{filename}, $self->{filename} )
          or croak sprintf __('Error importing image %s: %s'),
          $options{filename}, $ERRNO;
    }
    else {
        copy( $options{filename}, $self->{filename} )
          or croak sprintf __('Error importing image %s: %s'),
          $options{filename}, $ERRNO;
    }

    bless $self, $class;

    # Add units if not defined
    if ( $suffix{ $options{format} } !~ /^[.]p.m$/xsm ) {
        my $image = $self->im_object;
        my $units = $image->Get('units');
        if ( $units =~ /undefined/xsm ) {
            my ( $xresolution, $yresolution ) = $self->get_resolution;
            $image->Write(
                units    => 'PixelsPerInch',
                density  => $xresolution . 'x' . $yresolution,
                filename => $self->{filename}
            );
        }
    }

    $logger->info("New page written as $self->{filename} ($self->{uuid})");
    return $self;
}

sub set_logger {
    ( my $class, $logger ) = @_;
    return;
}

sub clone {
    my ( $self, $copy_image ) = @_;
    my $new = {};
    for ( keys %{$self} ) {
        $new->{$_} = $self->{$_};
    }
    $new->{uuid} = $uuid->create_str();
    if ($copy_image) {
        my $suffix;
        if ( $self->{filename} =~ /([.]\w*)$/xsm ) { $suffix = $1 }
        $new->{filename} =
          File::Temp->new( DIR => $self->{dir}, SUFFIX => $suffix );
        $logger->info(
"Cloning $self->{filename} ($self->{uuid}) -> $new->{filename} ($new->{uuid})"
        );

        # stringify filename to prevent copy from mangling it
        copy( "$self->{filename}", "$new->{filename}" )
          or croak sprintf __('Error copying image %s: %s'),
          $self->{filename}, $ERRNO;
    }
    bless $new, ref $self;
    return $new;
}

# cloning File::Temp objects causes problems

sub freeze {
    my ($self) = @_;
    my $new = $self->clone;
    if ( ref( $new->{filename} ) eq 'File::Temp' ) {
        $new->{filename}->unlink_on_destroy(FALSE);
        $new->{filename} = $self->{filename}->filename;
    }
    if ( ref( $new->{dir} ) eq 'File::Temp::Dir' ) {
        $new->{dir} = $self->{dir}->dirname;
    }
    $new->{uuid} = $self->{uuid};
    return $new;
}

sub thaw {
    my ($self) = @_;
    my $new = $self->clone;
    my $suffix;
    if ( $new->{filename} =~ /[.](\w*)$/xsm ) {
        $suffix = $1;
    }
    my $filename = File::Temp->new( DIR => $new->{dir}, SUFFIX => ".$suffix" );
    move( $new->{filename}, $filename );
    $new->{filename} = $filename;
    $new->{uuid}     = $self->{uuid};
    return $new;
}

sub import_hocr {
    my ( $self, $hocr ) = @_;
    my $bboxtree = Gscan2pdf::Bboxtree->new;
    $bboxtree->from_hocr($hocr);
    $self->{text_layer} = $bboxtree->json;
    return;
}

sub export_hocr {
    my ($self) = @_;
    if ( defined $self->{text_layer} ) {
        return Gscan2pdf::Bboxtree->new( $self->{text_layer} )->to_hocr;
    }
    return;
}

sub import_djvu_txt {
    my ( $self, $djvu ) = @_;
    my $tree = Gscan2pdf::Bboxtree->new;
    $tree->from_djvu_txt($djvu);
    $self->{text_layer} = $tree->json;
    return;
}

sub export_djvu_txt {
    my ($self) = @_;
    if ( defined $self->{text_layer} ) {
        return Gscan2pdf::Bboxtree->new( $self->{text_layer} )->to_djvu_txt;
    }
    return;
}

sub import_text {
    my ( $self, $text ) = @_;
    if ( not defined $self->{width} ) {
        $self->get_size;
    }
    my $tree = Gscan2pdf::Bboxtree->new;
    $tree->from_text( $text, $self->{width}, $self->{height} );
    $self->{text_layer} = $tree->json;
    return;
}

sub export_text {
    my ($self) = @_;
    if ( defined $self->{text_layer} ) {
        return Gscan2pdf::Bboxtree->new( $self->{text_layer} )->to_text;
    }
    return;
}

sub import_pdftotext {
    my ( $self, $html ) = @_;
    my $tree = Gscan2pdf::Bboxtree->new;
    $tree->from_pdftotext( $html, $self->get_resolution, $self->get_size );
    $self->{text_layer} = $tree->json;
    return;
}

sub import_annotations {
    my ( $self, $hocr ) = @_;
    my $bboxtree = Gscan2pdf::Bboxtree->new;
    $bboxtree->from_hocr($hocr);
    $self->{annotations} = $bboxtree->json;
    return;
}

sub import_djvu_ann {
    my ( $self,   $ann )    = @_;
    my ( $imagew, $imageh ) = $self->get_size;
    my $tree = Gscan2pdf::Bboxtree->new;
    $tree->from_djvu_ann( $ann, $imagew, $imageh );
    $self->{annotations} = $tree->json;
    return;
}

sub export_djvu_ann {
    my ($self) = @_;
    if ( defined $self->{annotations} ) {
        return Gscan2pdf::Bboxtree->new( $self->{annotations} )->to_djvu_ann;
    }
    return;
}

sub to_png {
    my ( $self, $page_sizes ) = @_;

    # Write the png
    my $png =
      File::Temp->new( DIR => $self->{dir}, SUFFIX => '.png', UNLINK => FALSE );
    my ( $xresolution, $yresolution ) = $self->get_resolution($page_sizes);
    $self->im_object->Write(
        units    => 'PixelsPerInch',
        density  => $xresolution . 'x' . $yresolution,
        filename => $png
    );
    my $new = Gscan2pdf::Page->new(
        filename    => $png,
        format      => 'Portable Network Graphics',
        dir         => $self->{dir},
        xresolution => $xresolution,
        yresolution => $yresolution,
        width       => $self->{width},
        height      => $self->{height},
    );
    if ( defined $self->{text_layer} ) {
        $new->{text_layer} = $self->{text_layer};
    }
    return $new;
}

sub get_size {
    my ($self) = @_;
    if ( not defined $self->{width} or not defined $self->{height} ) {
        my $image = $self->im_object;
        $self->{width}  = $image->Get('width');
        $self->{height} = $image->Get('height');
    }
    return $self->{width}, $self->{height};
}

sub get_resolution {
    my ( $self, $paper_sizes ) = @_;
    if ( defined $self->{xresolution} and defined $self->{yresolution} ) {
        return $self->{xresolution}, $self->{yresolution};
    }
    setlocale( LC_NUMERIC, 'C' );

    if ( defined $self->{size} ) {
        my ( $width, $height ) = $self->get_size;
        $logger->debug("PDF size @{$self->{size}}");
        $logger->debug("image size $width $height");
        my $scale = $Gscan2pdf::Document::POINTS_PER_INCH;
        if ( $self->{size}[2] ne 'pts' ) {
            croak "Error: unknown units '$self->{size}[2]'";
        }
        $self->{xresolution} = $width / $self->{size}[0] * $scale;
        $self->{yresolution} = $height / $self->{size}[1] * $scale;
        $logger->debug("resolution $self->{xresolution} $self->{yresolution}");
        return $self->{xresolution}, $self->{yresolution};
    }

    # Imagemagick always reports PNMs as 72ppi
    # Some versions of imagemagick report colour PNM as Portable pixmap (PPM)
    # B&W are Portable anymap
    my $image  = $self->im_object;
    my $format = $image->Get('format');
    if ( $format !~ /^Portable[ ]...map/xsm ) {
        $self->{xresolution} = $image->Get('x-resolution');
        $self->{yresolution} = $image->Get('y-resolution');

        if ( $self->{xresolution} ) {
            my $units = $image->Get('units');
            if ( $units eq 'pixels / centimeter' ) {
                $self->{xresolution} *= $CM_PER_INCH;
                $self->{yresolution} *= $CM_PER_INCH;
            }
            elsif ( $units =~ /undefined/xsm ) {
                $logger->warn('Undefined units.');
            }
            elsif ( $units ne 'pixels / inch' ) {
                $logger->warn("Unknown units: '$units'.");
                $units = 'undefined';
            }
            if ( $units =~ /undefined/xsm ) {
                $logger->warn(
                    'The resolution and page size will probably be wrong.');
            }
            return $self->{xresolution}, $self->{yresolution};
        }
    }

    # Return the first match based on the format
    for ( values %{ $self->matching_paper_sizes($paper_sizes) } ) {
        $self->{xresolution} = $_;
        $self->{yresolution} = $_;
        return $self->{xresolution}, $self->{yresolution};
    }

    # Default to 72
    $self->{xresolution} = $Gscan2pdf::Document::POINTS_PER_INCH;
    $self->{yresolution} = $Gscan2pdf::Document::POINTS_PER_INCH;
    return $self->{xresolution}, $self->{yresolution};
}

# Given paper width and height (mm), and hash of paper sizes,
# returns hash of matching resolutions (pixels per inch)

sub matching_paper_sizes {
    my ( $self,  $paper_sizes ) = @_;
    my ( $width, $height )      = $self->get_size;
    my %matching;
    if ( not( defined $height and defined $width ) ) {
        $logger->warn(
'ImageMagick returns undef for image size - resolution cannot be guessed'
        );
        return \%matching;
    }
    my $ratio = $height / $width;
    if ( $ratio < 1 ) { $ratio = 1 / $ratio }
    for ( keys %{$paper_sizes} ) {
        if ( $paper_sizes->{$_}{x} > 0
            and abs( $ratio - $paper_sizes->{$_}{y} / $paper_sizes->{$_}{x} ) <
            $PAGE_TOLERANCE )
        {
            $matching{$_} =
              ( ( $height > $width ) ? $height : $width ) /
              $paper_sizes->{$_}{y} *
              $MM_PER_INCH;
        }
    }
    return \%matching;
}

# returns Image::Magick object

sub im_object {
    my ($self) = @_;
    my $image  = Image::Magick->new;
    my $x      = $image->Read( $self->{filename} );
    if ("$x") { $logger->warn("Error creating IM object - $x"); croak $x }
    return $image;
}

# logic taken from at_scale_size_prepared_cb() in
# https://gitlab.gnome.org/GNOME/gdk-pixbuf/blob/2.40.0/gdk-pixbuf/gdk-pixbuf-io.c

sub _prepare_scale {
    my ( $image_width, $image_height, $res_ratio, $max_width, $max_height ) =
      @_;
    if (   $image_width <= 0
        or $image_height <= 0
        or $max_width <= 0
        or $max_height <= 0 )
    {
        return;
    }
    $image_width = $image_width / $res_ratio;

    if ( $image_height * $max_width > $image_width * $max_height ) {
        $image_width  = $image_width * $max_height / $image_height;
        $image_height = $max_height;
    }
    else {
        $image_height = $image_height * $max_width / $image_width;
        $image_width  = $max_width;
    }

    return $image_width, $image_height;
}

# Returns the pixbuf scaled to fit in the given box

sub get_pixbuf_at_scale {
    my ( $self, $max_width, $max_height ) = @_;
    my ( $xresolution, $yresolution ) = $self->get_resolution;
    my ( $width,       $height )      = $self->get_size;
    ( $width, $height ) =
      _prepare_scale( $width, $height, $xresolution / $yresolution,
        $max_width, $max_height );
    my $pixbuf;
    try {
        $pixbuf =
          Gtk3::Gdk::Pixbuf->new_from_file_at_scale( "$self->{filename}",
            $width, $height, FALSE );
    }
    catch {
        $logger->warn("Caught error getting pixbuf: $_");
    };
    return $pixbuf;
}

1;

__END__
