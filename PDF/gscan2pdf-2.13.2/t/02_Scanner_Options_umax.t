use warnings;
use strict;
use Test::More tests => 3;
use Image::Sane ':all';    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/umax';
SKIP: {
    skip 'source tree not available', 2 unless -r $filename;
    my $output  = do { local ( @ARGV, $/ ) = $filename; <> };
    my $options = Gscan2pdf::Scanner::Options->new_from_data($output);
    my @that    = (
        {
            'index' => 0,
        },
        {
            index             => 1,
            title             => 'Scan Mode',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
        {
            name   => 'mode',
            title  => 'Mode',
            index  => 2,
            'desc' =>
              'Selects the scan mode (e.g., lineart, monochrome, or color).',
            'val'           => 'Color',
            'constraint'    => [ 'Lineart', 'Gray', 'Color' ],
            constraint_type => SANE_CONSTRAINT_STRING_LIST,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_STRING,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name   => 'source',
            title  => 'Source',
            index  => 3,
            'desc' => 'Selects the scan source (such as a document-feeder).',
            'val'  => 'Flatbed',
            'constraint'    => ['Flatbed'],
            constraint_type => SANE_CONSTRAINT_STRING_LIST,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_STRING,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => 'resolution',
            title      => 'Resolution',
            index      => 4,
            'desc'     => 'Sets the resolution of the scanned image.',
            'val'      => '100',
            constraint => {
                'min'   => 5,
                'max'   => 300,
                'quant' => 5,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_DPI,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => 'y-resolution',
            title      => 'Y resolution',
            index      => 5,
            'desc'     => 'Sets the vertical resolution of the scanned image.',
            constraint => {
                'min'   => 5,
                'max'   => 600,
                'quant' => 5,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_DPI,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'resolution-bind',
            title           => 'Resolution bind',
            index           => 6,
            'desc'          => 'Use same values for X and Y resolution',
            'val'           => SANE_TRUE,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name            => 'negative',
            title           => 'Negative',
            index           => 7,
            'desc'          => 'Swap black and white',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            index             => 8,
            title             => 'Geometry',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
        {
            name       => SANE_NAME_SCAN_TL_X,
            title      => 'Top-left x',
            index      => 9,
            'desc'     => 'Top-left x position of scan area.',
            'val'      => 0,
            constraint => {
                'min' => 0,
                'max' => 215.9,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => SANE_NAME_SCAN_TL_Y,
            title      => 'Top-left y',
            index      => 10,
            'desc'     => 'Top-left y position of scan area.',
            'val'      => 0,
            constraint => {
                'min' => 0,
                'max' => 297.18,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => SANE_NAME_SCAN_BR_X,
            title      => 'Bottom-right x',
            desc       => 'Bottom-right x position of scan area.',
            index      => 11,
            'val'      => 215.9,
            constraint => {
                'min' => 0,
                'max' => 215.9,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => SANE_NAME_SCAN_BR_Y,
            title      => 'Bottom-right y',
            desc       => 'Bottom-right y position of scan area.',
            index      => 12,
            'val'      => 297.18,
            constraint => {
                'min' => 0,
                'max' => 297.18,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            index             => 13,
            title             => 'Enhancement',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
        {
            name   => 'depth',
            title  => 'Depth',
            index  => 14,
            'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
            'val'           => '8',
            'constraint'    => ['8'],
            constraint_type => SANE_CONSTRAINT_WORD_LIST,
            'unit'          => SANE_UNIT_BIT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name            => 'quality-cal',
            title           => 'Quality cal',
            index           => 15,
            'desc'          => 'Do a quality white-calibration',
            'val'           => SANE_TRUE,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name            => 'double-res',
            title           => 'Double res',
            index           => 16,
            'desc'          => 'Use lens that doubles optical resolution',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'warmup',
            title           => 'Warmup',
            index           => 17,
            'desc'          => 'Warmup lamp before scanning',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'rgb-bind',
            title           => 'Rgb bind',
            index           => 18,
            'desc'          => 'In RGB-mode use same values for each color',
            'val'           => SANE_FALSE,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => 'brightness',
            title      => 'Brightness',
            index      => 19,
            'desc'     => 'Controls the brightness of the acquired image.',
            constraint => {
                'min'   => -100,
                'max'   => 100,
                'quant' => 1,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'contrast',
            title      => 'Contrast',
            index      => 20,
            'desc'     => 'Controls the contrast of the acquired image.',
            constraint => {
                'min'   => -100,
                'max'   => 100,
                'quant' => 1,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'threshold',
            title      => 'Threshold',
            index      => 21,
            'desc'     => 'Select minimum-brightness to get a white point',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'highlight',
            title  => 'Highlight',
            index  => 22,
            'desc' =>
              'Selects what radiance level should be considered "white".',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'highlight-r',
            title  => 'Highlight r',
            index  => 23,
            'desc' =>
'Selects what red radiance level should be considered "full red".',
            'val'      => '100',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name   => 'highlight-g',
            title  => 'Highlight g',
            index  => 24,
            'desc' =>
'Selects what green radiance level should be considered "full green".',
            'val'      => '100',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name   => 'highlight-b',
            title  => 'Highlight b',
            index  => 25,
            'desc' =>
'Selects what blue radiance level should be considered "full blue".',
            'val'      => '100',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name   => 'shadow',
            title  => 'Shadow',
            index  => 26,
            'desc' =>
              'Selects what radiance level should be considered "black".',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'shadow-r',
            title  => 'Shadow r',
            index  => 27,
            'desc' =>
              'Selects what red radiance level should be considered "black".',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'shadow-g',
            title  => 'Shadow g',
            index  => 28,
            'desc' =>
              'Selects what green radiance level should be considered "black".',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'shadow-b',
            title  => 'Shadow b',
            index  => 29,
            'desc' =>
              'Selects what blue radiance level should be considered "black".',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'analog-gamma',
            title      => 'Analog gamma',
            index      => 30,
            'desc'     => 'Analog gamma-correction',
            constraint => {
                'min'   => 1,
                'max'   => 2,
                'quant' => 0.00999451,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'analog-gamma-r',
            title      => 'Analog gamma r',
            index      => 31,
            'desc'     => 'Analog gamma-correction for red',
            constraint => {
                'min'   => 1,
                'max'   => 2,
                'quant' => 0.00999451,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'analog-gamma-g',
            title      => 'Analog gamma g',
            index      => 32,
            'desc'     => 'Analog gamma-correction for green',
            constraint => {
                'min'   => 1,
                'max'   => 2,
                'quant' => 0.00999451,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'analog-gamma-b',
            title      => 'Analog gamma b',
            index      => 33,
            'desc'     => 'Analog gamma-correction for blue',
            constraint => {
                'min'   => 1,
                'max'   => 2,
                'quant' => 0.00999451,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'custom-gamma',
            title  => 'Custom gamma',
            index  => 34,
            'desc' =>
'Determines whether a builtin or a custom gamma-table should be used.',
            'val'           => SANE_TRUE,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
        {
            name       => 'gamma-table',
            title      => 'Gamma table',
            index      => 35,
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 255,
        },
        {
            name       => 'red-gamma-table',
            title      => 'Red gamma table',
            index      => 36,
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'desc'          => 'Gamma-correction table for the red band.',
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 255,
        },
        {
            name       => 'green-gamma-table',
            title      => 'Green gamma table',
            index      => 37,
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'desc'          => 'Gamma-correction table for the green band.',
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 255,
        },
        {
            name       => 'blue-gamma-table',
            title      => 'Blue gamma table',
            index      => 38,
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'desc'          => 'Gamma-correction table for the blue band.',
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 255,
        },
        {
            name   => 'halftone-size',
            title  => 'Halftone size',
            index  => 39,
            'desc' =>
'Sets the size of the halftoning (dithering) pattern used when scanning halftoned images.',
            'constraint'    => [ '2', '4', '6', '8', '12' ],
            constraint_type => SANE_CONSTRAINT_WORD_LIST,
            'unit'          => SANE_UNIT_PIXEL,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'halftone-pattern',
            title  => 'Halftone pattern',
            index  => 40,
            'desc' =>
'Defines the halftoning (dithering) pattern for scanning halftoned images.',
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            index             => 41,
            title             => 'Advanced',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
        {
            name       => 'cal-exposure-time',
            title      => 'Cal exposure time',
            index      => 42,
            'desc'     => 'Define exposure-time for calibration',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'cal-exposure-time-r',
            title      => 'Cal exposure time r',
            index      => 43,
            'desc'     => 'Define exposure-time for red calibration',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'cal-exposure-time-g',
            title      => 'Cal exposure time g',
            index      => 44,
            'desc'     => 'Define exposure-time for green calibration',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'cal-exposure-time-b',
            title      => 'Cal exposure time b',
            index      => 45,
            'desc'     => 'Define exposure-time for blue calibration',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'scan-exposure-time',
            title      => 'Scan exposure time',
            index      => 46,
            'desc'     => 'Define exposure-time for scan',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'scan-exposure-time-r',
            title      => 'Scan exposure time r',
            index      => 47,
            'desc'     => 'Define exposure-time for red scan',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'scan-exposure-time-g',
            title      => 'Scan exposure time g',
            index      => 48,
            'desc'     => 'Define exposure-time for green scan',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'scan-exposure-time-b',
            title      => 'Scan exposure time b',
            index      => 49,
            'desc'     => 'Define exposure-time for blue scan',
            constraint => {
                'min' => 0,
                'max' => 0,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MICROSECOND,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'disable-pre-focus',
            title           => 'Disable pre focus',
            index           => 50,
            'desc'          => 'Do not calibrate focus',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'manual-pre-focus',
            title           => 'Manual pre focus',
            index           => 51,
            'desc'          => '',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'fix-focus-position',
            title           => 'Fix focus position',
            index           => 52,
            'desc'          => '',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'lens-calibration-in-doc-position',
            title           => 'Lens calibration in doc position',
            index           => 53,
            'desc'          => 'Calibrate lens focus in document position',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'holder-focus-position-0mm',
            title           => 'Holder focus position 0mm',
            index           => 54,
            'desc'          => 'Use 0mm holder focus position instead of 0.6mm',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'cal-lamp-density',
            title      => 'Cal lamp density',
            index      => 55,
            'desc'     => 'Define lamp density for calibration',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'scan-lamp-density',
            title      => 'Scan lamp density',
            index      => 56,
            'desc'     => 'Define lamp density for scan',
            constraint => {
                'min' => 0,
                'max' => 100,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_PERCENT,
            type            => SANE_TYPE_INT,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'select-exposure-time',
            title           => 'Select exposure time',
            index           => 57,
            'desc'          => 'Enable selection of exposure-time',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name   => 'select-calibration-exposure-time',
            title  => 'Select calibration exposure time',
            index  => 58,
            'desc' =>
'Allow different settings for calibration and scan exposure times',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'select-lamp-density',
            title           => 'Select lamp density',
            index           => 59,
            'desc'          => 'Enable selection of lamp density',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BOOL,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'lamp-on',
            title           => 'Lamp on',
            index           => 60,
            'desc'          => 'Turn on scanner lamp',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BUTTON,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 0,
        },
        {
            name            => 'lamp-off',
            title           => 'Lamp off',
            index           => 61,
            'desc'          => 'Turn off scanner lamp',
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            type            => SANE_TYPE_BUTTON,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 0,
        },
        {
            name            => 'lamp-off-at-exit',
            title           => 'Lamp off at exit',
            index           => 62,
            'desc'          => 'Turn off lamp when program exits',
            type            => SANE_TYPE_BOOL,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'batch-scan-start',
            title           => 'Batch scan start',
            index           => 63,
            'desc'          => 'set for first scan of batch',
            type            => SANE_TYPE_BOOL,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'batch-scan-loop',
            title           => 'Batch scan loop',
            index           => 64,
            'desc'          => 'set for middle scans of batch',
            type            => SANE_TYPE_BOOL,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'batch-scan-end',
            title           => 'Batch scan end',
            index           => 65,
            'desc'          => 'set for last scan of batch',
            type            => SANE_TYPE_BOOL,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name       => 'batch-scan-next-tl-y',
            title      => 'Batch scan next tl y',
            index      => 66,
            'desc'     => 'Set top left Y position for next scan',
            constraint => {
                'min' => 0,
                'max' => 297.18,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_FIXED,
            cap             => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            max_values => 1,
        },
        {
            name            => 'preview',
            title           => 'Preview',
            index           => 67,
            'desc'          => 'Request a preview-quality scan.',
            'val'           => SANE_FALSE,
            type            => SANE_TYPE_BOOL,
            constraint_type => SANE_CONSTRAINT_NONE,
            'unit'          => SANE_UNIT_NONE,
            cap             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            max_values      => 1,
        },
    );
    is_deeply( $options->{array}, \@that, 'umax' );
    is( Gscan2pdf::Scanner::Options->device, 'umax:/dev/sg2', 'device name' );
}
