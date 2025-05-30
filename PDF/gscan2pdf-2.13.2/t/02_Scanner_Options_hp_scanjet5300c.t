use warnings;
use strict;
use Test::More tests => 3;
use Image::Sane ':all';    # For enums
BEGIN { use_ok('Gscan2pdf::Scanner::Options') }

#########################

my $filename = 'scanners/hp_scanjet5300c';
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
            title             => 'Scan mode',
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
            'val'        => 'Color',
            'constraint' => [
                'Lineart', 'Dithered', 'Gray', '12bit Gray',
                'Color',   '12bit Color'
            ],
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_STRING_LIST,
            type            => SANE_TYPE_STRING,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'resolution',
            title      => 'Resolution',
            index      => 3,
            'desc'     => 'Sets the resolution of the scanned image.',
            'val'      => '150',
            constraint => {
                'min'   => 100,
                'max'   => 1200,
                'quant' => 5,
            },
            'unit'          => SANE_UNIT_DPI,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => 'speed',
            title      => 'Speed',
            index      => 4,
            'desc'     => 'Determines the speed at which the scan proceeds.',
            'val'      => '0',
            constraint => {
                'min'   => 0,
                'max'   => 4,
                'quant' => 1,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name              => 'preview',
            title             => 'Preview',
            index             => 5,
            'desc'            => 'Request a preview-quality scan.',
            'val'             => SANE_FALSE,
            'unit'            => SANE_UNIT_NONE,
            'type'            => SANE_TYPE_BOOL,
            'constraint_type' => SANE_CONSTRAINT_NONE,
            'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'      => 1,
        },
        {
            name   => 'source',
            title  => 'Source',
            index  => 6,
            'desc' => 'Selects the scan source (such as a document-feeder).',
            'val'  => 'Normal',
            'constraint'    => [ 'Normal', 'ADF' ],
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_STRING_LIST,
            type            => SANE_TYPE_STRING,
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
                'max' => 216,
            },
            'unit'          => SANE_UNIT_MM,
            constraint_type => SANE_CONSTRAINT_RANGE,
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
                'max' => 296,
            },
            'unit'          => SANE_UNIT_MM,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => SANE_NAME_SCAN_BR_X,
            title      => 'Bottom-right x',
            desc       => 'Bottom-right x position of scan area.',
            index      => 10,
            'val'      => 216,
            constraint => {
                'min' => 0,
                'max' => 216,
            },
            'unit'          => SANE_UNIT_MM,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name       => SANE_NAME_SCAN_BR_Y,
            title      => 'Bottom-right y',
            desc       => 'Bottom-right y position of scan area.',
            index      => 11,
            'val'      => 296,
            constraint => {
                'min' => 0,
                'max' => 296,
            },
            'unit'          => SANE_UNIT_MM,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
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
            name   => 'quality-scan',
            title  => 'Quality scan',
            index  => 15,
            'desc' => 'Turn on quality scanning (slower but better).',
            'val'  => SANE_TRUE,
            'unit' => SANE_UNIT_NONE,
            'type' => SANE_TYPE_BOOL,
            'constraint_type' => SANE_CONSTRAINT_NONE,
            'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'      => 1,
        },
        {
            name              => 'quality-cal',
            title             => 'Quality cal',
            index             => 16,
            'desc'            => 'Do a quality white-calibration',
            'val'             => SANE_TRUE,
            'unit'            => SANE_UNIT_NONE,
            'type'            => SANE_TYPE_BOOL,
            'constraint_type' => SANE_CONSTRAINT_NONE,
            'cap'             => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'      => 1,
        },
        {
            name   => 'gamma-table',
            title  => 'Gamma table',
            index  => 17,
            'desc' =>
'Gamma-correction table.  In color mode this option equally affects the red, green, and blue channels simultaneously (i.e., it is an intensity gamma table).',
            constraint => {
                'min' => 0,
                'max' => 255,
            },
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_RANGE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 255,
        },
        {
            name       => 'red-gamma-table',
            title      => 'Red gamma table',
            index      => 18,
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
            index      => 19,
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
            index      => 20,
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
            name       => 'frame',
            title      => 'Frame',
            index      => 21,
            'desc'     => 'Selects the number of the frame to scan',
            constraint => {
                'min' => 0,
                'max' => 0,
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
            name   => 'power-save-time',
            title  => 'Power save time',
            index  => 22,
            'desc' =>
'Allows control of the scanner\'s power save timer, dimming or turning off the light.',
            'val'           => '65535',
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_INT,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
        {
            name   => 'nvram-values',
            title  => 'Nvram values',
            index  => 23,
            'desc' =>
'Allows access obtaining the scanner\'s NVRAM values as pretty printed text.',
            'val' =>
"Vendor: HP      \nModel: ScanJet 5300C   \nFirmware: 4.00\nSerial: 3119ME\nManufacturing date: 0-0-0\nFirst scan date: 65535-0-0\nFlatbed scans: 65547\nPad scans: -65536\nADF simplex scans: 136183808",
            'unit'          => SANE_UNIT_NONE,
            constraint_type => SANE_CONSTRAINT_NONE,
            type            => SANE_TYPE_STRING,
            'cap'           => SANE_CAP_SOFT_DETECT + SANE_CAP_SOFT_SELECT,
            'max_values'    => 1,
        },
    );
    is_deeply( $options->{array}, \@that, 'hp_scanjet5300c' );
    is( Gscan2pdf::Scanner::Options->device,
        'avision:libusb:001:005', 'device name' );
}
