use v6;

unit module Knot::Dowker:ver<1>:auth<Brian Conry (brian@theconrys.com)>;

subset DowkerStr of Str where * ~~ /^ [ '-'? [ <[2468]> | <[1..9]>+ <[24680]> ] ]+ % ' ' $/;

class Dowker is export {
    has @.numbers;
    has $.notation;

    submethod BUILD( DowkerStr:D :$notation ) {
        my @numbers = $notation.split( ' ' )».Int;

        my $uniq-numbers = |@numbers.Set;

        if $uniq-numbers.elems != @numbers.elems {
            fail "invalid Dowker notation, duplicates ( { $uniq-numbers.elems } vs. { @numbers.elems } )";
        }

        if @numbers.grep( *.abs > 2 * @numbers.elems ) {
            fail "invalid Dowker notation, crossing numbers out of range";
        }

        @!numbers = @numbers;
        $!notation = $notation;
    }
};

