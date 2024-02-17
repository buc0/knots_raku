use v6;

unit module PlottingGrid::Malleable:ver<2>:auth<Brian Conry (brian@theconrys.com)>;

# this is a draft for implementing a malleable plotting grid,
# where by "plotting grid" I mean:
#   a square grid, with lines at unit intervals
#   a plotting head that moves only along the lines from intersection to intersection
#   the plotting head leaves a marked trail behind it and knows its current direction of motion
#   noted points may be made at the intersection of two lines
# and by malleable" I mean that it's possible to insert or remove rows or columns in the grid,
#   insertion has the restriction that the insertion happens logically between the lines of the grid,
#       this allows the existing plot to be unambiguously stretched preserving its mathmatical topology
#       automatic expansion at the edges, shifting everything as necessary to keep the lowest corner at (0,0)
#   there is a method, de-encroach, that automatically inserts rows/columns into the grid to ensure
#       that there is an empty row/column on the grid between parrallel plotted lines

# plotting uses Unicode box drawing glyphs by default

# noted points use glyphs supplied by the caller, with optional annotations

# the intended initial use for this plotting grid additionally requires that it be clonable

# TODO
#    add support for coloring marks and annotations in a way that doesn't count against the .chars

# headings have to be absolute (the only relative heading is "ahead", since we don't also have a separate Facing)
enum Heading is export <ph-pos-x ph-pos-y ph-neg-x ph-neg-y>;

# directions could be absolute, but we have chosen to make them relative to an existing Heading
enum Direction is export <pd-left pd-ahead pd-right pd-back>;

subset Coordinate of Capture where * ~~ :( Int:D :$x, Int:D :$y );

my %turnChart = (
    ph-pos-x => {
        pd-left => ph-pos-y,
        pd-ahead => ph-pos-x,
        pd-right => ph-neg-y,
        pd-back => ph-neg-x,
    },
    ph-pos-y => {
        pd-left => ph-neg-x,
        pd-ahead => ph-pos-y,
        pd-right => ph-pos-x,
        pd-back => ph-neg-y,
    },
    ph-neg-x => {
        pd-left => ph-neg-y,
        pd-ahead => ph-neg-x,
        pd-right => ph-pos-y,
        pd-back => ph-pos-x,
    },
    ph-neg-y => {
        pd-left => ph-pos-x,
        pd-ahead => ph-neg-y,
        pd-right => ph-neg-x,
        pd-back => ph-pos-y,
    },
);

my %movementChart = (
    ph-pos-x => {
        Δx =>  1,
        Δy =>  0,
    },
    ph-neg-x => {
        Δx => -1,
        Δy =>  0,
    },
    ph-pos-y => {
        Δx =>  0,
        Δy =>  1,
    },
    ph-neg-y => {
        Δx =>  0,
        Δy => -1,
    },
);

# organized as:
#   ph-pos-y (top)
#     ph-neg-x (left)
#       ph-pos-x (right)
#         ph-neg-y (down)
# true/false for each
my %lineGlyphs = (
    empty => ' ',
    False => {
        False => {
            False => {
                False => '·',
                True  => '╷',
            },
            True => {
                False => '╶',
                True  => '┌',
            },
        },
        True => {
            False => {
                False => '╴',
                True  => '┐',
            },
            True => {
                False => '─',
                True  => '┬',
            },
        }
    },
    True => {
        False => {
            False => {
                False => '╵',
                True  => '│',
            },
            True => {
                False => '└',
                True  => '├',
            },
        },
        True => {
            False => {
                False => '┘',
                True  => '┤',
            },
            True => {
                False => '┴',
                True  => '┼',
            },
        },
    },
);

enum LineOrientation <lo-horizontal lo-vertical>;

class Line { ... };

# these points are intended to be ends for at most four lines,
# one heading in each cardinal direction
class Point {
    has Int $.x is rw;
    has Int $.y is rw;

    has Line %.lines is rw;

    has %.notes is rw;
};

# it is an error for the negative and postive ends to differ in both their x and their y,
# or for the points to demarcate a line that isn't the specified orientation
# neither of these are currently enforced
# a line's location is implied by its points
# a line can't change its points, but it's points can change their (x,y)
# - as long as they both change and don't violate the rules
# has a minimum length of 1 unit
# - also not enforced
class Line {
    has LineOrientation $.orientation;

    has Point $.neg is rw;
    has Point $.pos is rw;
};


# plot() makes a point at the current head (x,y), if there isn't one already
#   + this may break up an existing line if the head is over the middle of a linee
#   + if we have been plotting while advancing this will end the current line
# advance( plotting == False )
#   + if we have been plotting while advancing this will terminate the current
#     line, if any, before moving
# advance( plotting == True )
#   + if there is a current line
#     + if we have been plotting and are now going a different direction
#       + terminate the current line, register the line and point
#       + start a new line
#     + if the advancement intersects an already-existing line, a new point is created, which
#       is then treated as an 'already-existing point" in the next test
#     + if the advancement reaches an already-exisitng point the current line is terminated there
#       + the point used to track the progress of the line is discarded
#   + if there is not a current line, this will start one, creating a point for
#     the origin if necessary
# turn()
#   + turning doesn't affeect lines, it takes movement after the turn
# seek()
#   + if plotting, terminates the current line and stops plotting

class Grid is export {
    # key is "x,y"
    has Point %!points;
    # key is "x,y1,y2"
    has Line %!vlines;
    # key is "y,x1,x2"
    has Line %!hlines;

    has %!vline-lookup;
    has %!hline-lookup;

    # key is the annotation itself,
    # value is how many times it's present
    has %!annotation-catalog;

    # track the current location and heading of the plotting head
    has Int $!head-x;
    has Int $!head-y;
    has Heading $!heading;

    # if plotting, a change of direction requires action
    # we track it here so that we can defer stopping a line
    # if the direction is changed and then changed back before moving
    has Heading $!entered-going;
    has Line $!current-line;
    # $!head-point is one end of $!current-line
    # it is not stored in %!points as it is temporary until the line is terminated
    # if there isn't a $!current-line then there isn't a $!head-point either
    # the x,y of this point will change as the line is extended
    # the x,y of this point should never match the x,y of a point in %!points
    has Point $!head-point;

    # new object from scratch
    submethod BUILD() {
        $!head-x = 0;
        $!head-y = 0;
        $!heading = ph-pos-x;
    };

    method !rebuild-privates( Point %points is copy, %annotation-catalog is copy, --> Nil ) {
        # a shallow copy of this is fine, but we need fresh storage
        %!annotation-catalog := %annotation-catalog;

        # clear all of the shallow copies to rebuild from scratch
        %!points := Hash[Point].new;
        %!hlines := Hash[Line].new;
        %!vlines := Hash[Line].new;
        %!hline-lookup := Hash.new;
        %!vline-lookup := Hash.new;

        # make copies of all the points and hash them
        for %points.values -> $old-point {
            my $new-point = Point.new( x => $old-point.x, y => $old-point.y );

            # we don't care what's in here, we're only doing a shallow copy
            $new-point.notes = $old-point.notes;

            %!points{ make-point-key( $new-point ) } = $new-point;
        }

        # then walk the points again
        for %points.values -> $old-point {
            # for each point you clone the lines leaving it in a pos direction
            if $old-point.lines{ ph-pos-x }:exists {
                my $old-line = $old-point.lines{ ph-pos-x };

                my $new-neg-point = %!points{ make-point-key( $old-line.neg ) };
                my $new-pos-point = %!points{ make-point-key( $old-line.pos ) };

                my $new-line = Line.new( orientation => $old-line.orientation, neg => $new-neg-point, pos => $new-pos-point );

                $new-neg-point.lines{ ph-pos-x } = $new-line;
                $new-pos-point.lines{ ph-neg-x } = $new-line;

                self!add-hline( hline => $new-line );
            }

            if $old-point.lines{ ph-pos-y }:exists {
                my $old-line = $old-point.lines{ ph-pos-y };

                my $new-neg-point = %!points{ make-point-key( $old-line.neg ) };
                my $new-pos-point = %!points{ make-point-key( $old-line.pos ) };

                my $new-line = Line.new( orientation => $old-line.orientation, neg => $new-neg-point, pos => $new-pos-point );

                $new-neg-point.lines{ ph-pos-y } = $new-line;
                $new-pos-point.lines{ ph-neg-y } = $new-line;

                self!add-vline( vline => $new-line );
            }
        }
    };

    method clone(--> Grid) {
        # cloning fails if $!current-line or $!head-point
        fail "cannot clone while plotting" if $!head-point or $!current-line;

        my $clone = callsame;

        $clone!rebuild-privates( %!points, %!annotation-catalog );

        return $clone;
    };

    method !add-hline( Line:D :$hline --> Nil ) {
        %!hlines{ make-line-key( $hline ) } = $hline;
        %!hline-lookup{ $hline.neg.y }{ $hline.neg.x } = $hline.pos.x;
    }

    method !add-vline( Line:D :$vline --> Nil ) {
        %!vlines{ make-line-key( $vline ) } = $vline;
        %!vline-lookup{ $vline.neg.x }{ $vline.neg.y } = $vline.pos.y;
    }

    method !remove-hline( Line:D :$hline --> Nil ) {
        %!hlines{ make-line-key( $hline ) }:delete;
        %!hline-lookup{ $hline.neg.y }{ $hline.neg.x }:delete;
        if not %!hline-lookup{ $hline.neg.y }.elems {
            %!hline-lookup{ $hline.neg.y }:delete;
        }
    }

    method !remove-vline( Line:D :$vline --> Nil ) {
        %!vlines{ make-line-key( $vline ) }:delete;
        %!vline-lookup{ $vline.neg.x }{ $vline.neg.y }:delete;
        if not %!vline-lookup{ $vline.neg.x }.elems {
            %!vline-lookup{ $vline.neg.x }:delete;
        }
    }

    method audit-points-and-lines( --> Nil ) {
        my $audit-failed = False;

        for %!points -> $point-kv {
            if $point-kv.key ne make-point-key( $point-kv.value ) {
                $audit-failed = True;
                say "point stored at (" ~ $point-kv.key ~ ") should be stored at (" ~ make-point-key( $point-kv.value ) ~ ")";
            }
            my $point = $point-kv.value;
            if $point.lines{ ph-neg-x }:exists {
                my $line = $point.lines{ ph-neg-x };
                my $line-key = make-line-key( $line );
                if not $line.pos === $point {
                    $audit-failed = True;
                    my $other-point = $line.pos;
                    my $message = "pont/line mismatch: ";
                    $message ~= "point ($point) stored at (" ~ $point-kv.key ~ '), has lines{ ph-neg-x } refering to ';
                    $message ~= "line ($line)/($line-key), ";
                    $message ~= "but that line has point ($other-point)/(" ~ make-point-key( $other-point ) ~ ") for its pos end";
                    say $message;
                }
                if not %!hlines{ $line-key }:exists {
                    $audit-failed = True;
                    say "line $line-key not indexed";
                }
                if (
                    %!hline-lookup{ $line.neg.y }:!exists or
                    %!hline-lookup{ $line.neg.y }{ $line.neg.x }:!exists or 
                    %!hline-lookup{ $line.neg.y }{ $line.neg.x } != $line.pos.x
                ) {
                    $audit-failed = True;
                    say "line $line-key not seoncary indexed";
                }
            }
            if $point.lines{ ph-neg-y }:exists {
                my $line = $point.lines{ ph-neg-y };
                my $line-key = make-line-key( $line );
                if not $line.pos === $point {
                    $audit-failed = True;
                    my $other-point = $line.pos;
                    my $message = "pont/line mismatch: ";
                    $message ~= "point ($point) stored at (" ~ $point-kv.key ~ '), has lines{ ph-neg-y } refering to ';
                    $message ~= "line ($line)/($line-key), ";
                    $message ~= "but that line has point ($other-point)/(" ~ make-point-key( $other-point ) ~ ") for its pos end";
                    say $message;
                }
                if not %!vlines{ $line-key }:exists {
                    $audit-failed = True;
                    say "line $line-key not indexed";
                }
                if (
                    %!vline-lookup{ $line.neg.x }:!exists or
                    %!vline-lookup{ $line.neg.x }{ $line.neg.y }:!exists or 
                    %!vline-lookup{ $line.neg.x }{ $line.neg.y } != $line.pos.y
                ) {
                    $audit-failed = True;
                    say "line $line-key not seoncary indexed";
                }
            }
            if $point.lines{ ph-pos-x }:exists {
                my $line = $point.lines{ ph-pos-x };
                my $line-key = make-line-key( $line );
                if not $line.neg === $point {
                    $audit-failed = True;
                    my $other-point = $line.neg;
                    my $message = "pont/line mismatch: ";
                    $message ~= "point ($point) stored at (" ~ $point-kv.key ~ '), has lines{ ph-pos-x } refering to ';
                    $message ~= "line ($line)/($line-key), ";
                    $message ~= "but that line has point ($other-point)/(" ~ make-point-key( $other-point ) ~ ") for its neg end";
                    say $message;
                }
                if not %!hlines{ $line-key }:exists {
                    $audit-failed = True;
                    say "line $line-key not indexed";
                }
                if (
                    %!hline-lookup{ $line.neg.y }:!exists or
                    %!hline-lookup{ $line.neg.y }{ $line.neg.x }:!exists or 
                    %!hline-lookup{ $line.neg.y }{ $line.neg.x } != $line.pos.x
                ) {
                    $audit-failed = True;
                    say "line $line-key not seoncary indexed";
                }
            }
            if $point.lines{ ph-pos-y }:exists {
                my $line = $point.lines{ ph-pos-y };
                my $line-key = make-line-key( $line );
                if not $line.neg === $point {
                    $audit-failed = True;
                    my $other-point = $line.neg;
                    my $message = "pont/line mismatch: ";
                    $message ~= "point ($point) stored at (" ~ $point-kv.key ~ '), has lines{ ph-pos-y } refering to ';
                    $message ~= "line ($line)/($line-key), ";
                    $message ~= "but that line has point ($other-point)/(" ~ make-point-key( $other-point ) ~ ") for its neg end";
                    say $message;
                }
                if not %!vlines{ $line-key }:exists {
                    $audit-failed = True;
                    say "line $line-key not indexed";
                }
                if (
                    %!vline-lookup{ $line.neg.x }:!exists or
                    %!vline-lookup{ $line.neg.x }{ $line.neg.y }:!exists or 
                    %!vline-lookup{ $line.neg.x }{ $line.neg.y } != $line.pos.y
                ) {
                    $audit-failed = True;
                    say "line $line-key not seoncary indexed";
                }
            }
        }

        for %!vlines -> $vline-kv {
            my $line = $vline-kv.value;
            my $line-key = make-line-key( $line );
            if $vline-kv.key ne $line-key {
                $audit-failed = True;
                say "vline ($line) stored at (" ~ $vline-kv.key ~ ") should be stored at ($line-key)";
            }
            if (
                %!vline-lookup{ $line.neg.x }:!exists or
                %!vline-lookup{ $line.neg.x }{ $line.neg.y }:!exists or 
                %!vline-lookup{ $line.neg.x }{ $line.neg.y } != $line.pos.y
            ) {
                $audit-failed = True;
                say "line $line-key not seoncary indexed";
            }
            my $neg-point = $line.neg;
            my $neg-point-key = make-point-key( $neg-point );
            my $pos-point = $line.pos;
            my $pos-point-key = make-point-key( $pos-point );
            if not ( $line.neg.lines{ ph-pos-y }:exists and $line.neg.lines{ ph-pos-y } === $line ) {
                $audit-failed = True;
                say "vline ($line)/($line-key) .neg point ($neg-point)/($neg-point-key) does not refer to the correct line";
            }
            if not ( $line.pos.lines{ ph-neg-y }:exists and $line.pos.lines{ ph-neg-y } === $line ) {
                $audit-failed = True;
                say "vline ($line)/($line-key) .pos point ($pos-point)/($pos-point-key) does not refer to the correct line";
            }
            if not %!points{ $neg-point-key }:exists {
                $audit-failed = True;
                say "vline ($line)/($line-key) .neg point ($neg-point)/($neg-point-key) not indexed";
            }
            if not %!points{ $pos-point-key }:exists {
                $audit-failed = True;
                say "vline ($line)/($line-key) .pos point ($pos-point)/($pos-point-key) not indexed";
            }
        }

        for %!hlines -> $hline-kv {
            my $line = $hline-kv.value;
            my $line-key = make-line-key( $line );
            if $hline-kv.key ne $line-key {
                $audit-failed = True;
                say "hline ($line) stored at (" ~ $hline-kv.key ~ ") should be stored at ($line-key)";
            }
            if (
                %!hline-lookup{ $line.neg.y }:!exists or
                %!hline-lookup{ $line.neg.y }{ $line.neg.x }:!exists or 
                %!hline-lookup{ $line.neg.y }{ $line.neg.x } != $line.pos.x
            ) {
                $audit-failed = True;
                say "line $line-key not seoncary indexed";
            }
            my $neg-point = $line.neg;
            my $neg-point-key = make-point-key( $neg-point );
            my $pos-point = $line.pos;
            my $pos-point-key = make-point-key( $pos-point );
            if not ( $line.neg.lines{ ph-pos-x }:exists and $line.neg.lines{ ph-pos-x } === $line ) {
                $audit-failed = True;
                say "hline ($line)/($line-key) .neg point ($neg-point)/($neg-point-key) does not refer to the correct line";
            }
            if not ( $line.pos.lines{ ph-neg-x }:exists and $line.pos.lines{ ph-neg-x } === $line ) {
                $audit-failed = True;
                say "hline ($line)/($line-key) .pos point ($pos-point)/($pos-point-key) does not refer to the correct line";
            }
            if not %!points{ $neg-point-key }:exists {
                $audit-failed = True;
                say "hline ($line)/($line-key) .neg point ($neg-point)/($neg-point-key) not indexed";
            }
            if not %!points{ $pos-point-key }:exists {
                $audit-failed = True;
                say "hline ($line)/($line-key) .pos point ($pos-point)/($pos-point-key) not indexed";
            }
        }

        if $audit-failed {
            fail "point and line audit failed";
        }
    }

    method rehash-points-and-lines( --> Nil ) {
        my @points = %!points.values;
        %!points = ();
        for @points -> $point {
            %!points{ $point.x ~ ',' ~ $point.y } = $point;
        }

        my @vlines = %!vlines.values;
        %!vlines = ();
        %!vline-lookup = ();
        for @vlines -> $vline {
            self!add-vline( :$vline );
        }

        my @hlines = %!hlines.values;
        %!hlines = ();
        %!hline-lookup = ();
        for @hlines -> $hline {
            self!add-hline( :$hline );
        }
    }

    # moves everything >= the given x by one
    method grow-x( Int:D :$x, --> Nil ) {
        # move all the affected points
        for %!points.values.grep( { .x >= $x } ) -> $point {
            $point.x++;
        }

        # including head
        if $!head-x >= $x {
            $!head-x++;
            if $!head-point.DEFINITE {
                $!head-point.x++;
            }
        }

        # recalculate *all* the keys
        self.rehash-points-and-lines;
    }

    # moves everything >= the given y by one
    method grow-y( Int:D :$y, --> Nil ) {
        # move all the affected points
        for %!points.values.grep( { .y >= $y } ) -> $point {
            $point.y++;
        }

        # including head
        if $!head-y >= $y {
            $!head-y++;
            if $!head-point.DEFINITE {
                $!head-point.y++;
            }
        }

        # recalculate *all* the keys
        self.rehash-points-and-lines;
    }

    method find-line-at-x-y( Int:D :$x, Int:D :$y, --> Line ) {
        # check to see if we're on an existing line that must be split
        # this can only happen when we aren't plotting (which implies
        # that there's no head-point)

        # if there's a point, we treat it as if there were no lines
        if %!points{ make-point-key( :$x, :$y ) }:exists {
            return Nil;
        }

        my @vlines;
        if %!vline-lookup{ $x }:exists {
            for |%!vline-lookup{ $x }.sort( { +$^a.key <=> +$^b.key } ) -> $y-pair {
                if +$y-pair.key > $y {
                    last;
                }
                elsif $y-pair.value >= $y {
                    @vlines.push( %!vlines{ make-line-key( :$x, y1 => +$y-pair.key, y2 => $y-pair.value ) } );
                    last;
                }
            }
        }

        my @hlines;
        if %!hline-lookup{ $y }:exists {
            for |%!hline-lookup{ $y }.sort( { +$^a.key <=> +$^b.key } ) -> $x-pair {
                if +$x-pair.key > $x {
                    last;
                }
                elsif $x-pair.value >= $x {
                    @hlines.push( %!hlines{ make-line-key( :$y, x1 => +$x-pair.key, x2 => $x-pair.value ) } );
                    last;
                }
            }
        }

        if @vlines.elems + @hlines.elems > 1 {
            fail "there seem to be overlapping lines";
        }

        if @vlines.elems {
            return @vlines[0];
        }
        elsif @hlines.elems {
            return @hlines[0];
        }
        else {
            return Nil;
        }
    }

    method split-line-at-x-y( Line:D :$line, Int:D :$x, Int:D :$y, --> Point ) {
        my $point-key = make-point-key( :$x, :$y );

        fail "point already exists at location" if %!points{ $point-key }:exists;

        my $new-point = Point.new( :$x, :$y );

        %!points{ $point-key } = $new-point;

        if $line.orientation == lo-vertical {
            self.split-vline-at( vline => $line, :$new-point );
        }
        else {
            self.split-hline-at( hline => $line, :$new-point );
        }

        return $new-point;
    }

    method split-vline-at( Line:D :$vline, Point:D :$new-point ) {
        fail "Point not on vline (invalid x)" unless $new-point.x == $vline.neg.x;
        fail "Point not on vline (invalid y)" unless $vline.neg.y < $new-point.y < $vline.pos.y;

        self!remove-vline( :$vline );

        my $pos-line = Line.new( orientation => lo-vertical, pos => $vline.pos, neg => $new-point );
        my $neg-line = Line.new( orientation => lo-vertical, pos => $new-point, neg => $vline.neg );

        $vline.pos.lines{ ph-neg-y } = $pos-line;
        $new-point.lines{ ph-pos-y } = $pos-line;
        $new-point.lines{ ph-neg-y } = $neg-line;
        $vline.neg.lines{ ph-pos-y } = $neg-line;

        self!add-vline( vline => $pos-line );
        self!add-vline( vline => $neg-line );

        return;
    }

    method split-hline-at( Line:D :$hline, Point:D :$new-point ) {
        fail "Point not on hline (invalid y)" unless $new-point.y == $hline.neg.y;
        fail "Point not on hline (invalid x)" unless $hline.neg.x < $new-point.x < $hline.pos.x;

        self!remove-hline( :$hline );

        my $pos-line = Line.new( orientation => lo-horizontal, pos => $hline.pos, neg => $new-point );
        my $neg-line = Line.new( orientation => lo-horizontal, pos => $new-point, neg => $hline.neg );

        $hline.pos.lines{ ph-neg-x } = $pos-line;
        $new-point.lines{ ph-pos-x } = $pos-line;
        $new-point.lines{ ph-neg-x } = $neg-line;
        $hline.neg.lines{ ph-pos-x } = $neg-line;

        self!add-hline( hline => $pos-line );
        self!add-hline( hline => $neg-line );

        return;
    }

    my multi sub make-point-key( Int:D :$x, Int:D :$y ) {
        return "$x,$y";
    }

    my multi sub make-point-key( Point:D $point ) {
        return $point.x ~ "," ~ $point.y;
    }

    my multi sub make-line-key( Int:D :$x, Int:D :$y1, Int:D :$y2 ) {
        if $y1 > $y2 {
            ( $y1, $y2 ) = ( $y2, $y1 );
        }

        return "$x,$y1,$y2";
    }

    my multi sub make-line-key( Int:D :$y, Int:D :$x1, Int:D :$x2 ) {
        if $x1 > $x2 {
            ( $x1, $x2 ) = ( $x2, $x1 );
        }

        return "$y,$x1,$x2";
    }

    my multi sub make-line-key( Line:D $line ) {
        if $line.orientation == lo-horizontal {
            return $line.neg.y ~ "," ~ $line.neg.x ~ "," ~ $line.pos.x;
        }
        elsif $line.orientation == lo-vertical {
            return $line.neg.x ~ "," ~ $line.neg.y ~ "," ~ $line.pos.y;
        }
        else {
            fail;
        }
    }

    # TODO add option to add axis labels
    # TODO this seems to be very CPU intensive for the amount of work it does
    # returns a list of strings
    method render-to-strings(
        Bool:D :$with-annotations is copy = True,
        Bool:D :$with-head-location is copy = True,
        Bool:D :$with-frame is copy = True,
        Bool:D :$with-frame-marks is copy = True,
        --> List
    ) {
        my $max-annotation-width = 0;

        if $with-annotations {
            # clean up overwritten annotations
            for %!annotation-catalog.pairs -> $p {
                if $p.value == 0 {
                    %!annotation-catalog{ $p.key }:delete;
                }
            }

            $max-annotation-width = max( %!annotation-catalog.keys.map: { $_.chars } );

            # max returns -Inf for an empty list
            if $max-annotation-width <= 0 {
                $max-annotation-width = 1;
            }
        }

        my $fmt-string = '%' ~ $max-annotation-width ~ 's';
        my $empty = %lineGlyphs<empty>;
        my $empty-annotation = $empty x $max-annotation-width;
        my $x-line = %lineGlyphs<False><True><True><False>;
        my $y-line = %lineGlyphs<True><False><False><True>;
        my $x-line-long = $x-line x $max-annotation-width;

        my $max-grid-x = max( %!points.values.map: { $_.x } );
        if $!head-x > $max-grid-x {
            $max-grid-x = $!head-x;
        }
        my $max-grid-y = max( %!points.values.map: { $_.y } );
        if $!head-y > $max-grid-y {
            $max-grid-y = $!head-y;
        }

        my @rendered-rows;

        if $with-head-location {
            @rendered-rows.unshift( "head = " ~ $!head-x ~ "," ~ $!head-y ~ " - heading " ~ $!heading );
        }

        if $with-frame {
            if $with-annotations {
                my $tick-mark = $with-frame-marks ?? $y-line !! $x-line;
                @rendered-rows.unshift(
                    %lineGlyphs<True><False><True><False> ~
                    ( ( $x-line-long ~ $tick-mark ~ $x-line-long ) x ( $max-grid-x + 1 ) ) ~
                    %lineGlyphs<True><True><False><False>
                );
            }
            else {
                # no tick marks without annotations
                @rendered-rows.unshift(
                    %lineGlyphs<True><False><True><False> ~
                    (  $x-line x ( $max-grid-x + 1 ) ) ~
                    %lineGlyphs<True><True><False><False>
                );
            }
        }

        for 0 .. $max-grid-y -> $grid-y {
            my @annotation-u-data;
            my @grid-row-data;
            my @annotation-d-data;

            if $with-frame {
                if $with-annotations {
                    my $tick-mark = $with-frame-marks ?? $x-line !! $y-line;
                    @annotation-u-data.push( $y-line );
                    @grid-row-data.push( $tick-mark );
                    @annotation-d-data.push( $y-line );
                }
                else {
                    # no tick marks without annotations
                    @grid-row-data.push( $y-line );
                }
            }

            my $grid-x = 0;

            # this will allow us to skip when we have horizontal lines
            # whereas "for 1 .. $max-grid-x" would not
            while $grid-x <= $max-grid-x {
                my $point-key = make-point-key( x => $grid-x, y => $grid-y );

                # if on a point, render it
                if %!points{ $point-key }:exists {
                    my $point = %!points{ $point-key };
                    my %notes = $point.notes;
                    my %lines = $point.lines;

                    if $with-annotations {
                        if %notes<ul-annotation>:exists {
                            @annotation-u-data.push( $fmt-string.sprintf( %notes<ul-annotation> ) );
                        }
                        else {
                            @annotation-u-data.push( $empty-annotation );
                        }

                        if %lines{ ph-neg-x }:exists {
                            @grid-row-data.push( $x-line-long );
                        }
                        else {
                            @grid-row-data.push( $empty-annotation );
                        }

                        if %notes<dl-annotation>:exists {
                            @annotation-d-data.push( $fmt-string.sprintf( %notes<dl-annotation> ) );
                        }
                        else {
                            @annotation-d-data.push( $empty-annotation );
                        }

                        if %lines{ ph-pos-y }:exists {
                            @annotation-u-data.push( $y-line );
                        }
                        else {
                            @annotation-u-data.push( $empty );
                        }
                    }

                    # if has a mark, use that
                    if %notes<mark>:exists {
                        @grid-row-data.push( %notes<mark> )
                    }
                    elsif $with-head-location and $grid-x == $!head-x and $grid-y == $!head-y {
                        @grid-row-data.push( 'H' );
                    }
                    elsif $with-annotations and "ForTesting" {
                        # make sure all points are visible
                        @grid-row-data.push( %lineGlyphs{ False }{ False }{ False }{ False } );
                    }
                    # otherwise look up based on lines in/out
                    else {
                        @grid-row-data.push( %lineGlyphs{ %lines{ ph-pos-y }:exists }{ %lines{ ph-neg-x }:exists }{ %lines{ ph-pos-x }:exists }{ %lines{ ph-neg-y }:exists } );
                    }

                    if $with-annotations {
                        if %lines{ ph-neg-y }:exists {
                            @annotation-d-data.push( $y-line );
                        }
                        else {
                            @annotation-d-data.push( $empty );
                        }

                        if %notes<ur-annotation>:exists {
                            @annotation-u-data.push( $fmt-string.sprintf( %notes<ur-annotation> ) );
                        }
                        else {
                            @annotation-u-data.push( $empty-annotation );
                        }

                        if %lines{ ph-pos-x }:exists {
                            @grid-row-data.push( $x-line-long );
                        }
                        else {
                            @grid-row-data.push( $empty-annotation );
                        }

                        if %notes<dr-annotation>:exists {
                            @annotation-d-data.push( $fmt-string.sprintf( %notes<dr-annotation> ) );
                        }
                        else {
                            @annotation-d-data.push( $empty-annotation );
                        }
                    }

                    # if that point is the .neg side of an hline, render the line (but not the other endpoint)
                    if %lines{ ph-pos-x }:exists {
                        my $hline = %lines{ ph-pos-x };
                        my $middle-len = $hline.pos.x - $hline.neg.x - 1;

                        if $middle-len {
                            if $with-annotations {
                                @annotation-u-data.push( $empty-annotation x ( 2 * $middle-len ), $empty x $middle-len );
                                @grid-row-data.push( $x-line-long x $middle-len );
                            }

                            @grid-row-data.push( $x-line x $middle-len );

                            if $with-annotations {
                                @grid-row-data.push( $x-line-long x $middle-len );
                                @annotation-d-data.push( $empty-annotation x ( 2 * $middle-len ), $empty x $middle-len );
                            }
                        }

                        $grid-x = $hline.pos.x;
                    }
                    else {
                        $grid-x++;
                    }
                }
                # if on a vline, render it
                elsif self.find-line-at-x-y( x => $grid-x, y => $grid-y ) {
                    # we know we're not on a point, so we don't actually care about the line at all
                    if $with-annotations {
                        @annotation-u-data.push( $empty-annotation, $y-line, $empty-annotation );
                        @grid-row-data.push( $empty-annotation );
                    }

                    @grid-row-data.push( $y-line );

                    if $with-annotations {
                        @grid-row-data.push( $empty-annotation );
                        @annotation-d-data.push( $empty-annotation, $y-line, $empty-annotation );
                    }

                    $grid-x++;
                }
                # otherwise we're empty
                else {
                    if $with-annotations {
                        @annotation-u-data.push( $empty-annotation, $empty, $empty-annotation );
                        @grid-row-data.push( $empty-annotation );
                    }

                    @grid-row-data.push( $empty );

                    if $with-annotations {
                        @grid-row-data.push( $empty-annotation );
                        @annotation-d-data.push( $empty-annotation, $empty, $empty-annotation );
                    }

                    $grid-x++;
                }
            }

            if $with-frame {
                if $with-annotations {
                    @annotation-u-data.push( $y-line );
                }
                @grid-row-data.push( $y-line );
                if $with-annotations {
                    @annotation-d-data.push( $y-line );
                }
            }

            if $with-annotations {
                @rendered-rows.unshift( @annotation-d-data.join( '' ) );
            }

            @rendered-rows.unshift( @grid-row-data.join( '' ) );

            if $with-annotations {
                @rendered-rows.unshift( @annotation-u-data.join( '' ) );
            }
        }

        if $with-frame {
            if $with-annotations {
                @rendered-rows.unshift(
                    %lineGlyphs<False><False><True><True> ~
                    ( ( $x-line-long ~ $x-line ~ $x-line-long ) x ( $max-grid-x + 1 ) ) ~
                    %lineGlyphs<False><True><False><True>
                );
            }
            else {
                @rendered-rows.unshift(
                    %lineGlyphs<False><False><True><True> ~
                    (  $x-line x ( $max-grid-x + 1 ) ) ~
                    %lineGlyphs<False><True><False><True>
                );
            }
        }

        return @rendered-rows;
    }

    method render-to-multiline-string(
        Bool:D :$with-annotations = True,
        Bool:D :$with-head-location is copy = True,
        Bool:D :$with-frame is copy = True,
        Bool:D :$with-frame-marks is copy = True,
        --> Str
    ) {
        return self.render-to-strings( :$with-annotations, :$with-head-location, :$with-frame, :$with-frame-marks ).join("\n") ~ "\n";
    }

    # terminates the current line, if any, storing the line and end point
    # returns nothing
    method terminate-current-line( --> Nil ) {
        if $!current-line {
            my $point-key = make-point-key( x => $!head-x, y => $!head-y );

            %!points{ $point-key } = $!head-point;

            my $orientation = $!current-line.orientation;

            if $orientation == lo-vertical {
                self!add-vline( vline => $!current-line );
            }
            else { # lo-horizontal
                self!add-hline( hline => $!current-line );
            }

            $!entered-going = Nil;
            $!current-line = Nil;
            $!head-point = Nil;

            # automatic de-encroachment causes degenerate cases
            # it cannot be done.
        }

        return;
    }

    # (re)note the current point, with optional annotation(s) and/or user-data
    # a new annotation that is an empty string will remove any existing annotation
    # N.B. there is no way to remove user data except by replacing it with other defined data
    # returns a copy of the point notes
    method plot( 
        Str :$mark,
        Str :$ur-annotation,
        Str :$dr-annotation,
        Str :$dl-annotation,
        Str :$ul-annotation,
        :$user-data,
        --> Hash
    ) {
        my $point-key = make-point-key( x => $!head-x, y => $!head-y );

        my $point;

        if %!points{ $point-key }:!exists {
            if $!head-point.DEFINITE {
                fail "unexpected head-point without current-line" unless $!current-line.DEFINITE;
                self.terminate-current-line;
            }
            else {
                my $line = self.find-line-at-x-y( x => $!head-x, y => $!head-y );

                if $line.DEFINITE {
                    self.split-line-at-x-y( $line, x => $!head-x, y => $!head-y );
                }
                else {
                    my $new-point = Point.new( x => $!head-x, y => $!head-y );
                    my $new-point-key = make-point-key( x => $!head-x, y => $!head-y );

                    %!points{ $new-point-key } = $new-point;
                }
            }
        }

        $point = %!points{ $point-key };

        my $point-notes = $point.notes;

        if $mark.DEFINITE {
            fail "invalid mark, '$mark', must be a single glyph or the empty string" if $mark.chars > 1;

            if $mark eq '' {
                $point-notes<mark>:delete;
            }
            else {
                $point-notes<mark> = $mark;
            }
        }

        for 'ur', $ur-annotation, 'dr', $dr-annotation, 'dl', $dl-annotation, 'ul', $ul-annotation -> $pos, $value {
            my $key = $pos ~ '-annotation';

            if $value.DEFINITE {
                if $point-notes{ $key }:exists {
                    %!annotation-catalog{ $point-notes{ $key } }--;
                }

                if $value eq '' {
                    $point-notes{ $key }:delete;
                }
                else {
                    $point-notes{ $key } = $value;

                    %!annotation-catalog{ $value }++;
                }
            }
        }

        if $user-data.DEFINITE {
            $point-notes<user-data> = $user-data;
        }

        return Hash.new( $point-notes.pairs );
    };

    # returns the new absolute heading
    multi method turn( Direction:D :$relative, --> Heading ) {
        $!heading = %turnChart{ $!heading }{ $relative };

        return $!heading;
    };

    # returns the new absolute heading
    multi method turn( Heading:D :$absolute, --> Heading ) {
        $!heading = $absolute;

        return $!heading;
    };

    # returns the new grid (x,y)
    method advance( Bool:D :$plotting = True, --> Coordinate ) {
        #  if we have a line (meaning that we were plotting) either
        #  1) changed direction
        #  2) stopped plotting
        #  then we need stop the current line before continuing
        if (
            $!current-line and
            (
                $!entered-going != $!heading or
                not $plotting
            )
        ) {
            self.terminate-current-line;
        }

        my $Δx = %movementChart{ $!heading }< Δx >;
        my $Δy = %movementChart{ $!heading }< Δy >;

        if $Δx < 0 and $!head-x == 0 {
            self.grow-x( x => 0 );
        }

        if $Δy < 0 and $!head-y == 0 {
            self.grow-y( y => 0 );
        }

        my $orig-head-x = $!head-x;
        my $orig-head-y = $!head-y;

        $!head-x += $Δx;
        $!head-y += $Δy;

        if $plotting {
            my $dest-point-key = make-point-key( x => $!head-x, y => $!head-y );
            my $dest;

            if %!points{$dest-point-key}:exists {
                $dest = %!points{$dest-point-key};
            }
            else {
                # see if we're moving onto a line, if so we have to split it
                my $dest-line = self.find-line-at-x-y( x => $!head-x, y => $!head-y );

                if $dest-line.DEFINITE {
                    self.split-line-at-x-y( line => $dest-line, x => $!head-x, y => $!head-y );
                    $dest = %!points{$dest-point-key};
                }
            }

            if $!current-line {
                if $dest {
                    # if we're moving onto a point, modify current-line
                    # and head-point to refer to dest, before terminating the line
                    if $Δx + $Δy > 0 {
                        $!current-line.pos = $dest;
                        if $Δx {
                            $dest.lines{ ph-neg-x } = $!current-line;
                        }
                        else {
                            $dest.lines{ ph-neg-y } = $!current-line;
                        }
                    }
                    else {
                        $!current-line.neg = $dest;
                        if $Δx {
                            $dest.lines{ ph-pos-x } = $!current-line;
                        }
                        else {
                            $dest.lines{ ph-pos-y } = $!current-line;
                        }
                    }
                    $!head-point = $dest;
                    self.terminate-current-line;
                }
                else {
                    # otherwise all we have to do is update head-point (unterminated lines are not indexed in vlines and hlines)
                    $!head-point.x = $!head-x;
                    $!head-point.y = $!head-y;
                }
            }
            else {
                # no current line implies that we need to start one
                my $origin-point-key = make-point-key( x => $orig-head-x, y => $orig-head-y );
                my $origin;

                # see if we started on a point
                if %!points{$origin-point-key}:exists {
                    # is it valid to plot in the direction we're moving?
                    $origin = %!points{$origin-point-key};

                    if $origin.lines{ $!heading }:exists {
                        say self.render-to-multiline-string;
                        fail "line already exists in $!heading direction";
                    }
                }
                else {
                    my $origin-line = self.find-line-at-x-y( x => $orig-head-x, y => $orig-head-y );

                    if $origin-line.DEFINITE {
                        self.split-line-at-x-y( $origin-line, x => $orig-head-x, y => $orig-head-y );
                        $origin = %!points{$origin-point-key};
                    }
                    else {
                        $origin = Point.new( x => $orig-head-x, y => $orig-head-y );

                        %!points{ $origin-point-key } = $origin;
                    }
                }

                # if we're moving onto a point, create a new line linking our origin with the destination
                # otherwise create a new head-point and start a new current-line
                my $line-orientation = lo-horizontal;

                if $Δy {
                    $line-orientation = lo-vertical;
                }

                if $dest {
                    # no current line, but there is a point already at our destination,
                    # so we need to use that when we create the new line
                    # (which we will immediately terminate)
                    $!head-point = $dest;
                }
                else {
                    # there's not already a point at the destination, so create a new head-point
                    # we don't set $dest here so that we can tell later that we don't have to
                    # terminate the line
                    if not $!head-point.DEFINITE {
                        $!head-point = Point.new( x => $!head-x, y => $!head-y );
                    }
                }

                my $pos;
                my $neg;

                if $Δx + $Δy > 0 {
                    $pos = $!head-point;
                    $neg = $origin;
                }
                else {
                    $pos = $origin;
                    $neg = $!head-point;
                }

                my $line = Line.new( orientation => $line-orientation, pos => $pos, neg => $neg );

                if $line-orientation == lo-vertical {
                    if $Δx + $Δy > 0 {
                        $origin.lines{ ph-pos-y } = $line;
                        $!head-point.lines{ ph-neg-y } = $line;
                    }
                    else {
                        $origin.lines{ ph-neg-y } = $line;
                        $!head-point.lines{ ph-pos-y } = $line;
                    }
                }
                else {
                    if $Δx + $Δy > 0 {
                        $origin.lines{ ph-pos-x } = $line;
                        $!head-point.lines{ ph-neg-x } = $line;
                    }
                    else {
                        $origin.lines{ ph-neg-x } = $line;
                        $!head-point.lines{ ph-pos-x } = $line;
                    }
                }

                $!current-line = $line;

                if $dest {
                    # dest already existed, so terminate the line we just created
                    self.terminate-current-line;
                }
            }
        }

        $!entered-going = $!heading;

        return \( x => $!head-x, y => $!head-y );
    };

    # move the head to absolute grid coordinates
    # returns nothing
    multi method seek( Int:D :$x, Int:D :$y, --> Nil ) {
        if $!current-line {
            self.terminate-current-line;
        }

        $!head-x = $x;
        $!head-y = $y;

        return;
    };

    # move the head to a relative (grid) offset
    # returns the new grid (x,y)
    multi method seek( Int:D :$Δx, Int:D :$Δy, --> Coordinate ) {
        self.seek( x => $!head-x + $Δx, y => $!head-y + $Δy );

        return \( x => $!head-x, y => $!head-y );
    };

    # see other
    multi method look( Direction:D :$relative, Num:D :$horizon = Inf, --> Hash ) {
        return self.look( absolute => %turnChart{ $!heading }{ $relative }, :$horizon );
    };

    # returns information on the first non-empty location in the indicated direction from
    # the head-x/head-y position, within the given horizon
    #   if a point, will return the user-data for that point
    #   if a line will a pair (not a Pair) of coordinates for the endpoints of the line
    #   if nothing, will return Nil
    #   will also return the distance of the thing
    multi method look( Heading:D :$absolute, Num:D :$horizon = Inf, --> Hash ) {
        my $max-grid-x = max( %!points.values.map: { $_.x } );
        my $max-grid-y = max( %!points.values.map: { $_.y } );

        my $Δx = %movementChart{ $absolute }< Δx >;
        my $Δy = %movementChart{ $absolute }< Δy >;

        my $x = $!head-x + $Δx;
        my $y = $!head-y + $Δy;

        my $distance = 1;

        while $distance <= $horizon {
            if ( $x < 0 or $y < 0 or $x > $max-grid-x or $y > $max-grid-y ) {
                return { found => Nil, line => Nil, distance => $horizon };
            }

            my $point-key = make-point-key( :$x, :$y );
            if %!points{ $point-key }:exists {
                my $point = %!points{ $point-key };
                return { found => $point.notes, line => Nil, distance => $distance };
            }

            my $line = self.find-line-at-x-y( :$x, :$y );
            if $line {
                return {
                    found => Nil,
                    line => (
                        \( x => $line.neg.x, y => $line.neg.y ),
                        \( x => $line.pos.x, y => $line.pos.y ),
                    ),
                    distance => $distance
                };
            }

            $x += $Δx;
            $y += $Δy;
            $distance++;
        }

        return { found => Nil, line => Nil, distance => $horizon };
    };

    # encroachment can happen on *both* sides simultaneously
    # therefore encroachment checks have to be done starting from the max value
    #   and each time you move something you have to recheck the line you just moved things *to*
    #     this implies that lines may have to be moved (and thus need to be checked) more than once
    #     n.b. de-encroachment on one axis can cause encroachment on the other, so we also have to loopp
    # returns nothing
    method de-encroach( --> Nil ) {
        if $!current-line {
            fail "can't de-encroach with an unfinished line";
        }

        my $unchecked = True;
        my $changed = False;

        while $unchecked or $changed {
            $unchecked = False;
            $changed = False;

            # scoping block
            {
                # start axis-value at max-1
                my $y = max( %!points.values.map: { $_.y } ) - 1;

                my @hlines = %!hlines.values;

                while $y >= 0 {
                    my $target-y = $y + 1;

                    my @lines-this-y;

                    if %!hline-lookup{ $y }:exists {
                        for |%!hline-lookup{ $y } -> $x-pair {
                            @lines-this-y.push( %!hlines{ make-line-key( :$y, x1 => +$x-pair.key, x2 => $x-pair.value ) } );
                        }
                    }

                    my %x-to-check;

                    for @lines-this-y -> $reference-line {
                        for $reference-line.neg.x .. $reference-line.pos.x -> $x {
                            %x-to-check{ $x } = True;
                        }
                    }

                    for %!points.values.grep( { .y == $y } ) -> $point {
                        %x-to-check{ $point.x } = True;
                    }

                    my %new-changes;

                    for %x-to-check.keys -> $str-x {
                        my $x = +$str-x;
                        # if there's a point, or a line with the same orientation at axis-value/crossing-value
                        my $point-key = make-point-key( :$x, y => $target-y );
                        if %!points{ $point-key }:exists {
                            my $point = %!points{ $point-key };

                            if not %new-changes{ $point }:exists {
                                %new-changes{ $point } = $point;
                            }
                        }
                        else {
                            my $adjacent-line = self.find-line-at-x-y( :$x, y => $target-y );

                            # this test keeps us from marking lines that originate from a point as encroaching on that point
                            if $adjacent-line.DEFINITE and $adjacent-line.orientation == lo-horizontal {
                                if not %new-changes{ $adjacent-line }:exists {
                                    %new-changes{ $adjacent-line } = $adjacent-line;
                                }
                            }
                        }
                    }

                    my %changes;

                    while %new-changes.elems {
                        my @new-changes = %new-changes.values;
                        %new-changes = ();

                        for @new-changes -> $thing {
                            %changes{ $thing } = $thing;

                            if $thing.isa( Point ) {
                                # the perpendicular lines, if any, are guaranteed to not already
                                # be noted, and are also guaranteed to not cascade
                                for ( ph-neg-y, ph-pos-y ) -> $dir {
                                    if $thing.lines{ $dir }:exists {
                                        my $perpendicular-line = $thing.lines{ $dir };

                                        %changes{ $perpendicular-line } = $perpendicular-line;
                                    }
                                }

                                # the inline lines, if any, may already be added and may cascade
                                for ( ph-neg-x, ph-pos-x ) -> $dir {
                                    if $thing.lines{ $dir }:exists {
                                        my $connected-line = $thing.lines{ $dir };

                                        if not %changes{ $connected-line }:exists {
                                            %new-changes{ $connected-line } = $connected-line;
                                        }
                                    }
                                }
                            }
                            elsif $thing.isa( Line ) {
                                # the endpoints may already be added and may cascade
                                for ( $thing.neg, $thing.pos ) -> $endpoint {
                                    if not %changes{ $endpoint }:exists {
                                        %new-changes{ $endpoint } = $endpoint;
                                    }
                                }
                            }
                            else {
                                fail "I don't know how I got here"
                            }
                        }
                    }

                    if %changes.elems {
                        my %by-type = %changes.values.classify( { .^name } );
                        my @lines = |%by-type< PlottingGrid::Malleable::Line >;
                        my @points = |%by-type< PlottingGrid::Malleable::Point >;

                        # de-index all the changed lines
                        for @lines -> $changed-line {
                            if $changed-line.orientation == lo-horizontal {
                                self!remove-hline( hline => $changed-line );
                            }
                            else {
                                self!remove-vline( vline => $changed-line );
                            }
                        }

                        # then move all the points (lines are implicit)
                        # reindexing them along the way
                        # don't worry about encroaching, we'll sort that at the next axis-value iteration
                        for @points -> $point {
                            %!points{ make-point-key( $point ) }:delete;
                            if $!head-x == $point.x and $!head-y == $point.y {
                                $!head-y++;
                            }
                            $point.y++;
                            %!points{ make-point-key( $point ) } = $point;
                        }

                        # then reindex all the changed lines
                        for @lines -> $changed-line {
                            if $changed-line.orientation == lo-horizontal {
                                self!add-hline( hline => $changed-line );
                            }
                            else {
                                self!add-vline( vline => $changed-line );
                            }
                        }

                        # we have to go back and check where we just pushed things into
                        $y += 2;

                        # with the first axis we don't have to set $changed
                        #$changed = True;
                    }
                    else {
                        $y--;
                    }
                }
            }

            # scoping block
            {
                # start axis-value at max-1
                my $x = max( %!points.values.map: { $_.x } ) - 1;

                my @vlines = %!vlines.values;

                while $x >= 0 {
                    my $target-x = $x + 1;

                    my @lines-this-x;

                    if %!vline-lookup{ $x }:exists {
                        for |%!vline-lookup{ $x } -> $y-pair {
                            @lines-this-x.push( %!vlines{ make-line-key( :$x, y1 => +$y-pair.key, y2 => $y-pair.value ) } );
                        }
                    }

                    my %y-to-check;

                    for @lines-this-x -> $reference-line {
                        for $reference-line.neg.y .. $reference-line.pos.y -> $y {
                            %y-to-check{ $y } = True;
                        }
                    }

                    for %!points.values.grep( { .x == $x } ) -> $point {
                        %y-to-check{ $point.y } = True;
                    }

                    my %new-changes;

                    for %y-to-check.keys -> $str-y {
                        my $y = +$str-y;
                        # if there's a point, or a line with the same orientation at axis-value/crossing-value
                        my $point-key = make-point-key( x => $target-x, :$y );
                        if %!points{ $point-key }:exists {
                            my $point = %!points{ $point-key };

                            if not %new-changes{ $point }:exists {
                                %new-changes{ $point } = $point;
                            }
                        }
                        else {
                            my $adjacent-line = self.find-line-at-x-y( x => $target-x, :$y );

                            # this test keeps us from marking lines that originate from a point as encroaching on that point
                            if $adjacent-line.DEFINITE and $adjacent-line.orientation == lo-vertical {
                                if not %new-changes{ $adjacent-line }:exists {
                                    %new-changes{ $adjacent-line } = $adjacent-line;
                                }
                            }
                        }
                    }

                    my %changes;

                    while %new-changes.elems {
                        my @new-changes = %new-changes.values;
                        %new-changes = ();

                        for @new-changes -> $thing {
                            %changes{ $thing } = $thing;

                            if $thing.isa( Point ) {
                                # the perpendicular lines, if any, are guaranteed to not already
                                # be noted, and are also guaranteed to not cascade
                                for ( ph-neg-x, ph-pos-x ) -> $dir {
                                    if $thing.lines{ $dir }:exists {
                                        my $perpendicular-line = $thing.lines{ $dir };

                                        %changes{ $perpendicular-line } = $perpendicular-line;
                                    }
                                }

                                # the inline lines, if any, may already be added and may cascade
                                for ( ph-neg-y, ph-pos-y ) -> $dir {
                                    if $thing.lines{ $dir }:exists {
                                        my $connected-line = $thing.lines{ $dir };

                                        if not %changes{ $connected-line }:exists {
                                            %new-changes{ $connected-line } = $connected-line;
                                        }
                                    }
                                }
                            }
                            elsif $thing.isa( Line ) {
                                # the endpoints may already be added and may cascade
                                for ( $thing.neg, $thing.pos ) -> $endpoint {
                                    if not %changes{ $endpoint }:exists {
                                        %new-changes{ $endpoint } = $endpoint;
                                    }
                                }
                            }
                            else {
                                fail "I don't know how I got here"
                            }
                        }
                    }

                    if %changes.elems {
                        my %by-type = %changes.values.classify( { .^name } );
                        my @lines = |%by-type< PlottingGrid::Malleable::Line >;
                        my @points = |%by-type< PlottingGrid::Malleable::Point >;

                        # de-index all the changed lines
                        for @lines -> $changed-line {
                            if $changed-line.orientation == lo-horizontal {
                                self!remove-hline( hline => $changed-line );
                            }
                            else {
                                self!remove-vline( vline => $changed-line );
                            }
                        }

                        # then move all the points (lines are implicit)
                        # reindexing them along the way
                        # don't worry about encroaching, we'll sort that at the next axis-value iteration
                        for @points -> $point {
                            %!points{ make-point-key( $point ) }:delete;
                            if $!head-x == $point.x and $!head-y == $point.y {
                                $!head-x++;
                            }
                            $point.x++;
                            %!points{ make-point-key( $point ) } = $point;
                        }

                        # then reindex all the changed lines
                        for @lines -> $changed-line {
                            if $changed-line.orientation == lo-horizontal {
                                self!add-hline( hline => $changed-line );
                            }
                            else {
                                self!add-vline( vline => $changed-line );
                            }
                        }

                        # we have to go back and check where we just pushed things into
                        $x += 2;

                        # with the second axis we have to set $changed so we will recheck
                        # the first axis
                        $changed = True;
                    }
                    else {
                        $x--;
                    }
                }
            }
        }
    };

    method simplify( --> Nil ) {
        fail "can't simplify with an unterminated line" if $!current-line;

        my $changed;

        # always make at least one pass, make additional passes if any changes were made
        # in most cases should restart after each change
        #   the modifications are listed in preferential order, and a change of one
        #   type may make possible a change of a more-preferred type
        PASS: repeat {
            $changed = False;
            self.audit-points-and-lines;

            # first remove empty lines
            {
                my @points = %!points.values;

                my %x-values = @points.classify( { .x } );
                my $max-x = max( %x-values.keys.map( { +$_ } ) );
                my $Δx = 0;

                for 0 .. $max-x -> $x {
                    if %x-values{ $x }:exists {
                        if $Δx {
                            for |%x-values{ $x } -> $point {
                                $point.x -= $Δx;
                            }
                        }
                    }
                    else {
                        $Δx++;
                    }

                    if $!head-x == $x {
                        $!head-x -= $Δx;
                    }
                }

                my %y-values = @points.classify( { .y } );
                my $max-y = max( %y-values.keys.map( { +$_ } ) );
                my $Δy = 0;

                for 0 .. $max-y -> $y {
                    if %y-values{ $y }:exists {
                        if $Δy {
                            for |%y-values{ $y } -> $point {
                                $point.y -= $Δy;
                            }
                        }
                    }
                    else {
                        $Δy++;
                    }

                    if $!head-y == $y {
                        $!head-y -= $Δy;
                    }
                }

                if $Δx + $Δy > 0 {
                    self.rehash-points-and-lines;
                    $changed = True;
                    next PASS;
                }
            }

            # look for points in the middle of straight lines that have no marks and no perpendicular lines
            for %!points.values -> $point {
                # only consider if no notes
                next if $point.notes.keys.elems;

                # if there are perpendicular lines then it's not an option
                if (
                    ( $point.lines{ ph-pos-x }:exists or $point.lines{ ph-neg-x }:exists ) and
                    ( $point.lines{ ph-pos-y }:exists or $point.lines{ ph-neg-y }:exists )
                ) {
                    next;
                }

                if ( $point.lines{ ph-pos-x }:exists and $point.lines{ ph-neg-x }:exists ) {
                    my $neg-line = $point.lines{ ph-neg-x };
                    my $pos-line = $point.lines{ ph-pos-x };
                    my $neg-keep-point = $neg-line.neg;
                    my $pos-keep-point = $pos-line.pos;

                    # both lines need removed from the lookup
                    self!remove-hline( hline => $neg-line );
                    self!remove-hline( hline => $pos-line );

                    $neg-line.pos = $pos-keep-point;
                    $pos-keep-point.lines{ ph-neg-x } = $neg-line;
                    $point.lines{ ph-neg-x }:delete;
                    $point.lines{ ph-pos-x }:delete;

                    # re-add the line we're keeping
                    self!add-hline( hline => $neg-line );
                }
                elsif ( $point.lines{ ph-pos-y }:exists and $point.lines{ ph-neg-y }:exists ) {
                    my $neg-line = $point.lines{ ph-neg-y };
                    my $pos-line = $point.lines{ ph-pos-y };
                    my $neg-keep-point = $neg-line.neg;
                    my $pos-keep-point = $pos-line.pos;

                    # both lines need removed from the lookup
                    self!remove-vline( vline => $neg-line );
                    self!remove-vline( vline => $pos-line );

                    $neg-line.pos = $pos-keep-point;
                    $pos-keep-point.lines{ ph-neg-y } = $neg-line;
                    $point.lines{ ph-neg-y }:delete;
                    $point.lines{ ph-pos-y }:delete;

                    # re-add the line we're keeping
                    self!add-vline( vline => $neg-line );
                }
                else {
                    next;
                }

                %!points{ make-point-key( $point ) }:delete;
                $changed = True;
                next PASS;
            }

            # look for inside corners that can be flipped to outside corners
            POINT: for %!points.values -> $point {
                # only consider if no notes
                next if $point.notes.keys.elems;

                # point has exactly one x-line and exactly one y-line
                unless (
                    ( $point.lines{ ph-pos-x }:exists xor $point.lines{ ph-neg-x }:exists ) and
                    ( $point.lines{ ph-pos-y }:exists xor $point.lines{ ph-neg-y }:exists )
                ) {
                    next;
                }

                # we know that this point is on a corner, but we don't know which direction
                my $x-heading = $point.lines{ ph-pos-x }:exists ?? ph-pos-x !! ph-neg-x;
                my $y-heading = $point.lines{ ph-pos-y }:exists ?? ph-pos-y !! ph-neg-y;

                my $x-line = $point.lines{ $x-heading };
                my $y-line = $point.lines{ $y-heading };

                my $other-x-point = $x-heading == ph-pos-x ?? $x-line.pos !! $x-line.neg;
                my $other-y-point = $y-heading == ph-pos-y ?? $y-line.pos !! $y-line.neg;

                # the points at the other end of these liens also have exactly one x and exactly one y line
                unless (
                    ( $other-x-point.lines{ ph-pos-x }:exists xor $other-x-point.lines{ ph-neg-x }:exists ) and
                    ( $other-x-point.lines{ ph-pos-y }:exists xor $other-x-point.lines{ ph-neg-y }:exists ) and
                    ( $other-y-point.lines{ ph-pos-x }:exists xor $other-y-point.lines{ ph-neg-x }:exists ) and
                    ( $other-y-point.lines{ ph-pos-y }:exists xor $other-y-point.lines{ ph-neg-y }:exists )
                ) {
                    next;
                }

                next if $other-x-point.notes.keys.elems;
                next if $other-y-point.notes.keys.elems;

                # the points at the other end of these lines don't have lines going in the same direction
                #   as any of the lines from our first point
                # we don't have to check the axis that we're connected on
                unless (
                    ( $point.lines{ ph-pos-x }:exists xor $other-y-point.lines{ ph-pos-x }:exists ) and
                    ( $point.lines{ ph-pos-y }:exists xor $other-x-point.lines{ ph-pos-y }:exists )
                ) {
                    next;
                }

                # we've confirmed that we are an "inside corner"
                # now to check the area we're going to move around and make sure it's clear
                for $x-line.neg.x .. $x-line.pos.x -> $x {
                    for $y-line.neg.y .. $y-line.pos.y -> $y {
                        # we don't need to check where the known points and lines are
                        # these are all inline with our inside corner
                        next if $x == $point.x or $y == $point.y;

                        # there can't be lines without points, so looking
                        # for points finds all possible obstructions
                        if %!points{ make-point-key( :$x, :$y ) }:exists {
                            next POINT;
                        }
                    }
                }

                # if we made it this far there were no obstructions and we may proceed
                %!points{ make-point-key( $point ) }:delete;
                self!remove-hline( hline => $x-line );
                self!remove-vline( vline => $y-line );

                $point.x = $other-x-point.x;
                $point.y = $other-y-point.y;

                if $x-heading == ph-pos-x {
                    $other-y-point.lines{ ph-pos-x } = $x-line;
                    $x-line.neg = $other-y-point;

                    $point.lines{ ph-neg-x } = $x-line;
                    $x-line.pos = $point;

                    $point.lines{ ph-pos-x }:delete;
                    $other-x-point.lines{ ph-neg-x }:delete;
                }
                else {
                    $other-y-point.lines{ ph-neg-x } = $x-line;
                    $x-line.pos = $other-y-point;

                    $point.lines{ ph-pos-x } = $x-line;
                    $x-line.neg = $point;

                    $point.lines{ ph-neg-x }:delete;
                    $other-x-point.lines{ ph-pos-x }:delete;
                }

                if $y-heading == ph-pos-y {
                    $other-x-point.lines{ ph-pos-y } = $y-line;
                    $y-line.neg = $other-x-point;

                    $point.lines{ ph-neg-y } = $y-line;
                    $y-line.pos = $point;

                    $point.lines{ ph-pos-y }:delete;
                    $other-y-point.lines{ ph-neg-y }:delete;
                }
                else {
                    $other-x-point.lines{ ph-neg-y } = $y-line;
                    $y-line.pos = $other-x-point;

                    $point.lines{ ph-pos-y } = $y-line;
                    $y-line.neg = $point;

                    $point.lines{ ph-neg-y }:delete;
                    $other-y-point.lines{ ph-pos-y }:delete;
                }

                %!points{ make-point-key( $point ) } = $point;
                self!add-hline( hline => $x-line );
                self!add-vline( vline => $y-line );

                $changed = True;
                next PASS;
            }

            # look for loops that can be brought in
            #   outside corners adjacent to an outside corner
            #   (or inside corner adjacent to an inside corner, it doesn't matter)
            #   scan inside the loop for obstructions
            for %!points.values -> $point {
                # only consider if no notes
                next if $point.notes.keys.elems;

                # point has exactly one x-line and exactly one y-line
                unless (
                    ( $point.lines{ ph-pos-x }:exists xor $point.lines{ ph-neg-x }:exists ) and
                    ( $point.lines{ ph-pos-y }:exists xor $point.lines{ ph-neg-y }:exists )
                ) {
                    next;
                }

                # we know that this point is on a corner, but we don't know which direction
                my $x-heading = $point.lines{ ph-pos-x }:exists ?? ph-pos-x !! ph-neg-x;
                my $y-heading = $point.lines{ ph-pos-y }:exists ?? ph-pos-y !! ph-neg-y;

                my $x-line = $point.lines{ $x-heading };
                my $y-line = $point.lines{ $y-heading };

                my $other-x-point = $x-heading == ph-pos-x ?? $x-line.pos !! $x-line.neg;
                my $other-y-point = $y-heading == ph-pos-y ?? $y-line.pos !! $y-line.neg;

                # first we consider the x-line
                if (
                    ( $other-x-point.lines{ ph-pos-x }:exists xor $other-x-point.lines{ ph-neg-x }:exists ) and
                    ( $other-x-point.lines{ ph-pos-y }:exists xor $other-x-point.lines{ ph-neg-y }:exists ) and
                    ( $other-x-point.lines{ $y-heading }:exists ) and
                    ( $other-x-point.notes.keys.elems == 0 )
                ) {
                    # another corner, bending the same way on the y axis as we are
                    my $other-y-line = $other-x-point.lines{ $y-heading };

                    my $shared-y = $point.y;
                    my $scan-distance = min( $y-line.pos.y - $y-line.neg.y, $other-y-line.pos.y - $other-y-line.neg.y );

                    # we don't want to scan where the lines are
                    my $scan-min-x = $x-line.neg.x + 1;
                    my $scan-max-x = $x-line.pos.x - 1;

                    my $Δy = %movementChart{ $y-heading }< Δy >;

                    my $scan-y = $point.y;

                    my $moved-distance = 0;

                    # we can freely move up to one less than the scan distance
                    # because there can't be any points along the side
                    # so as long as the middle is clear, we're good
                    # but we know that at scan-distance there is at least one point
                    # along the side
                    DELTAY: while $moved-distance < ( $scan-distance - 1 ) {
                        $scan-y += $Δy;

                        for $scan-min-x .. $scan-max-x -> $scan-x {
                            # if there are no points then there can't be anything else
                            if %!points{ make-point-key( x => $scan-x, y => $scan-y ) }:exists {
                                last DELTAY;
                            }
                        }

                        $moved-distance += 1;
                    }

                    if $moved-distance {
                        self!remove-hline( hline => $x-line );
                        self!remove-vline( vline => $y-line );
                        self!remove-vline( vline => $other-y-line );

                        %!points{ make-point-key( $point ) }:delete;
                        %!points{ make-point-key( $other-x-point ) }:delete;

                        $point.y += $moved-distance * $Δy;
                        $other-x-point.y += $moved-distance * $Δy;

                        %!points{ make-point-key( $point ) } = $point;
                        %!points{ make-point-key( $other-x-point ) } = $other-x-point;

                        self!add-hline( hline => $x-line );
                        self!add-vline( vline => $y-line );
                        self!add-vline( vline => $other-y-line );

                        $changed = True;
                    }

                    # this can be true even when $moved-distance is 0
                    if $moved-distance == ( $scan-distance - 1 ) {
                        $scan-y = $point.y + $Δy;

                        # we've shrunk all the way up to at least one point
                        # (or maybe we were already there)
                        # now we have to decide if we're going to merge

                        # won't merge if any point in a destination location has notes
                        # won't merge if there's a line between points in the destination locations
                        #  (we are still going to check for points in between, so we only have to look for that line on one end)
                        my $dest-point-key = make-point-key( x => $point.x, y => $scan-y );
                        my $other-dest-point-key = make-point-key( x => $other-x-point.x, y => $scan-y );
                        if (
                            (
                                ( not %!points{ $dest-point-key }:exists ) or
                                (
                                    ( %!points{ $dest-point-key }.notes.keys.elems == 0 ) and
                                    ( not %!points{ $dest-point-key }.lines{ $x-heading }:exists )
                                )
                            ) and
                            (
                                ( not %!points{ $other-dest-point-key }:exists ) or
                                ( %!points{ $other-dest-point-key }.notes.keys.elems == 0 )
                            )
                        ) {
                            my $clear = True;

                            for $scan-min-x .. $scan-max-x -> $scan-x {
                                if %!points{ make-point-key( x => $scan-x, y => $scan-y ) }:exists {
                                    $clear = False;
                                    last;
                                }
                            }

                            if $clear {
                                # even if the lines aren't being completely removed they still need to be reindexed
                                self!remove-hline( hline => $x-line );
                                self!remove-vline( vline => $y-line );
                                self!remove-vline( vline => $other-y-line );

                                if %!points{ $dest-point-key }:exists {
                                    my $dest-point = %!points{ $dest-point-key };

                                    # edit $dest-point to refer to $x-line
                                    # edit $x-line to refer to $dest-point
                                    if $x-heading == ph-pos-x {
                                        $dest-point.lines{ ph-pos-x } = $x-line;

                                        $x-line.neg = $dest-point;
                                    }
                                    else {
                                        $dest-point.lines{ ph-neg-x } = $x-line;

                                        $x-line.pos = $dest-point;
                                    }

                                    # edit $dest-point to not refer to $y-line
                                    if $y-heading == ph-pos-y {
                                        $dest-point.lines{ ph-neg-y }:delete;
                                    }
                                    else {
                                        $dest-point.lines{ ph-pos-y }:delete;
                                    }

                                    %!points{ make-point-key( $point ) }:delete;
                                }
                                else {
                                    # edit y of $point
                                    %!points{ make-point-key( $point ) }:delete;
                                    $point.y += $Δy;
                                    %!points{ make-point-key( $point ) } = $point;

                                    # restore the line after the edit
                                    self!add-vline( vline => $y-line );
                                }

                                if %!points{ $other-dest-point-key }:exists {
                                    my $other-dest-point = %!points{ $other-dest-point-key };

                                    # edit $other-dest-point to refer to $x-line
                                    # edit $x-line to refer to $other-dest-point
                                    if $x-heading == ph-pos-x {
                                        $other-dest-point.lines{ ph-neg-x } = $x-line;

                                        $x-line.pos = $other-dest-point;
                                    }
                                    else {
                                        $other-dest-point.lines{ ph-pos-x } = $x-line;

                                        $x-line.neg = $other-dest-point;
                                    }

                                    # edit $other-dest-point to not refer to $other-y-line
                                    if $y-heading == ph-pos-y {
                                        $other-dest-point.lines{ ph-neg-y }:delete;
                                    }
                                    else {
                                        $other-dest-point.lines{ ph-pos-y }:delete;
                                    }

                                    %!points{ make-point-key( $other-x-point ) }:delete;
                                }
                                else {
                                    # edit y of $other-x-point
                                    %!points{ make-point-key( $other-x-point ) }:delete;
                                    $other-x-point.y += $Δy;
                                    %!points{ make-point-key( $other-x-point ) } = $other-x-point;

                                    # restore the line after the edit
                                    self!add-vline( vline => $other-y-line );
                                }

                                self!add-hline( hline => $x-line );
                                $changed = True;
                            }
                        }
                    }

                    if $changed {
                        next PASS;
                    }
                }

                # then we consider the y-line
                if (
                    ( $other-y-point.lines{ ph-pos-y }:exists xor $other-y-point.lines{ ph-neg-y }:exists ) and
                    ( $other-y-point.lines{ ph-pos-x }:exists xor $other-y-point.lines{ ph-neg-x }:exists ) and
                    ( $other-y-point.lines{ $x-heading }:exists ) and
                    ( $other-y-point.notes.keys.elems == 0 )
                ) {
                    # another corner, bending the same way on the x axis as we are
                    my $other-x-line = $other-y-point.lines{ $x-heading };

                    my $shared-x = $point.x;
                    my $scan-distance = min( $x-line.pos.x - $x-line.neg.x, $other-x-line.pos.x - $other-x-line.neg.x );

                    # we don't want to scan where the lines are
                    my $scan-min-y = $y-line.neg.y + 1;
                    my $scan-max-y = $y-line.pos.y - 1;

                    my $Δx = %movementChart{ $x-heading }< Δx >;

                    my $scan-x = $point.x;

                    my $moved-distance = 0;

                    # we can freely move up to one less than the scan distance
                    # because there can't be any points along the side
                    # so as long as the middle is clear, we're good
                    # but we know that at scan-distance there is at least one point
                    # along the side
                    DELTAX: while $moved-distance < ( $scan-distance - 1 ) {
                        $scan-x += $Δx;

                        for $scan-min-y .. $scan-max-y -> $scan-y {
                            # if there are no points then there can't be anything else
                            if %!points{ make-point-key( x => $scan-x, y => $scan-y ) }:exists {
                                last DELTAX;
                            }
                        }

                        $moved-distance += 1;
                    }

                    if $moved-distance {
                        self!remove-vline( vline => $y-line );
                        self!remove-hline( hline => $x-line );
                        self!remove-hline( hline => $other-x-line );

                        %!points{ make-point-key( $point ) }:delete;
                        %!points{ make-point-key( $other-y-point ) }:delete;

                        $point.x += $moved-distance * $Δx;
                        $other-y-point.x += $moved-distance * $Δx;

                        %!points{ make-point-key( $point ) } = $point;
                        %!points{ make-point-key( $other-y-point ) } = $other-y-point;

                        self!add-vline( vline => $y-line );
                        self!add-hline( hline => $x-line );
                        self!add-hline( hline => $other-x-line );

                        $changed = True;
                    }

                    # this can be true even when $moved-distance is 0
                    if $moved-distance == ( $scan-distance - 1 ) {
                        $scan-x = $point.x + $Δx;

                        # we've shrunk all the way up to at least one point
                        # (or maybe we were already there)
                        # now we have to decide if we're going to merge

                        # won't merge if any point in a destination location has notes
                        # won't merge if there's a line between points in the destination locations
                        #  (we are still going to check for points in between, so we only have to look for that line on one end)
                        my $dest-point-key = make-point-key( x => $scan-x, y => $point.y );
                        my $other-dest-point-key = make-point-key( x => $scan-x, y => $other-y-point.y );
                        if (
                            (
                                ( not %!points{ $dest-point-key }:exists ) or
                                (
                                    ( %!points{ $dest-point-key }.notes.keys.elems == 0 ) and
                                    ( not %!points{ $dest-point-key }.lines{ $y-heading }:exists )
                                )
                            ) and
                            (
                                ( not %!points{ $other-dest-point-key }:exists ) or
                                ( %!points{ $other-dest-point-key }.notes.keys.elems == 0 )
                            )
                        ) {
                            my $clear = True;

                            for $scan-min-y .. $scan-max-y -> $scan-y {
                                if %!points{ make-point-key( x => $scan-x, y => $scan-y ) }:exists {
                                    $clear = False;
                                    last;
                                }
                            }

                            if $clear {
                                # even if the lines aren't being completely removed they still need to be reindexed
                                self!remove-vline( vline => $y-line );
                                self!remove-hline( hline => $x-line );
                                self!remove-hline( hline => $other-x-line );

                                if %!points{ $dest-point-key }:exists {
                                    my $dest-point = %!points{ $dest-point-key };

                                    # edit $dest-point to refer to $y-line
                                    # edit $y-line to refer to $dest-point
                                    if $y-heading == ph-pos-y {
                                        $dest-point.lines{ ph-pos-y } = $y-line;

                                        $y-line.neg = $dest-point;
                                    }
                                    else {
                                        $dest-point.lines{ ph-neg-y } = $y-line;

                                        $y-line.pos = $dest-point;
                                    }

                                    # edit $dest-point to not refer to $other-x-line
                                    if $x-heading == ph-pos-x {
                                        $dest-point.lines{ ph-neg-x }:delete;
                                    }
                                    else {
                                        $dest-point.lines{ ph-pos-x }:delete;
                                    }

                                    %!points{ make-point-key( $point ) }:delete;
                                }
                                else {
                                    # edit x of $point
                                    %!points{ make-point-key( $point ) }:delete;
                                    $point.x += $Δx;
                                    %!points{ make-point-key( $point ) } = $point;

                                    # restore the line after the edit
                                    self!add-hline( hline => $x-line );
                                }

                                if %!points{ $other-dest-point-key }:exists {
                                    my $other-dest-point = %!points{ $other-dest-point-key };

                                    # edit $other-dest-point to refer to $y-line
                                    # edit $y-line to refer to $other-dest-point
                                    if $y-heading == ph-pos-y {
                                        $other-dest-point.lines{ ph-neg-y } = $y-line;

                                        $y-line.pos = $other-dest-point;
                                    }
                                    else {
                                        $other-dest-point.lines{ ph-pos-y } = $y-line;

                                        $y-line.neg = $other-dest-point;
                                    }

                                    # edit $other-dest-point to not refer to $other-x-line
                                    if $x-heading == ph-pos-x {
                                        $other-dest-point.lines{ ph-neg-x }:delete;
                                    }
                                    else {
                                        $other-dest-point.lines{ ph-pos-x }:delete;
                                    }

                                    %!points{ make-point-key( $other-y-point ) }:delete;
                                }
                                else {
                                    # edit x of $other-y-point
                                    %!points{ make-point-key( $other-y-point ) }:delete;
                                    $other-y-point.x += $Δx;
                                    %!points{ make-point-key( $other-y-point ) } = $other-y-point;

                                    # restore the line after the edit
                                    self!add-hline( hline => $other-x-line );
                                }

                                self!add-vline( vline => $y-line );
                                $changed = True;
                            }
                        }
                    }

                    if $changed {
                        next PASS;
                    }
                }
            }
        } while $changed;
    }

    # returns the current grid size as a coordinate pair
    method get-grid-size( --> Coordinate ) {
        return \( x => max( %!points.values.map( { $_.x } ) ), y => max( %!points.values.map( { $_.y } ) ) );
    };

    method get-num-points( --> Int ) {
        return %!points.elems;
    }

    # returns the current grid location of the plotting head as a coordinate pair
    method get-head-location( --> Coordinate ) {
        return \( x => $!head-x, y => $!head-y );
    };

    # returns the current heading
    method get-heading( --> Heading ) {
        return $!heading;
    };
}

