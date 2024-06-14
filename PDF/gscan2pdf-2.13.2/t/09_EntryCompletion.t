use warnings;
use strict;
use Test::More tests => 4;

BEGIN {
    use Gtk3 -init;
    use_ok('Gscan2pdf::EntryCompletion');
}

#########################

my @list  = qw(one two three);
my $entry = Gscan2pdf::EntryCompletion->new;
$entry->add_to_suggestions( \@list );
is_deeply( $entry->get_suggestions, \@list, 'get_suggestions' );

#########################

$entry->add_to_suggestions( ['four'] );
my @example = qw(one two three four);
is_deeply( $entry->get_suggestions, \@example, 'updated suggestions' );

#########################

$entry->add_to_suggestions( ['two'] );
is_deeply( $entry->get_suggestions, \@example,
    'ignored duplicates in suggestions' );

#########################

__END__
