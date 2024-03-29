use v6;

use lib <.>;

use PlottingGrid::Malleable;
use Knot::Dowker;
use Knot::Tangle;

CONTROL { when CX::Warn { note $_; exit 1 } }

=begin comment
potentially useful line drawing characters:
    ─ u+2500
    │ u+2502
    ═ u+2550
    ║ u+2551
    ┌ u+250C
    ╒ u+2552
    ╓ u+2553
    ╔ u+2554
    ┐ u+2510
    ╕ u+2555
    ╖ u+2556
    ╗ u+2557
    └ u+2514
    ╘ u+2558
    ╙ u+2559
    ╚ u+255A
    ┘ u+2518
    ╛ u+255B
    ╜ u+255C
    ╝ u+255D
    ╪ u+256A
    ╫ u+256B

    ╭ u+256d
    ╮ u+256e
    ╯ u+256f
    ╰ u+2570

    ↺ u+21ba
    ↻ u+21bb

    not actually useful:
    ┼ u+253C
    ╬ u+256C

possible styles
    preferred:
        transition inline - compact
        transition inline - N|0,→

    transition inline - compact
       +++++
      +┌──┐
      +│┌┐│
      +└╪╫╪┐
      + │└┘│
      + └──┘

    transition inline - N|0
       l+rl+rl+rl+rl+
      u
      + ┌────────┐
      d │        │
      u │        │
      + │  ┌──┐  │
      d │  │  │  │
      u │ 1│ 5│ 3│
      + └──╪──╫──╪──┐
      d   4│ 2│ 6│  │
      u    │  │  │  │
      +    │  └──┘  │
      d    │        │
      u    │        │
      +    └────────┘

    transition inline - N|0,→
       ll+rrll+rrll+rrll+rrll+
      u
      +  ┌──────────────┐
      d  │              │
      u  │              │
      +  │    ┌────┐    │
      d  │    │    │    │
      u  │  1→│  5↓│  3→│
      +  └────╪────╫────╪────┐
      d     4↑│  2→│  6↑│    │
      u       │    │    │    │
      +       │    └────┘    │
      d       │              │
      u       │              │
      +       └──────────────┘

    transition inline - N|1
       l+r-l+r-l+r-l+r-l+
      u
      + ┌───────────┐
      d │           │
      | │           │
      u │           │
      + │   ┌───┐   │
      d │   │   │   │
      | │   │   │   │
      u │  1│  5│  3│
      + └───╪───╫───╪───┐
      d    4│  2│  6│   │
      |     │   │   │   │
      u     │   │   │   │
      +     │   └───┘   │
      d     │           │
      |     │           │
      u     │           │
      +     └───────────┘

    transition inline - N|1,→
       ll+rr-ll+rr-ll+rr-ll+rr-ll+
      u
      +  ┌─────────────────┐
      d  │                 │
      |  │                 │
      u  │                 │
      +  │     ┌─────┐     │
      d  │     │     │     │
      |  │     │     │     │
      u  │   1→│   5↓│   3→│
      +  └─────╪─────╫─────╪─────┐
      d      4↑│   2→│   6↑│     │
      |        │     │     │     │
      u        │     │     │     │
      +        │     └─────┘     │
      d        │                 │
      |        │                 │
      u        │                 │
      +        └─────────────────┘

    x
       ┌────┐
       │┌─╖ │
       ╘╪╕║╒╪╕
        │└╫┘││
        │ ╙─┘│
        └────┘

    y
       ┌────┐
       │┌─╖ │
       ╘╪╕║ │
        │└╫┐│
        │ ║╘╪╕
        │ ╙─┘│
        └────┘

    z
       ┌──────┐
       │┌──╖┌┐│
       ╘╪╕┌╫┘╘╪╕
        │└┘╙──┘│
        └──────┘

=end comment
# the purpose of plotting is twofold
# + one, to have diagrams of my own generation that I can (hopefully)
#   manipulate by, e.g., coloring segments and crossings that will
#   be eliminated or created by an operation then specifying the
#   position of crossings in subsequent diagrams to maintain similarity
# + two, and this is the most important, to identify the direction of
#   travel along the strand for use in reducing the knot

# The process of plotting requires multiple saved states, so the process requires multiple layers of logic
#
# top layer:
#   decides when to accept a state as being the goal
#   manages the list of possible states
#
# seeking layer:
#   is clonable
#   is associated with a plotting layer (and cloning this layer clones the plotting layer too)
#   looks about the plotting layer to decide where to plot
#
#   Note: this layer should never plot two crossings immediately adjacent to each other - it should always advance twice to keep the result optimally condensable

my enum SeekingPattern <cw ccw>;
my enum PathingStatus <pathing-open pathing-taken pathing-blocked pathing-abandoned>;
my enum PlotGoal <plot-find-first plot-find-best>;

my %arrow-by-heading = (
    ph-pos-x => '→',
    ph-neg-x => '←',
    ph-pos-y => '↑',
    ph-neg-y => '↓',
);
my %mark-by-heading-and-position = (
    ph-pos-x => { over => '─', under => '│' },
    ph-neg-x => { over => '─', under => '│' },
    ph-pos-y => { over => '│', under => '─' },
    ph-neg-y => { over => '│', under => '─' },
);
my %preferences-by-seeking-pattern = (
    cw  => ( pd-right, pd-ahead, pd-left ),
    ccw => ( pd-left, pd-ahead, pd-right ),
);
my %annotation-location-by-position = (
    over  => 'ul-annotation',
    under => 'dl-annotation',
);
my %crossing-directions = (
    ph-pos-x => {
        pd-left => ph-pos-y,
        pd-right => ph-neg-y,
    },
    ph-pos-y => {
        pd-left => ph-neg-x,
        pd-right => ph-pos-x,
    },
    ph-neg-x => {
        pd-left => ph-neg-y,
        pd-right => ph-pos-y,
    },
    ph-neg-y => {
        pd-left => ph-pos-x,
        pd-right => ph-neg-x,
    },
);
# over then under
my %crossing-type-by-headings = (
    ph-pos-x => {
        ph-pos-y => L-plus,
        ph-neg-y => L-minus,
    },
    ph-pos-y => {
        ph-pos-x => L-minus,
        ph-neg-x => L-plus,
    },
    ph-neg-x => {
        ph-pos-y => L-minus,
        ph-neg-y => L-plus,
    },
    ph-neg-y => {
        ph-pos-x => L-plus,
        ph-neg-x => L-minus,
    },
);
my %turnChart = (
    ph-pos-x => {
        pd-left => ph-pos-y,
        pd-ahead => ph-pos-x,
        pd-right => ph-neg-y,
        pd-back => ph-neg-x,
        ph-neg-x => pd-back,
        ph-neg-y => pd-right,
        ph-pos-x => pd-ahead,
        ph-pos-y => pd-left,
    },
    ph-pos-y => {
        pd-left => ph-neg-x,
        pd-ahead => ph-pos-y,
        pd-right => ph-pos-x,
        pd-back => ph-neg-y,
        ph-neg-x => pd-left,
        ph-neg-y => pd-back,
        ph-pos-x => pd-right,
        ph-pos-y => pd-ahead,
    },
    ph-neg-x => {
        pd-left => ph-neg-y,
        pd-ahead => ph-neg-x,
        pd-right => ph-pos-y,
        pd-back => ph-pos-x,
        ph-neg-x => pd-ahead,
        ph-neg-y => pd-left,
        ph-pos-x => pd-back,
        ph-pos-y => pd-right,
    },
    ph-neg-y => {
        pd-left => ph-pos-x,
        pd-ahead => ph-neg-y,
        pd-right => ph-neg-x,
        pd-back => ph-pos-y,
        ph-neg-x => pd-right,
        ph-neg-y => pd-ahead,
        ph-pos-x => pd-left,
        ph-pos-y => pd-back,
    },
);

my $do-seek-debug = False;

sub do-seek( SeekingPattern:D :$seeking-pattern, :$target-segment, Int:D :$seq, Grid:D :$grid! ) {
    if $do-seek-debug {
        say "seeking $seeking-pattern";
    }

    my @trail;

    my $scratch-grid = $grid.clone;

    if $do-seek-debug {
        say "start here";
        say $scratch-grid.render-to-multiline-string;
    }

    $scratch-grid.advance();

    @trail.push( { taken => pd-ahead, pd-left => pathing-blocked, pd-ahead => pathing-taken, pd-right => pathing-blocked } );
    @trail.push( Hash.new );

    # seeking/simplifying goes here
    SEEKING: while @trail {
        my $here = @trail[ *-1 ];

        if $do-seek-debug {
            say "trail has " ~ @trail.elems ~ " steps";

            say "scratch;";
            say $scratch-grid.render-to-multiline-string;

            # backed-out pathing attempts may have rendered some things blocked, so even if we've been
            # here before we still need to look around

            say "at: " ~ $scratch-grid.get-head-location;
            say "heading: " ~ $scratch-grid.get-heading;
        }

        my %vistas;

        # taken will exist if we've backtracked to here, in which case we don't need to look around again
        if $here<taken>:!exists {
            if $do-seek-debug {
                say "we haven't been here before (at least not officially)";
            }

            # we've never officially been here before
            for ( pd-right, pd-ahead, pd-left ) -> $look-direction {
                my $vista = $scratch-grid.look( relative => $look-direction );

                %vistas{ $look-direction } = $vista;

                if $vista.DEFINITE {
                    if $vista<found>.DEFINITE {
                        my $looking-absolute = %turnChart{ $scratch-grid.get-heading }{ $look-direction };

                        my $notes = $vista<found>;
                        my $user-data = $notes<user-data> // {};

                        if $vista<distance> == 1 and $user-data<trail>:exists and $user-data<trail> == pathing-taken {
                            $here{ $look-direction } = pathing-taken;
                        }
                        elsif $vista<distance> == 1 {
                            my $looking-at-side = %turnChart{ $looking-absolute }<pd-back>;

                            if $do-seek-debug {
                                say "looking relative $look-direction, looking absolute $looking-absolute at the $looking-at-side face";
                            }

                            if $user-data{ $looking-at-side }:exists {
                                if $user-data{ $looking-at-side } === $target-segment {
                                    # we found our goal!
                                    $here<taken> = $look-direction;

                                    last SEEKING;
                                }
                                else {
                                    if $do-seek-debug {
                                        say "looking at $looking-at-side and seeing $user-data{ $looking-at-side }, looking for $target-segment";
                                    }

                                    my %c;
                                    for ph-pos-x, ph-pos-y, ph-neg-x, ph-neg-y -> $h {
                                        %c{ $h } = $user-data{ $h } // '';
                                    }

                                    if $do-seek-debug {
                                        say "+x %c{ ph-pos-x }, +y %c{ ph-pos-y }, -x %c{ ph-neg-x }, -y %c{ ph-neg-y }";
                                        say "blocked 5";
                                    }

                                    $here{ $look-direction } = pathing-blocked;
                                }
                            }
                            else {
                                if $do-seek-debug {
                                    say "looking at $looking-at-side and seeing nothing, looking for $target-segment";
                                }

                                my %c;
                                for ph-pos-x, ph-pos-y, ph-neg-x, ph-neg-y -> $h {
                                    %c{ $h } = $user-data{ $h } // '';
                                }

                                if $do-seek-debug {
                                    say "+x %c{ ph-pos-x }, +y %c{ ph-pos-y }, -x %c{ ph-neg-x }, -y %c{ ph-neg-y }";
                                    say "blocked 2";
                                }

                                $here{ $look-direction } = pathing-blocked;
                            }
                        }
                        else {
                            if $do-seek-debug {
                                say "saw something at distance " ~ $vista<distance>;
                            }

                            $here{ $look-direction } = pathing-open;
                        }
                    }
                    elsif $vista<line> and $vista<distance> == 1 {
                        if $do-seek-debug {
                            say "blocked 3";
                        }

                        $here{ $look-direction } = pathing-blocked;
                    }
                    else {
                        if $do-seek-debug {
                            say $look-direction ~ " assumed open";
                        }

                        $here{ $look-direction } = pathing-open;
                    }
                }
                else {
                    if $do-seek-debug {
                        say $look-direction ~ " nothing at all, open";
                    }

                    fail;
                    $here{ $look-direction } = pathing-open;
                }
            }
        }

        my $chosen-direction;

        # look at the options in order based on our seeking pattern
        PREFERENCE: for |%preferences-by-seeking-pattern{ $seeking-pattern } -> $direction {
            if $here{ $direction } == pathing-open {
                if $do-seek-debug {
                    say "choosing $direction";
                }

                $chosen-direction = $direction;
                last PREFERENCE;
            }
            elsif $here{ $direction } == pathing-taken {
                my $seeking-absolute = %turnChart{ $scratch-grid.get-heading }{ $direction };
                my $vista = %vistas{ $direction };
                my $notes = $vista<found>;
                my $user-data = $notes<user-data> // {};
                my $back-to = $user-data<traillen> // 0;

                while @trail.elems > $back-to {
                    $scratch-grid.plot( mark => 'a', user-data => { trail => pathing-abandoned } );

                    if $do-seek-debug {
                        say $scratch-grid.render-to-multiline-string;
                    }

                    # back out of the location without leaving any (further) marks
                    @trail.pop;

                    if !@trail {
                        if $do-seek-debug {
                            say "can't get there from here";
                        }

                        return;
                    }

                    my $prev = @trail[ *-1 ];

                    # first, backtrack to the previous location
                    $scratch-grid.turn( relative => pd-back );
                    $scratch-grid.advance( plotting => False );

                    # next, reorient as if we had just entered it
                    if $prev<taken> == pd-ahead {
                        $scratch-grid.turn( relative => pd-back );
                    }
                    else {
                        $scratch-grid.turn( relative => $prev<taken> );
                    }

                    # mark this direction as blocked
                    $prev{ $prev<taken> } = pathing-blocked;
                }

                # mark the direction we were going to re-enter this space from as blocked
                # but we have to mark it relative to the original heading when we entered
                # that space
                my $approached-from-relative = %turnChart{ $scratch-grid.get-heading }{ %turnChart{ $seeking-absolute }{ pd-back } };
                @trail[ *-1 ]{ $approached-from-relative } = pathing-blocked;

                # this may be redundant with the prior marking, but that's OK
                # also mark pd-ahead as blocked because this plotting algorithm can't generate
                # disconnected segments, therefore one of two conditions must be true:
                # 1) this is an enclosed space with nothing in the middle, therefore there's nothing
                #    to be gained by filling it in with trails that must also be abandoned.
                # 2) this is the outside of the grid with nothing else "out there" to be found,
                #    therefore we can't find our target even though we have infinite space that
                #    we can look at.
                # While case 1) will resolve itself properly without a short-cut, case 2) needs help
                # or the trail will seek forever.
                @trail[ *-1 ]{ pd-ahead } = pathing-blocked;

                if $do-seek-debug {
                    say "scratch after backout";
                    say $scratch-grid.render-to-multiline-string;
                    say $scratch-grid.get-head-location;
                    say $scratch-grid.get-heading;
                }

                $here{ $direction } = pathing-abandoned;

                # need to restart seeking at the point we just backed-out to, including looking around again
                redo SEEKING;
            }
            else {
                if $do-seek-debug {
                    say "would like to go $direction but is $here{ $direction }"
                }
            }
        }

        if $chosen-direction.DEFINITE {
            $scratch-grid.plot( user-data => { trail => pathing-taken, traillen => @trail.elems } );

            $here<taken> = $chosen-direction;
            $scratch-grid.turn( relative => $chosen-direction );
            $scratch-grid.advance();

            if $do-seek-debug {
                say "after advance, scratch:";
                say $scratch-grid.render-to-multiline-string;
            }

            @trail.push( Hash.new );
        }
        else {
            # nowhere to go from here, so we abandon this place and go back
            $scratch-grid.plot( mark => 'x', user-data => { trail => pathing-abandoned } );
            @trail.pop;

            if @trail.elems {
                my $prev = @trail[ *-1 ];

                # first, backtrack to the previous location
                $scratch-grid.turn( relative => pd-back );
                $scratch-grid.advance( plotting => False );

                # next, reorient as if we had just entered it
                if $prev<taken> == pd-ahead {
                    $scratch-grid.turn( relative => pd-back );
                }
                else {
                    $scratch-grid.turn( relative => $prev<taken> );
                }

                # finally, mark this option as blocked
                if $do-seek-debug {
                    say "blocked 4";
                }

                $prev{ $prev<taken> } = pathing-blocked;
            }
        }
    } # SEEKING


    if !@trail {
        # there is no path for this state
        return;
    }

    # plot it for real
    my $trail-grid = $grid.clone;
    my @turn-by-turn;
    for @trail -> $direction {
        @turn-by-turn.push( $direction<taken> );
        $trail-grid.turn( relative => $direction<taken> );
        $trail-grid.advance;
    }

    my $arrow-head = %arrow-by-heading{ $trail-grid.get-heading };
    my $annotation = %annotation-location-by-position{ $target-segment.position } => $seq ~ $arrow-head;
    $trail-grid.plot( |$annotation );

    # render trail as a string
    my $found-path = @turn-by-turn.join( "," );

    return( $found-path, $trail-grid, $arrow-head );
}

# lower score is better
# returns a list of scores, primary and successive tiebreakers
# primary score is area
# first tiebreaker is number of points as a measure of complexity
#   ( since these grids are plots of a knot/tangle formed from a single strand,
#     the number of lines are a function of the number of points and number of crossings.
#       each crossing is a point with four lines.
#       each non-crossing point is on exactly two lines.
#       crossings * 2 + (n-points - crossings) == n-lines
#     therefore the number of lines won't break any ties )
# second tiebreaker is absolute value of delta between width and height
#    e.g. to prefer 5x6 over 3x10
sub score-grid( Grid:D :$grid ) {
    my $grid-size = $grid.get-grid-size;
    my $grid-area = $grid-size<x> * $grid-size<y>;
    my $num-points = $grid.get-num-points;
    my $oblongity = abs( $grid-size<x> - $grid-size<y> );
    return ( $grid-area, $num-points, $oblongity );
}

sub grid-compare( $a, $b ) {
    return ( $a[0] <=> $b[0] || $a[1] <=> $b[1] || $a[2] <=> $b[2] );
}

my $plot-debug = False;
my $do-optimizations = True;

# TODO
#   Adjust locations of grid dumps to better line up with the needs of comparisons of
#   different algorithmic optimizations.
#
#   Add logic that detects when cw and ccw pathing generate the exact same grid and
#   skip further development of the redundant grid.
sub plot( Tangle:D :$tangle, PlotGoal:D :$goal = plot-find-best ) {
    # low score is better
    my @best-score = ( Inf, Inf, Inf );

    my @best-grids = ();

    # this may replace @grid-states completely, and if it does then it should be renamed to @grid-states
    # state consists of:
    #   grid
    #   seeking direction (if any)
    #   seeking target (if any)
    #   segments left to plot
    #   known segments
    #   crossing type information
    #   seq
    my @grid-stack = ();

    # plot first crossing, creating first state
    {
        my @segments-left = $tangle.getOrderedList().grep( { $_ ~~ Knot::Tangle::CrossedSegment } );
        my $known-segments = SetHash.new;

        my $first-segment = @segments-left.shift;
        my $seq = 1;

        @segments-left.push( $first-segment );
        $known-segments{ $first-segment } = True;

        my $grid = Grid.new;

        my %new-crossing-types;

        my $crossing-label = $seq ~ %arrow-by-heading{ $grid.get-heading };
        my $annotation = %annotation-location-by-position{ $first-segment.position } => $crossing-label;

        my $crossing = $first-segment.crossing;
        my $crossed = $crossing.segments[ over - $first-segment.position ];

        # the first segment is the only one that needs to mark an entry point for itself
        my $user-data = {
            ph-neg-x => $first-segment,
        };

        if $crossing.type.DEFINITE {
            if
                ( $first-segment.position == over and $crossing.type == L-minus ) or
                ( $first-segment.position == under and $crossing.type == L-plus )
            {
                $user-data<ph-pos-y> = $crossed;
            }
            else {
                $user-data<ph-neg-y> = $crossed;
            }
        }
        else {
            $user-data<ph-neg-y> = $crossed;
            $user-data<ph-pos-y> = $crossed;
            # store the current heading to be used later to calculate the type
            %new-crossing-types{ $crossing } = ph-pos-x;
        }

        $grid.plot( mark => '─', |$annotation, :$user-data );

        @grid-stack.push( {
            :$grid,
            seeking-pattern => Any,
            seeking-target => Any,
            :@segments-left,
            :$known-segments,
            :%new-crossing-types,
            :$seq,
            path-str => $crossing-label,
        } );
    }

    my $iterations = 0;
    while @grid-stack.elems {
        $iterations++;

        if $plot-debug {
            say "top of loop";
            say "grid stack has " ~ @grid-stack.elems ~ " elements";
        }

        my $grid-state = @grid-stack.pop;
        my $grid = $grid-state<grid>;
        my $path-str = $grid-state<path-str>;

        # check to see if this state is already worse than the known best
        my @grid-score = score-grid( :$grid );

        if grid-compare( @grid-score, @best-score ) == More {
            # there's no point in pursuing this state further
            if $plot-debug {
                say "aborting this state, too large 1";
            }

            next;
        }

        my $seq = $grid-state<seq>;
        my $new-crossing-types = $grid-state<new-crossing-types>;
        my $known-segments = $grid-state<known-segments>;

        # if seeking
        #   do the seek
        if $grid-state<seeking-pattern>.DEFINITE {
            my $seeking-pattern = $grid-state<seeking-pattern>;
            my $target-segment = $grid-state<seeking-target>;
            my $crossing = $target-segment.crossing;

            $path-str ~= $seeking-pattern;

            if $plot-debug {
                say "$target-segment";
                say $seq;
            }

            my ( $found-path, $trail-grid, $arrow-head ) = do-seek( :$seeking-pattern, :$target-segment, :$seq, grid => $grid.clone );

            if $found-path.DEFINITE {
                $known-segments{ $target-segment } = True;
                $path-str ~= $seq ~ $arrow-head;

                if !$crossing.type.DEFINITE {
                    my $discovered-type;

                    if $target-segment.position == over {
                        $discovered-type = %crossing-type-by-headings{ $trail-grid.get-heading }{ $new-crossing-types{ $crossing } };
                    }
                    else {
                        $discovered-type = %crossing-type-by-headings{ $new-crossing-types{ $crossing } }{ $trail-grid.get-heading };
                    }

                    $crossing.type = $discovered-type;
                }

                # simplify before de-encroach tends to improve performance by making
                # future paths shorter and less complex
                $trail-grid.simplify;
                $trail-grid.de-encroach;

                if $plot-debug {
                    say "after $seq:";
                    say $trail-grid.render-to-multiline-string;
                }

                $grid = $trail-grid;
            }
            else {
                # no path exists, so this state is a bust

                # and our sibling (if any) will be too
                if $do-optimizations {
                    if
                        $grid-state<sibling-data>:exists and
                        @grid-stack.elems and
                        @grid-stack[ *-1 ]<sibling-data>:exists and
                        $grid-state<sibling-data> === @grid-stack[ *-1 ]<sibling-data>
                    {
                        @grid-stack.pop;
                    }
                }

                next;
            }
        }

        my $segments-left = $grid-state<segments-left>;

        # plot as many unknown segments as you can
        while $segments-left.elems {
            my $cur-segment = $segments-left[0];
            my $crossing = $cur-segment.crossing;
            my $crossed = $crossing.segments[ over - $cur-segment.position ];

            if $known-segments{ $crossed }:exists {
                last;
            }

            $segments-left.shift;
            $seq++;

            $known-segments{ $cur-segment } = True;

            $grid.advance();

            my $heading = $grid.get-heading;

            my $crossing-label = $seq ~ %arrow-by-heading{ $heading };
            my $annotation = %annotation-location-by-position{ $cur-segment.position } => $crossing-label;
            $path-str ~= $crossing-label;

            my $user-data = {};

            if $crossing.type.DEFINITE {
                if
                    ( $cur-segment.position == over and $crossing.type == L-minus ) or
                    ( $cur-segment.position == under and $crossing.type == L-plus )
                {
                    $user-data{ %crossing-directions{ $heading }<pd-left> } = $crossed;
                }
                else {
                    $user-data{ %crossing-directions{ $heading }<pd-right> } = $crossed;
                }
            }
            else {
                $user-data{ %crossing-directions{ $heading }<pd-left> } = $crossed;
                $user-data{ %crossing-directions{ $heading }<pd-right> } = $crossed;
                # store the current heading to be used later to calculate the type
                $new-crossing-types{ $crossing } = $heading;
            }

            $grid.plot( mark => %mark-by-heading-and-position{ $grid.get-heading }{ $cur-segment.position }, |$annotation, :$user-data );

            $grid.de-encroach;

            # check for redundant state here

            if $plot-debug {
                say "after $seq:";
                say $grid.render-to-multiline-string;
            }
        }

        # check to see if this state is already worse than the known best
        @grid-score = score-grid( :$grid );
        my $grid-score = grid-compare( @grid-score, @best-score );

        if $grid-score == More {
            # there's no point in pursuing this state further
            if $plot-debug {
                say "aborting this state, too large 2";
            }

            next;
        }

        if $segments-left.elems {
            # create both child seeking states
            my $cur-segment = $segments-left.shift;

            # are we looking for the first/last segment?
            if $segments-left.elems {
                $seq++;
            }
            else {
                $seq = 1;
            }

            my %sibling-data;

            for ( cw, ccw ) -> $seeking-pattern {
                @grid-stack.push( {
                    grid => $grid.clone,
                    seeking-pattern => $seeking-pattern,
                    seeking-target => $cur-segment,
                    segments-left => $segments-left.clone,
                    known-segments => $known-segments.clone,
                    new-crossing-types => $new-crossing-types.clone,
                    :%sibling-data,
                    :$seq,
                    path-str => $path-str,
                } );
            }
        }
        else {
            $grid.title = $path-str;

            if $grid-score == Less {
                if $plot-debug {
                    say "setting new best";
                }

                @best-score = @grid-score;
                @best-grids = ( $grid );

                # early-out if plot-find-first
                if $goal == plot-find-first {
                    return ($grid);
                }
            }
            elsif $grid-score == Same {
                if $plot-debug {
                    say "adding new best";
                }

                @best-grids.push( $grid );
            }
        }
    }

    for @best-grids -> $grid {
        say $grid.render-to-multiline-string;
    }

    say "iterations: $iterations";

    say "best score: " ~ @best-score;

    return @best-grids;
}


if True {
    #say "plotting trefoil";
    #my $t = Tangle.new( dowker-str => "4 6 2" );

    # not at trefoil - unknot with three twists
    #my $t = Tangle.new( dowker-str => "6 2 4" );

    # The tangle I drew and simplified by hand
    my $t = Tangle.new( dowker-str => "10 20 18 -4 2 -14 -16 -12 -22 6 -8" );

    # imaginary
    #my $t = Tangle.new( dowker-str => "4 6 8 10 2" );
    #my $t = Tangle.new( dowker-str => "4 6 8 10 12 14 16 18 2" );
    #my $t = Tangle.new( dowker-str => "4 6 10 18 2 8 12 14 16" );
    #plot( tangle => $t );
    say $t.isReal( debug => False );
}

if False {
# The tangle I drew and simplified by hand
#my $t = Tangle.new( dowker-str => "10 20 18 -4 2 -14 -16 -12 -22 6 -8" );

# the tangle described by this dowker is impossible - I need to figure out how
# to detect this...
#my $t = Tangle.new( dowker-str => "4 6 8 10 12 14 16 18 2" );

#my $t = Tangle.new( dowker-str => "4 6 8 10 2" );

#my $t = Tangle.new(
#    tok-pairs => [
#        [0,7],    1    -1,-2,-3,4,-5,6,-7,1,-8,9,2,5,-6,7,-4,3,-10,8,-9,10
#        [1,10],   2
#        [2,15],   3
#        [14,3],   4
#        [4,11],   5
#        [12,5],   6
#        [6,13],   7
#        [8,17],   8
#        [18,9],   9
#        [16,19],  10

#    ],
    #trace => True,
#);

my $t = Tangle.new(
    tok-pairs => [
         [0,101], [162,1], [161,2], [3,104], [4,57], [56,5], [187,6], [166,7], [41,8], [9,52], [10,93], [11,194], [49,12], [124,13], [117,14], [15,46], [16,109], [17,156], [18,221], [220,19], [111,20], [21,128], [113,22], [23,204], [217,24], [25,132], [207,26], [208,27], [28,133], [29,150], [30,201], [31,214], [32,69], [33,196], [34,77], [35,90], [36,65], [170,37], [38,81], [39,54], [40,167], [42,95], [122,43], [119,44], [190,45], [47,126], [48,115], [50,193], [51,94], [168,53], [186,55], [58,83], [59,178], [60,139], [174,61], [62,181], [63,142], [183,64], [66,79], [67,92], [195,68], [213,70], [200,71], [72,149], [73,134], [74,209], [75,136], [76,145], [78,91], [169,80], [185,82], [84,103], [102,85], [177,86], [138,87], [175,88], [144,89], [96,121], [97,120], [189,98], [108,99], [157,100], [160,105], [163,106], [107,158], [155,110], [112,129], [114,153], [116,125], [118,191], [123,192], [154,127], [205,130], [218,131], [210,135], [137,176], [173,140], [141,180], [182,143], [197,146], [212,147], [199,148], [216,151], [203,152], [164,159], [188,165], [171,184], [172,179], [198,211], [202,215], [219,206],
        # [0,19],[1,14],[2,13],[12,3],[4,9],[10,5],[6,11],[7,16],[17,8],[15,18],
    ],
);

say $t.asGaussStr;
$t.preferred-first = $t.findCanonFirst;
say $t.asGaussStr;
$t.reduce;
say $t.asGaussStr;
$t.preferred-first = $t.findCanonFirst;
say $t.asGaussStr;

}
elsif 0 {
my @twos;

my %unique-dowkers;

for 1 .. 6 -> $n {
    @twos[ $n - 1 ] //= 2 ** ( $n - 1 );

    # the 0 is necessary to seed the pattern for the range,
    # but we don't want it in the final list
    my @numbers = 0, 2 ... ( 2 * $n );
    @numbers.shift;

    # skip permutations that reduce trivially
    for @numbers.permutations.grep( { $_[0] != 2 && $_[0] != @twos[ *-1 ] } ) -> @permutation {
        # half of the bit patterns are mere inversions of the
        # other half, so skip half by simply never negating the last element
        # (note from later - the premise above seems dubious)
        for 0 ..^ @twos[ $n - 1 ] -> $sign-bits {
            for 0 ..^ $n -> $i {
                @permutation[$i] *= -1 ** ( ( $sign-bits +& @twos[ $i ] ) / @twos[ $i ] );
            }

            my $dowker-str = @permutation.join( ' ' );
            my $tangle = Tangle.new( :$dowker-str );
            next if $tangle.canReduce;

            my $new-str = $tangle.asDowkerStr;

            %unique-dowkers{ $new-str } = 1;
        }
    }
}

dd %unique-dowkers;
}

=begin aside
    while writing:
                    # @adjacent-pair and @partners[0] .. @partners[1] separate the rest
                    # of the tangle into two substrands:
                    #   @adjacent-pair[0] ^..^ @partners[0]
                    #   @partners[1] ^..^ @adjacent-pair[1]
                    # when dealing with real knots we can rely on the fact that any
                    # strand in $also-involved either:
                    #      is adjacent to one of @adjacent-pair or @partners
                    #   OR has two "edges" in $also-involved
                    # but when dealing with imaginary knots, this can't be assumed.
                    # an imaginary knot could have a strand with only one "edge"
                    # that intersects @partners[0] ^..^ @partners[1] and yet isn't
                    # adjacent to @partners or @adjacent-pair.
                    # If this section relies on the assumption of a real knot, it
                    # will be the first logic in this module that does so.

    I got to thinking about the topology of the imaginary two-crossing tangles
    represented in the tok notation by:
        [0,2],[1,3]; [0,2],[3,1]; [2,0],[1,3]; [2,0],[3,1];
    Each of those reduces to the unknot using the standard Reidmeister Type II move

    While thinking about that, and the implications of an imaginary knot being
    reducable to a real "knot" using only standard moves, I recalled a piece I
    ready in either Game Developers or on Gamasutra about how many pathfinding
    algorithms often spend as much time looking in the "wrong" directions for a
    "slow teleport" to their destination as they do looking in the "right"
    direction to find a "direct route" to their destination.  within the context
    of that article a "slow teleport" is a way of traversing from poin C to
    point D at the normal movement cost but without crossing any of the already
    searched points in between.  In a constrained 2d maze world it would be like
    being able to climb down into a tunnel that passed under the rest of the maze,
    including walls and the already-searched portions of the maze, to emerge next
    to the goal.  That is a topology that looks very similar to the topology
    of the imaginary two-crossing tangles.

    So, it seems that if one were to be able to differentiate between a real
    tangle and an imaginary one based solely on the information found in their
    crossings, one might also be able to apply similar techniques to the culling
    of options in pathfinding to eliminate "looking for a slow teleport".

    Less specific, but potentially more interesting, is the implications of
    "if this section relies on the assumption of a real knot, it will be the
    first logic in this module that does so".  This implies that it /may/
    be possible for there to be a complete general-purpose algorithm for
    reducing knot complexity that does not rely on distinguishing between a
    real knot and an imaginary one (where an imaginary knot is one that
    requires a means to get in/out of a closed loop without crossing the
    loop itself).  Even if it isn't possible for an algorithm that covers
    both, that itself is interesting.
=end aside
