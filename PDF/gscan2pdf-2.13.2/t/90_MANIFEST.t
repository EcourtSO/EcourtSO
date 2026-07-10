use strict;
use warnings;
use Test::More;
use IPC::System::Simple qw(capture);

my $git;
if (
    -d '.git'
    and eval {
        $git = capture("git ls-tree --name-status -r HEAD | egrep -v '^\.git'");
    }
  )
{
    plan( tests => 1 );
}
else {
    my $msg = 'Need the git repository to compare the MANIFEST.';
    plan( skip_all => $msg );
}

my $manifest = capture(qw(cat MANIFEST));

is( $git, $manifest, 'MANIFEST up to date' );
