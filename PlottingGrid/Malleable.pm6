use v6;

unit module PlottingGrid::Malleable:ver<1>:auth<Brian Conry (brian@theconrys.com)>;

# this is a draft for implementing a malleable plotting grid,
# where by "plotting grid" I mean:
#   a square grid, with lines at unit intervals
#   a plotting head that moves only along the lines from intersectino to intersection
#   the plotting head leaves a marked trail behind it and knows its current direction of motion
#   noted points may be made at the intersection of two lines
# and by malleable" I mean that it's possible to insert or remove rows or columns in the grid,
#   insertion has the restriction that the insertion happens logically between the lines of the grid,
#       this allows the existing plot to be unambiguously stretched preserving its mathmatical topology
#       automatic expansion at the edges, shifting everything as necessary to keep the lowest corner at (0,0)
#   there is a method, de-encroach, that automatically inserts rows/columns into the grid to ensure
#       that there is an empty row/column on the grid between parrallel plotted lines
#   removal isn't as arbitrary, however.  there is a method, condense, that removes rows/columns
#       that contain only of auto-marks that don't turn.  if de-encroach is used, care must be taken
#       to not plot something in a row/column that exists for spacing.

# plotting uses Unicode box drawing glyphs by default

# noted points use glyphs supplied by the caller, with optional annotations

# the intended initial use for this plotting grid additionally requires that it be clonable

# TODO
#    add method for simplifying drawn lines? (i.e. removing concave sections)

# TODO
#    add support for coloring marks and annotations in a way that doesn't count against the .chars

# headings have to be absolute (the only relative heading is "ahead", since we don't also have a separate Facing)
enum Heading is export <ph-invalid ph-pos-x ph-pos-y ph-neg-x ph-neg-y>;

# directions could be absolute, but we have chosen to make them relative to an existing Heading
enum Direction is export <pd-invalid pd-left pd-ahead pd-right pd-back>;

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
        pd-back => ph-pos-x,
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

# heading -> direction of movement
# TODO some means to let these be customized
my %lineGlyphs = (
    ph-pos-x => {
        pd-left  => '┘',
        ph-pos-y => '┘',
        pd-ahead => '─',
        ph-pos-x => '─',
        pd-right => '┐',
        ph-neg-y => '┐',
        pd-back  => '─',
        ph-neg-x => '─',
        stop     => '╴',
    },
    ph-pos-y => {
        pd-left  => '┐',
        ph-neg-x => '┐',
        pd-ahead => '│',
        ph-pos-y => '│',
        pd-right => '┌',
        ph-pos-x => '┌',
        pd-back  => '│',
        ph-neg-y => '│',
        stop     => '╷',
    },
    ph-neg-x => {
        pd-left  => '┌',
        ph-neg-y => '┌',
        pd-ahead => '─',
        ph-neg-x => '─',
        pd-right => '└',
        ph-pos-y => '└',
        pd-back  => '─',
        ph-pos-x => '─',
        stop     => '╶',
    },
    ph-neg-y => {
        pd-left  => '└',
        ph-pos-x => '└',
        pd-ahead => '│',
        ph-neg-y => '│',
        pd-right => '┘',
        ph-neg-x => '┘',
        pd-back  => '│',
        ph-pos-y => '│',
        stop     => '╵',
    },
    start => {
        ph-pos-x => '╶',
        ph-pos-y => '╵',
        ph-neg-x => '╴',
        ph-neg-y => '╷',
    },
    dot   => '·',
    empty => ' ',
);

class Grid is export {
    # because of the need to track drawn lines between the points on the grid, 
    # there have to be rows and columns of cells for them.
    has @!cells;
    has %!annotation-catalog;

    # these are cell coordinates, not grid coordinates
    has $!head-x;
    has $!head-y;
    has Heading $!heading;
    has Heading $!entered-going;

    # new object from scratch
    submethod BUILD() {
        @!cells = {} xx 3 xx 3; # grid point (1,1) and the margins around it
        @!cells[1][1]<auto-mark> = %lineGlyphs<dot>;
        $!head-x = 1;
        $!head-y = 1;
        $!heading = ph-pos-x;
        $!entered-going = Nil;
    };

    method !rebind-privates( :@cells is copy, :%annotation-catalog is copy, --> Nil ) {
        @!cells := @cells.deepmap(-> $c is copy { $c } ).Array;
        %!annotation-catalog := %annotation-catalog;
    }

    method clone(--> Grid) {
        my $clone = callsame;

        $clone!rebind-privates( :@!cells, :%!annotation-catalog );

        return $clone;
    }

    # the logical grid coords need converted to the implementation cell coords
    my sub grid-coord-to-cell-coord( Int:D :$n, --> Int ) {
        return 1 + ( $n - 1 ) * 2;
    }

    my sub cell-coord-to-grid-coord( Int:D :$n, --> Int ) {
        fail "cell coord not on the grid" unless $n % 2;

        return Int( ( $n + 1 ) / 2 );
    }

    # insert two columns, "stretching" (cloning) the contents at the named coordinate,
    # which MUST identify a column between grid points
    method !stretch-at-cell-x-coord( Int:D :$x, --> Nil ) {
        fail "(Grid internal error) invalid stretch-at-cell-x-coord x: $x" if $x % 2 || $x > @!cells.elems || $x < 0;

        @!cells.splice( $x, 0, @!cells[$x].deepmap( -> $c is copy { $c } ), @!cells[$x].deepmap( -> $c is copy { $c } ) );

        if $!head-x > $x {
            $!head-x += 2;
        }

        return;
    }

    # insert two rows, "stretching" (cloning) the contents at the named coordinate,
    # which MUST identify a row between grid points
    method !stretch-at-cell-y-coord( Int:D :$y, --> Nil ) {
        fail "(Grid internal error) invalid stretch-at-cell-y-coord y: $y" if $y % 2 || $y > @!cells[0].elems || $y < 0;

        for @!cells -> $row is rw {
            # $row is a List so we can't .splice it
            $row = ( |$row[ 0 ..^ $y ], $row[$y].deepmap(->$c is copy {$c}), $row[$y].deepmap(->$c is copy {$c}), |$row[ $y .. * ] );
        }

        if $!head-y > $y {
            $!head-y += 2;
        }

        return;
    }

    # returns the new grid x size
    multi method expand-before( Int:D :$x, --> Int ) {
        fail "invalid x: $x" if $x <= 0 || $x > ( @!cells.elems / 2 );

        my $cell-x = grid-coord-to-cell-coord( n => $x );

        self!stretch-at-cell-x-coord( x => $cell-x - 1 );

        return cell-coord-to-grid-coord( n => @!cells.end - 1 );
    };

    # returns the new grid y size
    multi method expand-before( Int:D :$y, --> Int ) {
        fail "invalid y: $y" if $y <= 0 || $y > ( @!cells[0].elems / 2 );

        my $cell-y = grid-coord-to-cell-coord( n => $y );

        self!stretch-at-cell-y-coord( y => $cell-y - 1 );

        return cell-coord-to-grid-coord( n => @!cells[0].end - 1 );
    };

    # returns the new grid x size
    multi method expand-after( Int:D :$x, --> Int ) {
        return self.expand-before( x => $x + 1 );
    };

    # returns the new grid y size
    multi method expand-after( Int:D :$y, --> Int ) {
        return self.expand-before( y => $y + 1 );
    };

    # TODO add option to add axis
    # returns a list of strings
    method render-to-strings( Bool:D :$with-annotations is copy = True, --> List ) {
        my $max-annotation-width = 0;

        if $with-annotations {
            # clean up overwritten annotations
            for %!annotation-catalog.pairs -> $p {
                if $p.value == 0 {
                    %!annotation-catalog{ $p.key }:delete;
                }
            }

            $max-annotation-width = max( %!annotation-catalog.keys.map: { $_.chars } );

            # if there aren't any, pretend that we weren't asked to render them
            # max returns -Inf for an empty list
            if $max-annotation-width <= 0 {
                $with-annotations = False;
                $max-annotation-width = 0;
            }
        }

        my $fmt-string = '%' ~ $max-annotation-width ~ 's';
        my $empty-annotation = %lineGlyphs<empty> x $max-annotation-width;

        my @rendered-rows;

        # cell (0,0) is in the lower left corner, for congruency with the mathmatical convention
        my $max-grid-x = ( @!cells.end / 2 );
        my $max-grid-y = ( @!cells[0].end / 2 );

        # iterate by logical coords
        for 1 .. $max-grid-y -> $grid-y {
            my @annotation-u-data;
            my @grid-row-data;
            my @annotation-d-data;

            my $cell-y = grid-coord-to-cell-coord( n => $grid-y );

            for 1 .. $max-grid-x -> $grid-x {
                my $cell-x = grid-coord-to-cell-coord( n => $grid-x );

                my $target-cell = @!cells[ $cell-x     ][ $cell-y ];
                my $left-cell   = @!cells[ $cell-x - 1 ][ $cell-y ];
                my $right-cell  = @!cells[ $cell-x + 1 ][ $cell-y ];

                if $with-annotations {
                    if $left-cell<auto-mark>:exists {
                        @grid-row-data.push( $left-cell<auto-mark> x $max-annotation-width );
                    }
                    else {
                        @grid-row-data.push( $empty-annotation );
                    }
                }

                if $target-cell<mark>:exists {
                    @grid-row-data.push( $target-cell<mark> );
                }
                elsif $target-cell<auto-mark>:exists {
                    @grid-row-data.push( $target-cell<auto-mark> );
                }
                else {
                    @grid-row-data.push( %lineGlyphs<empty> );
                }

                if $with-annotations {
                    if $right-cell<auto-mark>:exists {
                        @grid-row-data.push( $right-cell<auto-mark> x $max-annotation-width );
                    }
                    else {
                        @grid-row-data.push( $empty-annotation );
                    }
                }

                if $with-annotations {
                    my $up-cell   = @!cells[ $cell-x ][ $cell-y + 1 ];
                    my $down-cell = @!cells[ $cell-x ][ $cell-y - 1 ];

                    if $target-cell<ul-annotation>:exists {
                        @annotation-u-data.push( $fmt-string.sprintf( $target-cell<ul-annotation> ) );
                    }
                    else {
                        @annotation-u-data.push( $empty-annotation );
                    }

                    if $up-cell<auto-mark>:exists {
                        @annotation-u-data.push( $up-cell<auto-mark> );
                    }
                    else {
                        @annotation-u-data.push( %lineGlyphs<empty> );
                    }

                    if $target-cell<ur-annotation>:exists {
                        @annotation-u-data.push( $fmt-string.sprintf( $target-cell<ur-annotation> ) );
                    }
                    else {
                        @annotation-u-data.push( $empty-annotation );
                    }

                    if $target-cell<dl-annotation>:exists {
                        @annotation-d-data.push( $fmt-string.sprintf( $target-cell<dl-annotation> ) );
                    }
                    else {
                        @annotation-d-data.push( $empty-annotation );
                    }

                    if $down-cell<auto-mark>:exists {
                        @annotation-d-data.push( $down-cell<auto-mark> );
                    }
                    else {
                        @annotation-d-data.push( %lineGlyphs<empty> );
                    }

                    if $target-cell<dr-annotation>:exists {
                        @annotation-d-data.push( $fmt-string.sprintf( $target-cell<dr-annotation> ) );
                    }
                    else {
                        @annotation-d-data.push( $empty-annotation );
                    }
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

        return @rendered-rows;
    }

    method render-to-multiline-string( Bool:D :$with-annotations = True, --> Str ) {
        return self.render-to-strings( :$with-annotations ).join("\n") ~ "\n";
    }

    # (re)mark the current cell, with optional annotation(s) and/or user-data
    # a new annotation that is an empty string will remove any existing annotation
    # N.B. there is no way to remove user data except by replacing it with other defined data
    # returns a copy of the cell markings
    method plot( 
        Str :$mark,
        Str :$ur-annotation,
        Str :$dr-annotation,
        Str :$dl-annotation,
        Str :$ul-annotation,
        :$user-data,
        --> Hash
    ) {
        my $cell = @!cells[ $!head-x ][ $!head-y ];

        if $mark.DEFINITE {
            fail "invalid mark, '$mark', must be a single glyph or the empty string" if $mark.chars > 1;

            if $mark eq '' {
                $cell<mark>:delete;
            }
            else {
                $cell<mark> = $mark;
            }
        }

        for 'ur', $ur-annotation, 'dr', $dr-annotation, 'dl', $dl-annotation, 'ul', $ul-annotation -> $pos, $value {
            my $key = $pos ~ '-annotation';

            if $value.DEFINITE {
                if $cell{ $key }:exists {
                    %!annotation-catalog{ $cell{ $key } }--;
                }

                if $value eq '' {
                    $cell{ $key }:delete;
                }
                else {
                    $cell{ $key } = $value;

                    %!annotation-catalog{ $value }++;
                }
            }
        }

        if $user-data.DEFINITE {
            $cell<user-data> = $user-data;
        }

        return Hash.new( $cell.pairs );
    };

    # returns the new absolute heading
    multi method turn( Direction:D :$relative, --> Heading ) {
        $!heading = %turnChart{ $!heading }{ $relative };

        return $!heading;
    }

    # returns the new absolute heading
    multi method turn( Heading:D :$absolute, --> Heading ) {
        $!heading = $absolute;

        return $!heading;
    }

    # returns the new grid (x,y)
    method advance( Bool:D :$plotting = True, --> Coordinate ) {
        my $Δx = %movementChart{ $!heading }< Δx >;
        my $Δy = %movementChart{ $!heading }< Δy >;

        my $pilot-x = $!head-x + 2 * $Δx;
        my $pilot-y = $!head-y + 2 * $Δy;

        if $pilot-x < 1 {
            self!stretch-at-cell-x-coord( x => $!head-x - 1 );
        }
        elsif $pilot-x >= @!cells.elems {
            self!stretch-at-cell-x-coord( x => $!head-x + 1 );
        }

        if $pilot-y < 1 {
            self!stretch-at-cell-y-coord( y => $!head-y - 1 );
        }
        elsif $pilot-y >= @!cells[0].elems {
            self!stretch-at-cell-y-coord( y => $!head-y + 1 );
        }

        my $start-cell = @!cells[ $!head-x ][ $!head-y ];

        if $plotting {
            if $!entered-going.defined {
                $start-cell<auto-mark> = %lineGlyphs{ $!entered-going }{ $!heading };
            }
            else {
                $start-cell<auto-mark> = %lineGlyphs<start>{ $!heading };
            }
        }

        $!head-x += $Δx;
        $!head-y += $Δy;

        if $plotting {
            @!cells[ $!head-x ][ $!head-y ]<auto-mark> = %lineGlyphs{ $!heading }{ $!heading };
        }

        $!head-x += $Δx;
        $!head-y += $Δy;

        if $plotting {
            @!cells[ $!head-x ][ $!head-y ]<auto-mark> = %lineGlyphs{ $!heading }<stop>;
            $!entered-going = $!heading;
        }
        else {
            # if we aren't plotting then there's no mark leading into this cell,
            # which is effectively the same as having come here from nowhere
            $!entered-going = Nil;
        }

        return \( x => cell-coord-to-grid-coord( n => $!head-x ), y => cell-coord-to-grid-coord( n => $!head-y ) );
    }

    # move the head to absolute grid coordinates
    # returns nothing
    multi method seek( Int:D :$x, Int:D :$y, --> Nil ) {
        self.seek( Δx => $x - $!head-x, Δy => $y - $!head-y );

        return;
    }

    # move the head to a relative (grid) offset
    # returns the new grid (x,y)
    multi method seek( Int:D :$Δx, Int:D :$Δy, --> Coordinate ) {
        my $old-heading = $!heading;

        while $Δx < 0 {
            $!heading = ph-neg-x;
            self.advance( plotting => False );
            $Δx++;
        }

        while $Δx > 0 {
            $!heading = ph-pos-x;
            self.advance( plotting => False );
            $Δx--;
        }

        while $Δy < 0 {
            $!heading = ph-neg-y;
            self.advance( plotting => False );
            $Δy++;
        }

        while $Δy > 0 {
            $!heading = ph-pos-y;
            self.advance( plotting => False );
            $Δy--;
        }

        $!heading = $old-heading;

        return \( x => cell-coord-to-grid-coord( n => $!head-x ), y => cell-coord-to-grid-coord( n => $!head-y ) );
    }

    # returns a copy of the cell markings in the first non-empty cell in the specified direction
    multi method look( Direction:D :$relative, Num:D :$horizon = Inf, --> Hash ) {
        return self.look( absolute => %turnChart{ $!heading }{ $relative } );
    }

    # returns a copy of the cell markings in the first non-empty cell in the specified direction
    multi method look( Heading:D :$absolute, Num:D :$horizon = Inf, --> Hash ) {
        my $Δx = %movementChart{ $absolute }< Δx >;
        my $Δy = %movementChart{ $absolute }< Δy >;

        my $look-x = $!head-x + $Δx;
        my $look-y = $!head-y + $Δy;

        my $distance = 1;

        # the first row/column and the last row/column should always be empty margin
        # so there's no reason to look at the cell stored in them
        while
            $look-x > 0 and
            $look-y > 0 and
            $look-x < @!cells.end and
            $look-y < @!cells[0].end and
            $distance <= $horizon
        {
            my $cell = @!cells[$look-x][$look-y];

            if $cell.elems {
                my $copy = Hash.new( $cell.pairs );
                # we've been counting in cell coords, not grid coords
                # we don't want to convert this because it may be odd and may
                # result in a fraction, and that's OK.
                $copy<distance> = $distance / 2;
                return $copy;
            }

            $look-x += $Δx;
            $look-y += $Δy;

            $distance++;
        }

        return Nil;
    };

    # returns nothing
    method de-encroach( --> Nil ) {
        # iterate the rows and columns looking for grid-adjacent '─' or '│' in the
        # in-between cells and add space between them - this may be useful for some
        # plotting algorithms.

        my $x-expand = SetHash.new;
        my $y-expand = SetHash.new;

        for 1 ..^ @!cells.end -> $cell-x {
            for 1 ..^ @!cells[0].end -> $cell-y {
                if $cell-x % 2 == 0 and $cell-y > 1 and $cell-y % 2 != 0 {
                    if not $y-expand{ $cell-y - 1 } {
                        if
                            @!cells[ $cell-x ][ $cell-y ]<auto-mark>:exists and
                            @!cells[ $cell-x ][ $cell-y ]<auto-mark> eq '─' and
                            @!cells[ $cell-x ][ $cell-y - 2 ]<auto-mark>:exists and
                            @!cells[ $cell-x ][ $cell-y - 2 ]<auto-mark> eq '─'
                        {
                            $y-expand{ $cell-y - 1 } = True;
                        }
                    }
                }

                if $cell-y % 2 == 0 and $cell-x > 1 and $cell-x % 2 != 0 {
                    if not $x-expand{ $cell-x - 1 } {
                        if
                            @!cells[ $cell-x ][ $cell-y ]<auto-mark>:exists and
                            @!cells[ $cell-x ][ $cell-y ]<auto-mark> eq '│' and
                            @!cells[ $cell-x - 2 ][ $cell-y ]<auto-mark>:exists and
                            @!cells[ $cell-x - 2 ][ $cell-y ]<auto-mark> eq '│'
                        {
                            $x-expand{ $cell-x - 1 } = True;
                        }
                    }
                }
            }
        }

        for $x-expand.keys.sort.reverse -> $x {
            self!stretch-at-cell-x-coord( :$x );
        }

        for $y-expand.keys.sort.reverse -> $y {
            self!stretch-at-cell-y-coord( :$y );
        }

        return;
    }

    # returns nothing
    method condense( --> Nil ) {
        # de-encroaching adds extraneous rows and columns, this removes them
        # intended to be done after all plotting is finished.

        # if adding the rows/columns is "stretching" the existing data,
        # this condensing is folding over the rows/columns that don't alter topology
        # unlike the stretching, though, folding isn't done while doing other operations

        my $max-grid-x = ( @!cells.end / 2 );
        my $max-grid-y = ( @!cells[0].end / 2 );

        # while these are tracked by cell coordinate, the coordiates are
        # iterated by grid coordinate and imply the elimination of the following
        # between-the-grid cell row/column along with the grid row/column
        my $can-eliminate-cell-x = SetHash.new;
        my $can-eliminate-cell-y = SetHash.new;

        # we can't find "proof" that a grid line can be eliminated,
        # we can only find a lack of proof that it needs to be kept.
        # so we mark them all as disposable and unmark them when we find a reason to keep it.
        for 1 .. $max-grid-x -> $grid-x {
            $can-eliminate-cell-x{ grid-coord-to-cell-coord( n => $grid-x ) } = True;
        }
        for 1 .. $max-grid-y -> $grid-y {
            $can-eliminate-cell-y{ grid-coord-to-cell-coord( n => $grid-y ) } = True;
        }

        for 1 .. $max-grid-x -> $grid-x {
            my $cell-x = grid-coord-to-cell-coord( n => $grid-x );

            for 1 .. $max-grid-y -> $grid-y {
                my $cell-y = grid-coord-to-cell-coord( n => $grid-y );

                if $can-eliminate-cell-x{ $cell-x } or $can-eliminate-cell-y{ $cell-y } {
                    my $cell = @!cells[ $cell-x ][ $cell-y ];

                    if
                        $cell<mark>:exists or
                        $cell<ul-annotation>:exists or
                        $cell<ur-annotation>:exists or
                        $cell<dr-annotation>:exists or
                        $cell<dl-annotation>:exists or
                        (
                            $cell<auto-mark>:exists and
                            $cell<auto-mark> ne '─' and
                            $cell<auto-mark> ne '│'
                        )
                    {
                        $can-eliminate-cell-x{ $cell-x } = False;
                        $can-eliminate-cell-y{ $cell-y } = False;
                    }
                }
            }
        }

        for $can-eliminate-cell-x.keys.sort.reverse -> $x {
            @!cells.splice( $x, 2 );
        }

        for $can-eliminate-cell-y.keys.sort.reverse -> $y {
            for @!cells -> $row is rw {
                # $row is a List so we can't .splice it
                $row = ( |$row[ 0 ..^ $y ], |$row[ ( $y + 1 ) ^.. * ] );
            }
        }

        return;
    }

    # returns the current grid size as a coordinate pair
    method get-grid-size( --> Coordinate ) {
        return \( x => cell-coord-to-grid-coord( n => @!cells.end - 1 ), y => cell-coord-to-grid-coord( n => @!cells[0].end - 1 ) );
    }

    # returns the current grid location of the plotting head as a coordinate pair
    method get-head-location( --> Coordinate ) {
        return \( x => cell-coord-to-grid-coord( n => $!head-x ), y => cell-coord-to-grid-coord( n => $!head-y ) );
    }

    # returns the current heading
    method get-heading( --> Heading ) {
        return $!heading;
    }

    # TODO
    # This method removes concave/convex features from lines when there are no obstructions
    # this will likely require tracking segments added between one plot and another
    # returns nothing
    method straighten(--> Nil) { ... }
};

