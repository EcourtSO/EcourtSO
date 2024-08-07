use warnings;
use strict;
use Test::More tests => 3;
use Image::Sane ':all';    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/canonLiDE25';
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
            type              => SANE_TYPE_GROUP,
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
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_STRING_LIST,
            type            => SANE_TYPE_STRING,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name   => 'depth',
            title  => 'Depth',
            index  => 3,
            'desc' =>
'Number of bits per sample, typical values are 1 for "line-art" and 8 for multibit scans.',
            'val'           => '8',
            'constraint'    => [ '8', '16' ],
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_WORD_LIST,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name   => 'source',
            title  => 'Source',
            index  => 4,
            'desc' => 'Selects the scan source (such as a document-feeder).',
            'constraint'    => [ 'Normal', 'Transparency', 'Negative' ],
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_STRING_LIST,
            type            => SANE_TYPE_STRING,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 1,
        },
        {
            name       => 'resolution',
            title      => 'Resolution',
            index      => 5,
            'desc'     => 'Sets the resolution of the scanned image.',
            'val'      => '50',
            constraint => {
                'min' => 50,
                'max' => 2400,
            },
            'unit'          => SANE_UNIT_DPI,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name            => 'preview',
            title           => 'Preview',
            index           => 6,
            'desc'          => 'Request a preview-quality scan.',
            'val'           => SANE_FALSE,
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BOOL,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            index             => 7,
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
            index      => 8,
            'desc'     => 'Top-left x position of scan area.',
            'val'      => 0,
            constraint => {
                'min' => 0,
                'max' => 215,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => SANE_NAME_SCAN_TL_Y,
            title      => 'Top-left y',
            index      => 9,
            'desc'     => 'Top-left y position of scan area.',
            'val'      => 0,
            constraint => {
                'min' => 0,
                'max' => 297,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => SANE_NAME_SCAN_BR_X,
            title      => 'Bottom-right x',
            desc       => 'Bottom-right x position of scan area.',
            index      => 10,
            'val'      => 103,
            constraint => {
                'min' => 0,
                'max' => 215,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => SANE_NAME_SCAN_BR_Y,
            title      => 'Bottom-right y',
            desc       => 'Bottom-right y position of scan area.',
            index      => 11,
            'val'      => 76.21,
            constraint => {
                'min' => 0,
                'max' => 297,
            },
            constraint_type => SANE_CONSTRAINT_RANGE,
            'unit'          => SANE_UNIT_MM,
            type            => SANE_TYPE_FIXED,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            index             => 12,
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
            name       => 'brightness',
            title      => 'Brightness',
            index      => 13,
            'desc'     => 'Controls the brightness of the acquired image.',
            'val'      => '0',
            constraint => {
                'min'   => -100,
                'max'   => 100,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_PERCENT,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'contrast',
            title      => 'Contrast',
            index      => 14,
            'desc'     => 'Controls the contrast of the acquired image.',
            'val'      => '0',
            constraint => {
                'min'   => -100,
                'max'   => 100,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_PERCENT,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name   => 'custom-gamma',
            title  => 'Custom gamma',
            index  => 15,
            'desc' =>
'Determines whether a builtin or a custom gamma-table should be used.',
            'val'           => SANE_FALSE,
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BOOL,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name   => 'gamma-table',
            title  => 'Gamma table',
            index  => 16,
            'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 255,
        },
        {
            name       => 'red-gamma-table',
            title      => 'Red gamma table',
            index      => 17,
            'desc'     => 'Gamma-correction table for the red band.',
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 255,
        },
        {
            name       => 'green-gamma-table',
            title      => 'Green gamma table',
            index      => 18,
            'desc'     => 'Gamma-correction table for the green band.',
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 255,
        },
        {
            name       => 'blue-gamma-table',
            title      => 'Blue gamma table',
            index      => 19,
            'desc'     => 'Gamma-correction table for the blue band.',
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 255,
        },
        {
            index             => 20,
            title             => 'Device-Settings',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
        {
            name            => 'lamp-switch',
            title           => 'Lamp switch',
            index           => 21,
            'desc'          => 'Manually switching the lamp(s).',
            'val'           => SANE_FALSE,
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BOOL,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'lampoff-time',
            title      => 'Lampoff time',
            index      => 22,
            'desc'     => 'Lampoff-time in seconds.',
            'val'      => '300',
            constraint => {
                'min'   => 0,
                'max'   => 999,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name            => 'lamp-off-at-exit',
            title           => 'Lamp off at exit',
            index           => 23,
            'desc'          => 'Turn off lamp when program exits',
            'val'           => SANE_TRUE,
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BOOL,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'warmup-time',
            title      => 'Warmup time',
            index      => 24,
            'desc'     => 'Warmup-time in seconds.',
            constraint => {
                'min'   => -1,
                'max'   => 999,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 1,
        },
        {
            name            => 'calibration-cache',
            title           => 'Calibration cache',
            index           => 25,
            'desc'          => 'Enables or disables calibration data cache.',
            'val'           => SANE_FALSE,
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BOOL,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name   => 'speedup-switch',
            title  => 'Speedup switch',
            index  => 26,
            'desc' => 'Enables or disables speeding up sensor movement.',
            'unit' => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BOOL,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 1,
        },
        {
            name            => 'calibrate',
            title           => 'Calibrate',
            index           => 27,
            'desc'          => 'Performs calibration',
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_BUTTON,
            'cap'           => SANE_CAP_SOFT_DETECT +
              SANE_CAP_SOFT_SELECT +
              SANE_CAP_INACTIVE,
            'max_values' => 0,
        },
        {
            index             => 28,
            title             => 'Analog frontend',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
        {
            name       => 'red-gain',
            title      => 'Red gain',
            index      => 29,
            'desc'     => 'Red gain value of the AFE',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 63,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'green-gain',
            title      => 'Green gain',
            index      => 30,
            'desc'     => 'Green gain value of the AFE',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 63,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'blue-gain',
            title      => 'Blue gain',
            index      => 31,
            'desc'     => 'Blue gain value of the AFE',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 63,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'red-offset',
            title      => 'Red offset',
            index      => 32,
            'desc'     => 'Red offset value of the AFE',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 63,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'green-offset',
            title      => 'Green offset',
            index      => 33,
            'desc'     => 'Green offset value of the AFE',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 63,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'blue-offset',
            title      => 'Blue offset',
            index      => 34,
            'desc'     => 'Blue offset value of the AFE',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 63,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'redlamp-off',
            title      => 'Redlamp off',
            index      => 35,
            'desc'     => 'Defines red lamp off parameter',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 16363,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'greenlamp-off',
            title      => 'Greenlamp off',
            index      => 36,
            'desc'     => 'Defines green lamp off parameter',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 16363,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'bluelamp-off',
            title      => 'Bluelamp off',
            index      => 37,
            'desc'     => 'Defines blue lamp off parameter',
            'val'      => '-1',
            constraint => {
                'min'   => -1,
                'max'   => 16363,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            index             => 38,
            title             => 'Buttons',
            'cap'             => 0,
            'max_values'      => 0,
            'name'            => '',
            'unit'            => SANE_UNIT_NONE,
            'desc'            => '',
            type              => SANE_TYPE_GROUP,
            'constraint_type' => SANE_CONSTRAINT_NONE
        },
    );
    is_deeply( $options->{array}, \@that, 'canonLiDE25' );
    is( Gscan2pdf::Scanner::Options->device,
        'plustek:libusb:001:002', 'device name' );
}
