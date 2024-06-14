package Gscan2pdf::Dialog::Save;

use warnings;
use strict;
use feature 'switch';
use Glib 1.220 qw(TRUE FALSE);    # To get TRUE and FALSE
use Gscan2pdf::ComboBoxText;
use Gscan2pdf::Dialog;
use Gscan2pdf::Document;
use Gscan2pdf::EntryCompletion;
use Gscan2pdf::Translation '__';    # easier to extract strings with xgettext
use Date::Calc qw(Today Today_and_Now Add_Delta_DHMS);
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use Encode;
use Readonly;
Readonly my $ENTRY_WIDTH_DATE     => 10;
Readonly my $ENTRY_WIDTH_DATETIME => 19;

our $VERSION = '2.13.2';
my $EMPTY           = q{};
my $DATE_FORMAT     = '%04d-%02d-%02d';
my $DATETIME_FORMAT = '%04d-%02d-%02d %02d:%02d:%02d';
my ( $_100_PERCENT, $MAX_DPI );

# need to register this with Glib before we can use it below
BEGIN {
    use Readonly;
    Readonly $_100_PERCENT => 100;
    Readonly $MAX_DPI      => 2400;
}

use Glib::Object::Subclass Gscan2pdf::Dialog::, properties => [
    Glib::ParamSpec->scalar(
        'meta-datetime',                             # name
        'Array of datetime metadata',                # nick
        'Year, month, day, hour, minute, second',    # blurb
        [qw/readable writable/]                      # flags
    ),
    Glib::ParamSpec->boolean(
        'select-datetime',                                  # name
        'Select datetime',                                  # nickname
        'TRUE = show datetime entry, FALSE = now/today',    # blurb
        FALSE,                                              # default
        [qw/readable writable/]                             # flags
    ),
    Glib::ParamSpec->boolean(
        'include-time',                                     # name
        'Specify the time as well as date',                 # nickname
        'Whether to allow the time, as well as the date, to be entered', # blurb
        FALSE,                     # default
        [qw/readable writable/]    # flags
    ),
    Glib::ParamSpec->string(
        'meta-title',              # name
        'Title metadata',          # nick
        'Title metadata',          # blurb
        $EMPTY,                    # default
        [qw/readable writable/]    # flags
    ),
    Glib::ParamSpec->scalar(
        'meta-title-suggestions',                 # name
        'Array of title metadata suggestions',    # nick
        'Used by entry completion widget',        # blurb
        [qw/readable writable/]                   # flags
    ),
    Glib::ParamSpec->string(
        'meta-author',                            # name
        'Author metadata',                        # nick
        'Author metadata',                        # blurb
        $EMPTY,                                   # default
        [qw/readable writable/]                   # flags
    ),
    Glib::ParamSpec->scalar(
        'meta-author-suggestions',                 # name
        'Array of author metadata suggestions',    # nick
        'Used by entry completion widget',         # blurb
        [qw/readable writable/]                    # flags
    ),
    Glib::ParamSpec->string(
        'meta-subject',                            # name
        'Subject metadata',                        # nick
        'Subject metadata',                        # blurb
        $EMPTY,                                    # default
        [qw/readable writable/]                    # flags
    ),
    Glib::ParamSpec->scalar(
        'meta-subject-suggestions',                 # name
        'Array of subject metadata suggestions',    # nick
        'Used by entry completion widget',          # blurb
        [qw/readable writable/]                     # flags
    ),
    Glib::ParamSpec->string(
        'meta-keywords',                            # name
        'Keyword metadata',                         # nick
        'Keyword metadata',                         # blurb
        $EMPTY,                                     # default
        [qw/readable writable/]                     # flags
    ),
    Glib::ParamSpec->scalar(
        'meta-keywords-suggestions',                # name
        'Array of keyword metadata suggestions',    # nick
        'Used by entry completion widget',          # blurb
        [qw/readable writable/]                     # flags
    ),
    Glib::ParamSpec->scalar(
        'image-types',                                            # name
        'Array of available image types',                         # nick
        'To allow djvu, pdfunite dependencies to be optional',    # blurb
        [qw/readable writable/]                                   # flags
    ),
    Glib::ParamSpec->string(
        'image-type',                                             # name
        'Image type',                                             # nick
        'Currently selected image type',                          # blurb
        'pdf',                                                    # default
        [qw/readable writable/]                                   # flags
    ),
    Glib::ParamSpec->scalar(
        'ps-backends',                                            # name
        'PS backends',                                            # nick
        'Array of available postscript backends',                 # blurb
        [qw/readable writable/]                                   # flags
    ),
    Glib::ParamSpec->string(
        'ps-backend',                                             # name
        'PS backend',                                             # nick
        'Currently selected postscript backend',                  # blurb
        'pdftops',                                                # default
        [qw/readable writable/]                                   # flags
    ),
    Glib::ParamSpec->string(
        'tiff-compression',                                       # name
        'TIFF compression',                                       # nick
        'Currently selected TIFF compression method',             # blurb
        undef,                                                    # default
        [qw/readable writable/]                                   # flags
    ),
    Glib::ParamSpec->float(
        'jpeg-quality',                                      # name
        'JPEG quality',                                      # nick
        'Affects the compression level of JPEG encoding',    # blurb
        1,                                                   # minimum
        $_100_PERCENT,                                       # maximum
        75,                                                  # default_value
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->float(
        'downsample-dpi',                                    # name
        'Downsample DPI',                                    # nick
        'Resolution to use when downsampling',               # blurb
        1,                                                   # minimum
        $MAX_DPI,                                            # maximum
        150,                                                 # default_value
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->boolean(
        'downsample',                                        # name
        'Downsample',                                        # nickname
        'Whether to downsample',                             # blurb
        FALSE,                                               # default
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->string(
        'pdf-compression',                                   # name
        'PDF compression',                                   # nick
        'Currently selected PDF compression method',         # blurb
        'auto',                                              # default
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->scalar(
        'available-fonts',                                   # name
        'Available fonts',                                   # nick
        'Hash of true type fonts available',                 # blurb
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->string(
        'text_position',                                     # name
        'Text position',                                     # nick
        'Where to place the OCR output',                     # blurb
        'behind',                                            # default
        [qw/readable writable/]                              # flags
    ),
    Glib::ParamSpec->string(
        'pdf-font',                                            # name
        'PDF font',                                            # nick
        'Font with which to write hidden OCR layer of PDF',    # blurb
        undef,                                                 # default
        [qw/readable writable/]                                # flags
    ),
    Glib::ParamSpec->boolean(
        'can-encrypt-pdf',                                     # name
        'Can encrypt PDF',                                     # nick
        'Backend is capable of encrypting the PDF',            # blurb
        FALSE,                                                 # default
        [qw/readable writable/]                                # flags
    ),
    Glib::ParamSpec->string(
        'pdf-user-password',                                   # name
        'PDF user password',                                   # nick
        'PDF user password',                                   # blurb
        undef,                                                 # default
        [qw/readable writable/]                                # flags
    ),
];

sub SET_PROPERTY {
    my ( $self, $pspec, $newval ) = @_;
    my $name = $pspec->get_name;
    $self->{$name} = $newval;
    if ( $name eq 'include_time' ) {
        $self->on_toggle_include_time($newval);
    }
    elsif ( $name =~ /^meta_([^_]+)(_suggestions)?$/xsm ) {
        my $key = $1;
        if ( defined $self->{"meta-$key-widget"} ) {
            if ( defined $2 ) {
                $self->{"meta-$key-widget"}->add_to_suggestions($newval);
            }
            else {
                if ( $key eq 'datetime' ) {
                    $newval = $self->datetime2string( @{$newval} );
                }
                $self->{"meta-$key-widget"}->set_text($newval);
            }
        }
    }
    return;
}

sub GET_PROPERTY {
    my ( $self, $pspec ) = @_;
    my $name = $pspec->get_name;
    if ( $name =~ /^meta_([^_]+)(_suggestions)?$/xsm ) {
        my $key = $1;
        if ( defined $self->{"meta-$key-widget"} ) {
            if ( defined $2 ) {
                $self->{$name} = $self->{"meta-$key-widget"}->get_suggestions;
            }
            else {
                $self->{$name} = $self->{"meta-$key-widget"}->get_text;
                if ( $key eq 'datetime' ) {
                    if ( $self->{'meta-now-widget'}->get_active ) {
                        $self->{$name} = [ Today_and_Now() ];
                    }
                    elsif ( defined $self->{$name}
                        and $self->{$name} ne $EMPTY )
                    {
                        $self->{$name} = [
                            Gscan2pdf::Document::text_to_datetime(
                                $self->{$name}, Today()
                            )
                        ];
                    }
                }
                elsif ( $self->{$name} ne $EMPTY ) {
                    $self->{"meta-$key-widget"}
                      ->add_to_suggestions( [ $self->{$name} ] );
                }
            }
        }
    }
    return $self->{$name};
}

sub on_toggle_include_time {
    my ( $self, $newval ) = @_;
    if ( defined $self->{'meta-box-widget'} ) {
        if ($newval) {
            $self->{'meta-now-widget'}->get_child->set_text( __('Now') );
            $self->{'meta-now-widget'}
              ->set_tooltip_text( __('Use current date and time') );
            $self->{'meta-datetime-widget'}
              ->set_max_length($ENTRY_WIDTH_DATETIME);
            $self->{'meta-datetime-widget'}->set_text(
                $self->{'meta-datetime-widget'}->get_text . ' 00:00:00' );
        }
        else {
            $self->{'meta-now-widget'}->get_child->set_text( __('Today') );
            $self->{'meta-now-widget'}
              ->set_tooltip_text( __("Use today's date") );
            $self->{'meta-datetime-widget'}->set_max_length($ENTRY_WIDTH_DATE);
        }
    }
    return;
}

sub add_metadata {
    my ( $self, $defaults ) = @_;
    my $vbox = $self->get_content_area;

    # it needs its own box to be able to hide it if necessary
    $self->{'meta-box-widget'} = Gtk3::HBox->new;
    $vbox->pack_start( $self->{'meta-box-widget'}, FALSE, FALSE, 0 );

    # Frame for metadata
    my $frame = Gtk3::Frame->new( __('Document Metadata') );
    $self->{'meta-box-widget'}->pack_start( $frame, TRUE, TRUE, 0 );
    my $hboxm = Gtk3::VBox->new;
    $hboxm->set_border_width( $self->style_get('content-area-border') );
    $frame->add($hboxm);

    # grid to align widgets
    my $grid = Gtk3::Grid->new;
    my $row  = 0;
    $hboxm->pack_start( $grid, TRUE, TRUE, 0 );

    # Date/time
    my $dtframe = Gtk3::Frame->new( __('Date/Time') );
    $grid->attach( $dtframe, 0, $row++, 2, 1 );
    $dtframe->set_hexpand(TRUE);
    my $vboxdt = Gtk3::VBox->new;
    $vboxdt->set_border_width( $self->style_get('content-area-border') );
    $dtframe->add($vboxdt);

    # the first radio button has to set the group,
    # which is undef for the first button
    # Now button
    $self->{'meta-now-widget'} =
      Gtk3::RadioButton->new_with_label( undef, __('Now') );
    $self->{'meta-now-widget'}
      ->set_tooltip_text( __('Use current date and time') );
    $vboxdt->pack_start( $self->{'meta-now-widget'}, TRUE, TRUE, 0 );

    # Specify button
    my $bspecify_dt =
      Gtk3::RadioButton->new_with_label_from_widget( $self->{'meta-now-widget'},
        __('Specify') );
    $bspecify_dt->set_tooltip_text( __('Specify date and time') );
    $vboxdt->pack_start( $bspecify_dt, TRUE, TRUE, 0 );
    my $hboxe = Gtk3::HBox->new;
    $bspecify_dt->signal_connect(
        clicked => sub {
            if ( $bspecify_dt->get_active ) {
                $hboxe->show;
                $self->set( 'select-datetime', TRUE );
            }
            else {
                $hboxe->hide;
                $self->set( 'select-datetime', FALSE );
            }
        }
    );

    my $datetime = $self->get('meta-datetime');
    $self->{'meta-datetime-widget'} = Gtk3::Entry->new;
    if ( defined $datetime and $datetime ne $EMPTY ) {
        $self->{'meta-datetime-widget'}
          ->set_text( $self->datetime2string( @{$datetime} ) );
    }
    $self->{'meta-datetime-widget'}->set_activates_default(TRUE);
    $self->{'meta-datetime-widget'}->set_tooltip_text( __('Year-Month-Day') );
    $self->{'meta-datetime-widget'}->set_alignment(1.);    # Right justify
    $self->{'meta-datetime-widget'}
      ->signal_connect( 'insert-text' => \&insert_text_handler, $self );
    $self->{'meta-datetime-widget'}->signal_connect(
        'focus-out-event' => sub {
            my $text = $self->{'meta-datetime-widget'}->get_text;
            if ( defined $text ) {
                $self->{'meta-datetime-widget'}->set_text(
                    $self->datetime2string(
                        Gscan2pdf::Document::text_to_datetime($text), Today()
                    )
                );
            }
            return FALSE;
        }
    );
    my $button = Gtk3::Button->new;
    $button->set_image( Gtk3::Image->new_from_stock( 'gtk-edit', 'button' ) );
    $button->signal_connect(
        clicked => sub {
            my $window_date = Gscan2pdf::Dialog->new(
                'transient-for' => $self,
                title           => __('Select Date'),
            );
            my $vbox_date = $window_date->get_content_area;
            $window_date->set_resizable(FALSE);
            my $calendar = Gtk3::Calendar->new;

            # Editing the entry and clicking the edit button bypasses the
            # focus-out-event, so update the date now
            my ( $year, $month, $day, $hour, $min, $sec ) =
              Gscan2pdf::Document::text_to_datetime(
                $self->{'meta-datetime-widget'}->get_text, Today() );

            $calendar->select_day($day);
            $calendar->select_month( $month - 1, $year );
            my $calendar_s;
            $calendar_s = $calendar->signal_connect(
                day_selected => sub {
                    ( $year, $month, $day ) = $calendar->get_date;
                    $month += 1;
                    $self->{'meta-datetime-widget'}->set_text(
                        $self->datetime2string(
                            $year, $month, $day, $hour, $min, $sec
                        )
                    );
                }
            );
            $calendar->signal_connect(
                day_selected_double_click => sub {
                    ( $year, $month, $day ) = $calendar->get_date;
                    $month += 1;
                    $self->{'meta-datetime-widget'}->set_text(
                        $self->datetime2string(
                            $year, $month, $day, $hour, $min, $sec
                        )
                    );
                    $window_date->destroy;
                }
            );
            $vbox_date->pack_start( $calendar, TRUE, TRUE, 0 );

            my $today = Gtk3::Button->new( __('Today') );
            $today->signal_connect(
                clicked => sub {
                    ( $year, $month, $day ) = Today();

                    # block and unblock signal, and update entry manually
                    # to remove possibility of race conditions
                    $calendar->signal_handler_block($calendar_s);
                    $calendar->select_day($day);
                    $calendar->select_month( $month - 1, $year );
                    $calendar->signal_handler_unblock($calendar_s);
                    $self->{'meta-datetime-widget'}->set_text(
                        $self->datetime2string(
                            $year, $month, $day, $hour, $min, $sec
                        )
                    );
                }
            );
            $vbox_date->pack_start( $today, TRUE, TRUE, 0 );

            $window_date->show_all;
        }
    );
    $button->set_tooltip_text( __('Select date with calendar') );
    $vboxdt->pack_start( $hboxe, TRUE, TRUE, 0 );
    $hboxe->pack_end( $button,                         FALSE, FALSE, 0 );
    $hboxe->pack_end( $self->{'meta-datetime-widget'}, FALSE, FALSE, 0 );

    # Don't show these widgets when the window is shown
    $hboxe->set_no_show_all(TRUE);
    $self->{'meta-datetime-widget'}->show;
    $button->show;
    $bspecify_dt->set_active( $self->get('select-datetime') );

    my @label = (
        { title    => __('Title') },
        { author   => __('Author') },
        { subject  => __('Subject') },
        { keywords => __('Keywords') },
    );
    for my $entry (@label) {
        my ( $name, $label ) = %{$entry};
        my $hbox = Gtk3::HBox->new;
        $grid->attach( $hbox, 0, $row, 1, 1 );
        $label = Gtk3::Label->new($label);
        $hbox->pack_start( $label, FALSE, TRUE, 0 );
        $hbox = Gtk3::HBox->new;
        $grid->attach( $hbox, 1, $row++, 1, 1 );
        $self->{"meta-$name-widget"} =
          Gscan2pdf::EntryCompletion->new( $self->get("meta-$name"),
            $self->get("meta-$name-suggestions") );
        $hbox->pack_start( $self->{"meta-$name-widget"}, TRUE, TRUE, 0 );
    }
    $self->on_toggle_include_time( $self->get('include-time') );
    return;
}

# helper function to return correctly formatted date or datetime string
sub datetime2string {
    my ( $self, @datetime ) = @_;
    return $self->get('include-time')
      ? sprintf $DATETIME_FORMAT, @datetime
      : sprintf $DATE_FORMAT, @datetime[ 0 .. 2 ];
}

sub insert_text_handler {
    my ( $widget, $string, $len, $position, $self ) = @_;
    my $text     = $widget->get_text;
    my $text_len = length( $widget->get_text );
    $widget->signal_handlers_block_by_func( \&insert_text_handler );

    # trap + & - for incrementing and decrementing date
    if (
        (
            (
                not $self->get('include-time')
                and $text_len == $ENTRY_WIDTH_DATE
            )
            or

            (
                    $self->get('include-time')
                and $text_len == $ENTRY_WIDTH_DATETIME
            )
        )
        and $string =~ /^[+\-]+$/smx
      )
    {
        my $offset = 1;
        if ( $string eq q{-} ) { $offset = -$offset }
        $widget->set_text(
            $self->datetime2string(
                Add_Delta_DHMS(
                    Gscan2pdf::Document::text_to_datetime( $text, Today() ),
                    $offset, 0, 0, 0
                )
            )
        );
    }

    # only allow integers and -
    elsif (
        ( not $self->get('include-time') and $string =~ /^[\d\-]+$/smx )
        or

        # only allow integers, space, : and -
        ( $self->get('include-time') and $string =~ /^[\d\- :]+$/smx )
      )
    {
        $widget->insert_text( $string, $len, $position++ );
    }
    $widget->signal_handlers_unblock_by_func( \&insert_text_handler );
    $widget->signal_stop_emission_by_name('insert-text');
    return $position;
}

sub add_image_type {
    my ($self) = @_;
    my $vbox = $self->get_content_area;

    # Image type ComboBox
    my $hboxi = Gtk3::HBox->new;
    $vbox->pack_start( $hboxi, FALSE, FALSE, 0 );
    my $label = Gtk3::Label->new( __('Document type') );
    $hboxi->pack_start( $label, FALSE, FALSE, 0 );

    my @image_types = (
        [ 'pdf', __('PDF'), __('Portable Document Format') ],
        [ 'gif', __('GIF'), __('CompuServe graphics interchange format') ],
        [
            'jpg', __('JPEG'),
            __('Joint Photographic Experts Group JFIF format')
        ],
        [ 'png',     __('PNG'),     __('Portable Network Graphics') ],
        [ 'pnm',     __('PNM'),     __('Portable anymap') ],
        [ 'ps',      __('PS'),      __('Postscript') ],
        [ 'tif',     __('TIFF'),    __('Tagged Image File Format') ],
        [ 'txt',     __('Text'),    __('Plain text') ],
        [ 'hocr',    __('hOCR'),    __('hOCR markup language') ],
        [ 'session', __('Session'), __('gscan2pdf session file') ],
        [
            'prependpdf', __('Prepend to PDF'), __('Prepend to an existing PDF')
        ],
        [ 'appendpdf', __('Append to PDF'), __('Append to an existing PDF') ],
        [ 'djvu',      __('DjVu'),          __('Deja Vu') ],
    );
    my @type =
      @{ filter_table( \@image_types, @{ $self->get('image-types') } ) };
    my $combobi = Gscan2pdf::ComboBoxText->new_from_array(@type);
    $hboxi->pack_end( $combobi, FALSE, FALSE, 0 );

    $self->add_metadata;

    # Postscript backend
    my $hboxps = Gtk3::HBox->new;
    $vbox->pack_start( $hboxps, TRUE, TRUE, 0 );
    $label = Gtk3::Label->new( __('Postscript backend') );
    $hboxps->pack_start( $label, FALSE, FALSE, 0 );
    my @backends = (
        [
            'libtiff', __('LibTIFF'),
            __('Use LibTIFF (tiff2ps) to create Postscript files from TIFF.')
        ],
        [
            'pdf2ps',
            __('Ghostscript'),
            __('Use Ghostscript (pdf2ps) to create Postscript files from PDF.')
        ],
        [
            'pdftops', __('Poppler'),
            __('Use Poppler (pdftops) to create Postscript files from PDF.')
        ],
    );
    my @ps_backend =
      @{ filter_table( \@backends, @{ $self->get('ps-backends') } ) };
    my $combops = Gscan2pdf::ComboBoxText->new_from_array(@ps_backend);
    $combops->signal_connect(
        changed => sub {
            my $ps_backend = $combops->get_active_index;
            $self->set( 'ps-backend', $ps_backend );
        }
    );

    # FIXME: this is defaulting to undef, despite the default being defined in
    # the subclassing call
    my $ps_backend = $self->get('ps-backend');
    if ( not defined $ps_backend ) { $ps_backend = 'pdftops' }
    $combops->set_active_index($ps_backend);
    $hboxps->pack_end( $combops, TRUE, TRUE, 0 );

    my @tiff_compression = (
        [
            'lzw', __('LZW'),
            __('Compress output with Lempel-Ziv & Welch encoding.')
        ],
        [ 'zip', __('Zip'), __('Compress output with deflate encoding.') ],

        # jpeg rather than jpg needed here because tiffcp uses -c jpeg
        [ 'jpeg', __('JPEG'), __('Compress output with JPEG encoding.') ],
        [
            'packbits', __('Packbits'),
            __('Compress output with Packbits encoding.')
        ],
        [ 'g3', __('G3'), __('Compress output with CCITT Group 3 encoding.') ],
        [ 'g4', __('G4'), __('Compress output with CCITT Group 4 encoding.') ],
        [ 'none', __('None'), __('Use no compression algorithm on output.') ],
    );

    # Compression ComboBox
    my $hboxc = Gtk3::HBox->new;
    $vbox->pack_start( $hboxc, FALSE, FALSE, 0 );
    $label = Gtk3::Label->new( __('Compression') );
    $hboxc->pack_start( $label, FALSE, FALSE, 0 );

    # Set up quality spinbutton here
    # so that it can be shown or hidden by callback
    my ( $hboxtq, $spinbuttontq ) = $self->add_quality_spinbutton($vbox);

    # Fill compression ComboBox
    my $combobtc = Gscan2pdf::ComboBoxText->new_from_array(@tiff_compression);
    $combobtc->signal_connect(
        changed => sub {
            my $compression = $combobtc->get_active_index;
            $self->set( 'tiff-compression', $compression );
            if ( $compression eq 'jpeg' ) {
                $hboxtq->show;
            }
            else {
                $hboxtq->hide;
                $self->resize( 1, 1 );
            }
        }
    );
    $combobtc->set_active_index( $self->get('tiff-compression') );
    $hboxc->pack_end( $combobtc, FALSE, FALSE, 0 );

    # PDF options
    my ( $vboxp, $hboxpq ) = $self->add_pdf_options;

    $combobi->signal_connect(
        changed => \&image_type_changed_callback,
        [ $self, $vboxp, $hboxpq, $hboxc, $hboxtq, $hboxps, ]
    );
    $self->show_all;
    $hboxc->set_no_show_all(TRUE);
    $hboxtq->set_no_show_all(TRUE);
    $hboxps->set_no_show_all(TRUE);
    $combobi->set_active_index( $self->get('image-type') );
    return;
}

sub image_type_changed_callback {
    my ( $widget, $data ) = @_;
    my ( $self, $vboxp, $hboxpq, $hboxc, $hboxtq, $hboxps, ) = @{$data};
    my $image_type = $widget->get_active_index;
    $self->set( 'image-type', $image_type );
    given ($image_type) {
        when (/pdf/xsm) {
            $vboxp->show;
            $hboxc->hide;
            $hboxtq->hide;
            $hboxps->hide;
            if ( $_ eq 'pdf' ) {
                $self->{'meta-box-widget'}->show;
            }
            else {    # don't show metadata for pre-/append to pdf
                $self->{'meta-box-widget'}->hide;
            }
            if ( $self->get('pdf-compression') eq 'jpg' ) {
                $hboxpq->show;
            }
            else {
                $hboxpq->hide;
            }
        }
        when ('djvu') {
            $self->{'meta-box-widget'}->show;
            $hboxc->hide;
            $vboxp->hide;
            $hboxpq->hide;
            $hboxtq->hide;
            $hboxps->hide;
        }
        when ('tif') {
            $hboxc->show;
            $self->{'meta-box-widget'}->hide;
            $vboxp->hide;
            $hboxpq->hide;
            if ( $self->get('tiff-compression') eq 'jpeg' ) {
                $hboxtq->show;
            }
            else {
                $hboxtq->hide;
            }
            $hboxps->hide;
        }
        when ('ps') {
            $hboxc->hide;
            $self->{'meta-box-widget'}->hide;
            $vboxp->hide;
            $hboxpq->hide;
            $hboxtq->hide;
            $hboxps->show;
        }
        when ('jpg') {
            $self->{'meta-box-widget'}->hide;
            $hboxc->hide;
            $vboxp->hide;
            $hboxpq->hide;
            $hboxtq->show;
            $hboxps->hide;
        }
        default {
            $self->{'meta-box-widget'}->hide;
            $vboxp->hide;
            $hboxc->hide;
            $hboxpq->hide;
            $hboxtq->hide;
            $hboxps->hide;
        }
    }
    $self->resize( 1, 1 );
    return;
}

sub filter_table {
    my ( $table, @filter ) = @_;
    my @sub_table;
    for my $row ( @{$table} ) {
        if ( $row->[0] ~~ @filter ) { push @sub_table, $row }
    }
    return \@sub_table;
}

# Set up quality spinbutton here so that it can be shown or hidden by callback

sub add_quality_spinbutton {
    my ( $self, $vbox ) = @_;
    my $hbox = Gtk3::HBox->new;
    $vbox->pack_start( $hbox, TRUE, TRUE, 0 );
    my $label = Gtk3::Label->new( __('JPEG Quality') );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );
    my $spinbutton = Gtk3::SpinButton->new_with_range( 1, $_100_PERCENT, 1 );
    $spinbutton->set_value( $self->get('jpeg-quality') );
    $hbox->pack_end( $spinbutton, FALSE, FALSE, 0 );
    return $hbox, $spinbutton;
}

sub add_pdf_options {
    my ($self) = @_;

    # pack everything in one vbox to be able to show/hide them all at once
    my $vboxp = Gtk3::VBox->new;
    my $vbox  = $self->get_content_area;
    $vbox->pack_start( $vboxp, FALSE, FALSE, 0 );

    # Downsample options
    my $hboxd = Gtk3::HBox->new;
    $vboxp->pack_start( $hboxd, FALSE, FALSE, 0 );
    my $button = Gtk3::CheckButton->new( __('Downsample to') );
    $hboxd->pack_start( $button, FALSE, FALSE, 0 );
    my $spinbutton = Gtk3::SpinButton->new_with_range( 1, $MAX_DPI, 1 );
    $spinbutton->set_value( $self->get('downsample-dpi') );
    my $label = Gtk3::Label->new( __('PPI') );
    $hboxd->pack_end( $label,      FALSE, FALSE, 0 );
    $hboxd->pack_end( $spinbutton, FALSE, FALSE, 0 );
    $button->signal_connect(
        toggled => sub {
            my $active = $button->get_active;
            $self->set( 'downsample', $active );
            $spinbutton->set_sensitive($active);
        }
    );
    $spinbutton->signal_connect(
        'value-changed' => sub {
            $self->set( 'downsample-dpi', $spinbutton->get_value );
        }
    );
    $spinbutton->set_sensitive( $self->get('downsample') );
    $button->set_active( $self->get('downsample') );

    # Compression options
    my @compression = (
        [
            'auto', __('Automatic'),
            __('Let gscan2pdf which type of compression to use.')
        ],
        [
            'lzw', __('LZW'),
            __('Compress output with Lempel-Ziv & Welch encoding.')
        ],
        [ 'g3',  __('G3'), __('Compress output with CCITT Group 3 encoding.') ],
        [ 'g4',  __('G4'), __('Compress output with CCITT Group 4 encoding.') ],
        [ 'png', __('Flate'), __('Compress output with flate encoding.') ],
        [ 'jpg', __('JPEG'),  __('Compress output with JPEG (DCT) encoding.') ],
        [ 'none', __('None'), __('Use no compression algorithm on output.') ],
    );

    # Compression ComboBox
    my $hbox = Gtk3::HBox->new;
    $vboxp->pack_start( $hbox, TRUE, TRUE, 0 );
    $label = Gtk3::Label->new( __('Compression') );
    $hbox->pack_start( $label, FALSE, FALSE, 0 );

  # Set up quality spinbutton here so that it can be shown or hidden by callback
    my ( $hboxq, $spinbuttonq ) = $self->add_quality_spinbutton($vboxp);

    my $combob = Gscan2pdf::ComboBoxText->new_from_array(@compression);
    $combob->signal_connect(
        changed => sub {
            my $compression = $combob->get_active_index;
            $self->set( 'pdf-compression', $compression );
            if ( $compression eq 'jpg' ) {
                $hboxq->show;
            }
            else {
                $hboxq->hide;
                $self->resize( 1, 1 );
            }
        }
    );
    $spinbuttonq->signal_connect(
        'value-changed' => sub {
            $self->set( 'jpeg-quality', $spinbuttonq->get_value );
        }
    );
    $hbox->pack_end( $combob, FALSE, FALSE, 0 );

    my $hboxt = Gtk3::HBox->new;
    $vboxp->pack_start( $hboxt, TRUE, TRUE, 0 );
    $label = Gtk3::Label->new( __('Position of OCR output') );
    $hboxt->pack_start( $label, FALSE, FALSE, 0 );
    my @positions = (
        [ 'behind', __('Behind'), __('Put OCR output behind image.') ],
        [
            'right', __('Right'),
            __('Put OCR output to the right of the image.')
        ],
    );
    my $combot = Gscan2pdf::ComboBoxText->new_from_array(@positions);
    $combot->signal_connect(
        changed => sub {
            $self->set( 'text_position', $combot->get_active_index );
        }
    );
    $combot->set_active_index( $self->get('text_position') );
    $hboxt->pack_end( $combot, FALSE, FALSE, 0 );

    $self->add_font_button($vboxp);

    if ( $self->get('can-encrypt-pdf') ) {
        my $passb = Gtk3::Button->new( __('Encrypt PDF') );
        $vboxp->pack_start( $passb, TRUE, TRUE, 0 );
        $passb->signal_connect(
            clicked => sub {
                my $passwin = Gscan2pdf::Dialog->new(
                    'transient-for' => $self,
                    title           => __('Set password'),
                );
                $passwin->set_modal(TRUE);
                my $passvbox = $passwin->get_content_area;
                my $grid     = Gtk3::Grid->new;
                my $row      = 0;
                $passvbox->pack_start( $grid, TRUE, TRUE, 0 );

                $hbox  = Gtk3::HBox->new;
                $label = Gtk3::Label->new( __('User password') );
                $hbox->pack_start( $label, FALSE, FALSE, 0 );
                $grid->attach( $hbox, 0, $row, 1, 1 );
                my $userentry = Gtk3::Entry->new;
                if ( defined $self->get('pdf-user-password') ) {
                    $userentry->set_text( $self->get('pdf-user-password') );
                }
                $grid->attach( $userentry, 1, $row++, 1, 1 );
                $passwin->add_actions(
                    'gtk-ok',
                    sub {
                        $self->set( 'pdf-user-password', $userentry->get_text );
                        $passwin->destroy;
                    },
                    'gtk-cancel',
                    sub { $passwin->destroy }
                );
                $passwin->show_all;
            }
        );
    }

    $vboxp->show_all;
    $hboxq->set_no_show_all(TRUE);
    $vboxp->set_no_show_all(TRUE);

    # do this after show all and set_no_show_all
    # to make sure child widgets are shown.
    $combob->set_active_index( $self->get('pdf-compression') );

    return $vboxp, $hboxq;
}

sub add_font_button {
    my ( $self, $vboxp ) = @_;

    # It would be nice to use a Gtk3::FontButton here, but as we can only use
    # TTF, and we have to know the filename of the font, we must filter the
    # list of fonts, and so we must use a Gtk3::FontChooserDialog
    my $hboxf = Gtk3::HBox->new;
    $vboxp->pack_start( $hboxf, TRUE, TRUE, 0 );
    my $label = Gtk3::Label->new( __('Font for non-ASCII text') );
    $hboxf->pack_start( $label, FALSE, FALSE, 0 );
    my $fontb = Gtk3::Button->new('Font name goes here');
    $hboxf->pack_end( $fontb, FALSE, TRUE, 0 );

    my $ttffile = $self->get('pdf-font');
    my $fonts   = $self->get('available-fonts');
    if ( not defined $ttffile or not -e $ttffile ) {
        $ttffile = ( keys %{ $fonts->{by_file} } )[0];
        $self->set( 'pdf-font', $ttffile );
    }
    if (    defined $ttffile
        and defined $fonts
        and defined $fonts->{by_file}{$ttffile} )
    {
        my ( $family, $style ) = @{ $fonts->{by_file}{$ttffile} };
        $fontb->set_label("$family $style");
    }
    else {
        $fontb->set_label( __('Core') );
    }
    $fontb->signal_connect(
        clicked => sub {
            my $fontwin =
              Gtk3::FontChooserDialog->new( 'transient-for' => $self, );
            $fontwin->set_filter_func(
                sub {
                    my ( $family, $face ) = @_;
                    $family = $family->get_name;
                    $face   = $face->get_face_name;
                    if (    defined $fonts->{by_family}{$family}
                        and defined $fonts->{by_family}{$family}{$face} )
                    {
                        return TRUE;
                    }
                    return;
                }
            );
            if (    defined $ttffile
                and defined $fonts
                and defined $fonts->{by_file}{$ttffile} )
            {
                my ( $family, $style ) = @{ $fonts->{by_file}{$ttffile} };
                my $font = $family;
                if ( defined $style and $style ne $EMPTY ) {
                    $font .= " $style";
                }
                $fontwin->set_font($font);
            }
            $fontwin->show_all;
            if ( $fontwin->run eq 'ok' ) {
                my $family = $fontwin->get_font_family->get_name;
                my $face   = $fontwin->get_font_face->get_face_name;
                if (    defined $fonts->{by_family}{$family}
                    and defined $fonts->{by_family}{$family}{$face} )
                {

                    # also set local variable as a sort of cache
                    $ttffile = $fonts->{by_family}{$family}{$face};
                    $self->set( 'pdf-font', $ttffile );
                    $fontb->set_label("$family $face");
                }
            }
            $fontwin->destroy;
        }
    );
    return;
}

1;

__END__
