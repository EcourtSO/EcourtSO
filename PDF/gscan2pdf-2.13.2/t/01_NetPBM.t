use warnings;
use strict;
use IPC::System::Simple qw(system);
use Test::More tests => 14;

BEGIN {
    use_ok('Gscan2pdf::NetPBM');
}

#########################

for my $type (qw(pbm pgm ppm)) {
    for my $depth ( ( 8, 16 ) ) {
        for my $size ( ( "8x5", "9x6" ) ) {
            my ( $width, $height );
            if ( $size =~ /(\d)x(\d)/ ) {
                ( $width, $height ) = ( $1, $2 );
            }
            my $file = "test.$type";
            system( qw(convert -depth),
                $depth, '-resize', $size, 'rose:', $file );
            is_deeply [ Gscan2pdf::NetPBM::file_size_from_header($file) ],
              [ -s $file, $width, $height ],
              "get_size_from_PNM $type $size depth $depth";
            unlink $file;
        }
    }
}

#########################

my $file = 'test.pnm';
system( 'touch', $file );
is_deeply [ Gscan2pdf::NetPBM::file_size_from_header($file) ], [ -s $file ],
  "0-length PNM";
unlink $file;

#########################

__END__
