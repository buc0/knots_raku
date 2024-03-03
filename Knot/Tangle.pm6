use v6;

unit module Knot::Tangle:ver<1>:auth<Brian Conry (brian@theconrys.com)>;

#use PlottingGrid::Malleable;
use Knot::Dowker;

enum CrossingPosition is export <under over>;
# as a reminder
# when looking at a crossing from the perspective of being between the "in" portion
# of each segment, the crossing is L-plus if the left-to-right segment is in the
# "over" position and the right-to-left segment is in the "under" position
enum CrossingType is export ( L-minus => -1, L-plus => 1 );

class Segment {
    has Segment $.successor is rw;
    has Segment $.predecessor is rw;
};

class PlainSegment is Segment {
    # returns the new Segment
    method split( Bool:D :$after = True, --> Segment ) {
        my $new-half = PlainSegment.new;

        if $after {
            $new-half.predecessor = self;
            $new-half.successor = self.successor;
            self.successor.predecessor = $new-half;
            self.successor = $new-half;
        }
        else {
            $new-half.successor = self;
            $new-half.predecessor = self.predecessor;
            self.predecessor.successor = $new-half;
            self.predecessor = $new-half;
        }

        return $new-half;
    }
}

class Crossing { ... };

class CrossedSegment is Segment {
    has Crossing $.crossing is rw;
    has CrossingPosition $.position is rw;
};

# having type undefined indicates that it is unknown
class Crossing {
    has @.segments[2] is rw;
    has CrossingType $.type is rw;
};

class MarkedSegment is Segment {
    # thought:
    #   the mark can be of any type,
    #   so I could use it to simultaneously
    #   mark the location of an excised subset
    #   of a tangle *and* store the excised segments!
    has $.mark is rw;
};


# the logic here is supposed to keep at least one
# PlainSegment on each side of any segment that
# isn't a PlainSegment

class Tangle is export {
    use fatal;

    has SetHash $!segments;
    has SetHash $.crossings;

    # preferred-first maybe should have a setter method that validates that it is in $!segments
    # could also mark it so that it can't be excised
    # may want to add a way to "unmark" a segment so that a former first-segment could be excised
    has Segment $.preferred-first is rw;

    # returns nothing
    submethod build-strand( Int:D :$length, --> Nil ) {
        my @segments;

        @segments.push( PlainSegment.new );

        for 0 ^..^ $length {
            my $new-segment = PlainSegment.new( predecessor => @segments[ *-1 ] );
            @segments[ *-1 ].successor = $new-segment;
            @segments.push( $new-segment );
        }

        @segments[0].predecessor = @segments[ *-1 ];
        @segments[ *-1 ].successor = @segments[0];

        $!segments = @segments.SetHash;
        $!crossings = SetHash.new;
    }

    # specifically unoriented dowker
    # returns nothing
    submethod build-from-dowker( Dowker:D :$dowker, --> Nil ) {
        my @expanded-pairs = ( 1, 3 ... ∞ ) Z $dowker.numbers;

        # allocate one extra segment which we'll set as the preferred first segment since all of
        # the other segments will change as they get crossed.
        # in this case the extra segment is the first segment.
        self.build-strand( length => 2 * @expanded-pairs + 1 );

        my @segments = self.getOrderedList;

        self.preferred-first = @segments[0];

        for @expanded-pairs -> $dowker-pair {
            if $dowker-pair[1] < 0 {
                self.cross( over => @segments[ $dowker-pair[1].abs ], under => @segments[ $dowker-pair[0] ] );
            }
            else {
                self.cross( over => @segments[ $dowker-pair[0] ], under => @segments[ $dowker-pair[1] ] );
            }
        }

        self.preferred-first = @segments[0];
    }

    multi submethod BUILD( Dowker:D :$dowker ) {
        self.build-from-dowker( :$dowker );
    }

    multi submethod BUILD( Str:D :$dowker-str ) {
        self.build-from-dowker( dowker => Dowker.new( notation => $dowker-str ) );
    }

    multi submethod BUILD( :@tok-pairs ) {
        # allocate one extra segment which we'll set as the preferred first segment since all of
        # the other segments will change as they get crossed.
        # in this case the extra segment is the last segment.
        self.build-strand( length => 2 * @tok-pairs + 1 );

        my @segments = self.getOrderedList;

        self.preferred-first = @segments[ *-1 ];

        for @tok-pairs -> @tok-pair {
            self.cross( over => @segments[ @tok-pair[1] ], under => @segments[ @tok-pair[0] ] );
        }
    }

    # returns a string
    method asDowkerStr( Segment :$first? is copy, --> Str ) {
        $first //= $!preferred-first // $!segments.keys[0];

        fail "not mine!" unless $first ∈ $!segments;

        my @crossing-segments = self.getOrderedList( :$first ).grep( { $_ ~~ CrossedSegment } );

        if @crossing-segments {
            fail "odd number of crossing segments" unless @crossing-segments %% 2;

            my %index-lookup = @crossing-segments.antipairs;

            my @dowker-numbers;

            for 0 ..^ @crossing-segments -> $i, Mu {
                my $segment = @crossing-segments[ $i ];

                if $segment.position == under {
                    @dowker-numbers.push( -( %index-lookup{ $segment.crossing.segments[ over ] } + 1 ) );
                }
                else {
                    @dowker-numbers.push( %index-lookup{ $segment.crossing.segments[ under ] } + 1 );
                }
            }

            return @dowker-numbers.join( ' ' );
        }
        else {
            return Nil;
        }
    }

    # returns a Knot::Dowker
    method asDowker( Segment :$first? is copy, --> Dowker ) {
        my $dowker-str = self.asDowkerStr( :$first );

        if $dowker-str.DEFINITE {
            return Dowker.new( notation => $dowker-str );
        }
        else {
            return Nil;
        }
    }

    method asGaussStr( Segment :$first? is copy, --> Str ) {
        $first //= $!preferred-first // $!segments.keys[0];

        fail "not mine!" unless $first ∈ $!segments;

        my @crossing-segments = self.getOrderedList( :$first ).grep( { $_ ~~ CrossedSegment } );

        if @crossing-segments {
            fail "odd number of crossing segments" unless @crossing-segments %% 2;

            my %crossings;

            my @gauss-numbers;

            for @crossing-segments -> $segment {
                my $nbr;

                if %crossings{ $segment.crossing }:exists {
                    $nbr = %crossings{ $segment.crossing };
                }
                else {
                    $nbr = 1 + %crossings.elems;
                    %crossings{ $segment.crossing } = $nbr;
                }

                if $segment.position == under {
                    $nbr = -$nbr;
                }

                @gauss-numbers.push( $nbr );
            }
            return @gauss-numbers.join( ', ' );
        }
        else {
            return '-';
        }
    }

    method isReal( Bool :$debug? --> Bool ) {
        # This method determines whether or not this tangle is "real",
        # where I'm defining a "real knot" to be one that could be drawn
        # on a plane or the surface of a sphere, as opposed to an
        # "imaginary" knot (to coin a term) that cannot be so drawn
        # without one or more discontinuities, as if a segment were
        # taking a short-cut through the inside of the sphere in order
        # to get to the other side of some segment without crossing it.
        #
        # The method functions by constructing the spaces bounded by the
        # segments of the tangle incrementally.
        #
        # if the orientations of the crossings isn't specified then during
        # the process crossing segments will be assigned placeholders
        # "a" and "b" until an in/out direction is chosen.
        #
        # in a tangle where the crossing directions are not specified it
        # may be that some combinations will be real while others are not.
        # therefore the algorithm will have to be able to backtrack and
        # try other combinations until it finds one that works.
        #
        # This method is easiest to visualize if you think of the tangle
        # as being a set of connected crossing hallways (over/under doesn't
        # matter) rather than as a strand. This algorithm names each wall
        # according to the corners of the intersections that it forms
        # (or that form it, depending on your perspective).
        #
        # notation example, showing crossings
        #   1 over X followed by 2 under Y
        #
        #              │    │                   │    │
        #              │    │                   │    │
        #     1i|Xa    │    │    Xa|1o-2i|Ya    │    │     Ya|2o
        #              │    │                   │    │
        #              │ Xa │                   │ Ya │
        #              │    │                   │    │
        #   ───────────┘    └───────────────────┘    └──────────────
        # →         ii        1o             2i        2o          →
        #   ───────────┐    ┌───────────────────┐    ┌──────────────
        #              │    │                   │    │
        #              │ Xb │                   │ Yb │
        #              │    │                   │    │
        #     Xb|1i    │    │    Yb|2i-1o|Xb    │    │     2o|Yb
        #              │    │                   │    │
        #              │    │                   │    │
        #
        #  "i" is short for "in"
        #  "o" is short for "out"
        #  "a" is a placeholder for either in or out
        #  "b" is the plaecholder for the opposite for a given crossing-segment
        #  "corners" are named for the paths that they border,
        #    in counter-clockwise order respective to the intersection.
        #  "walls" are named by their corners, in counter-clockwise order
        #    respective to the interior of the wall.
        #
        # Another important concept for understanding this is that incomplete
        # walls (walls that haven't yet been proven to be complete), may be
        # known to be separated from each other.
        #
        # For instance, suppose you start at one intersection and walk down
        # the hallway and pass through two more intersections, so you've passed
        # two openings on the left and two corresponding openings on the right,
        # and then the hallway loops around to the left and you return to your
        # starting interesection. Because you've gone all the way around them
        # you know that the two openings that were on your left cannot connect
        # directly to any other openings you know about, and you may also be
        # pretty sure that they connect to each other, though this hasn't been
        # proven yet. These two openings are bounded by walls that you don't
        # know the full names of (at least not officially), but that you know
        # can't be simply grouped in with any other walls.
        #
        # One way of picturing this would be if you were looking down on this
        # set of crossing hallways from above, but it's completely dark so
        # you can't see anything. Someone is walking down the hallways and
        # lighting lamps as they go. When they start they are one spot of
        # light in the middle of a large connected darkness and every opening
        # that they pass leads off into this same connected darkness. As they
        # loop back to come at crossings along the other path they will be
        # creating loops of lit hallways that will split the one dark unknown
        # into smaller dark unknowns. The algorithm will keep trakc of these
        # splits because that's how it determines whether or not the tangle
        # is "real" - if all of the walls can be named fully (and the
        # hallways fully lit) then it's "real", but if at some point the
        # path heads into one of the darknesses and the exit corridor is
        # on a different dark blob then that combination doesn't work.
        #
        # The imagry falls apart at this point because if the direction of
        # crossings isn't specified up-front then it may be possible to
        # connect to either the "a" or "b" side of a crossing, and sometimes
        # a full solution can be found for only one of those choices, so the
        # algorithm has to keep track of each of those decision points and
        # be able to revisit them if it can't find a path with the current
        # set of decisions. A tangle is "imaginary" only if there doesn't
        # exist any combination of decisions that can be solved.

        # assign each crossing segment a number from 1 to N
        # using 'not-a-crossing' as a spacer to take the 0 index.
        my @crossing-segments = self.getOrderedList().grep( { $_ ~~ CrossedSegment } );
        @crossing-segments.unshift( 'not-a-crossing' );
        my %number-lookup = @crossing-segments.antipairs;
        %number-lookup{ 'not-a-crossing' }:delete;
        @crossing-segments.shift;

        # initialize the stack of decision states
        my @states = (
            {
                grouped-incomplete-spaces => [],
                active-group => Nil,
                complete-spaces => [],
                segments-left => [ |@crossing-segments ],
                seen-segments => {},
            },
        );

        # scratch variables
        # note that the "cw" and "ccw" are relative to the crossing, starting at the "in" of the current segment
        my $other-number;
        my $other-cw-label;
        my $other-ccw-label;

        # finish initializing the starting decision state with the
        # information from the first crossing
        #   (1o|Xb) (Xb|1i) (1i|Xa) (Xa|1o)
        # set the one group to the active group
        my $first-segment = @states[0]<segments-left>.shift;

        $other-number = %number-lookup{ $first-segment.crossing.segments[ over - $first-segment.position ] };

        if $first-segment.crossing.type.DEFINITE {
            if
                (
                    $first-segment.crossing.type == L-minus and
                    $first-segment.position == under
                ) or
                (
                    $first-segment.crossing.type == L-plus and
                    $first-segment.position == over
                )
            {
                $other-cw-label = 'o';
                $other-ccw-label = 'i';
            }
            else {
                $other-cw-label = 'i';
                $other-ccw-label = 'o';
            }
        }
        else {
            $other-cw-label = 'a';
            $other-ccw-label = 'b';
        }

        my @initial-space = ( "1o|$other-number$other-ccw-label", "$other-number$other-ccw-label|1i", "1i|$other-number$other-cw-label", "$other-number$other-cw-label|1o" );
        @states[0]<grouped-incomplete-spaces>.push( @initial-space );
        @states[0]<active-group> = @initial-space;
        @states[0]<seen-segments>{ 1 } = True;
        @states[0]<seen-segments>{ $other-number } = True;

        while @states.elems {
            my %state = @states.pop;

            my $next-segment = %state<segments-left>.shift;
            my $next-number = %number-lookup{ $next-segment };

            if $debug {
                say '(';
                dd(
                  grouped-spaces => %state<grouped-incomplete-spaces>,
                  active-group => %state<active-group>,
                  complete-groups => %state<complete-spaces>,
                  seen => %state<seen-segments>,
                  :$next-number,
                );
                say ')';
            }

            while not %state<seen-segments>{ $next-number }:exists {
                $other-number = %number-lookup{ $next-segment.crossing.segments[ over - $next-segment.position ] };

                if $next-segment.crossing.type.DEFINITE {
                    if
                      (
                          $next-segment.crossing.type == L-minus and
                          $next-segment.position == under
                      ) or
                      (
                          $next-segment.crossing.type == L-plus and
                          $next-segment.position == over
                      )
                    {
                        $other-cw-label = 'o';
                        $other-ccw-label = 'i';
                    }
                    else {
                        $other-cw-label = 'i';
                        $other-ccw-label = 'o';
                    }
                }
                else {
                    $other-cw-label = 'a';
                    $other-ccw-label = 'b';
                }

                %state<active-group>[0] = "$other-number$other-ccw-label|{$next-number}i-" ~ %state<active-group>[0];
                %state<active-group>.unshift( "{$next-number}o|$other-number$other-ccw-label" );
                %state<active-group>[ *-1 ] ~= "-{$next-number}i|$other-number$other-cw-label";
                %state<active-group>.push( "$other-number$other-cw-label|{$next-number}o" );

                %state<seen-segments>{ $next-number } = True;
                %state<seen-segments>{ $other-number } = True;

                $next-segment = %state<segments-left>.shift;
                $next-number = %number-lookup{ $next-segment };

                if $debug {
                    say '(';
                    dd(
                      grouped-spaces => %state<grouped-incomplete-spaces>,
                      active-group => %state<active-group>,
                      complete-groups => %state<complete-spaces>,
                      seen => %state<seen-segments>,
                      :$next-number,
                    );
                    say ')';
                }
            }

            # look for "i", "a", and "b" in the active group
            my @options-for-in = %state<active-group>.grep( { / ^ $next-number <[abi]> / } );

            if $debug {
                dd :@options-for-in;
            }

            if @options-for-in.elems == 2 {
                # this can only happen if we find both "a" and "b"
                # we'll create a copy of the current state that makes the opposite choice

                # clone is shallow
                my %other-state = %state.clone;
                %other-state<grouped-incomplete-spaces> = [ %state<grouped-incomplete-spaces>.map( { $_.clone } ) ];
                %other-state<active-group> = %other-state<grouped-incomplete-spaces>.grep( { $_.grep( { / ^ $next-number a / } ).elems } )[0];
                for %other-state<active-group>.values {
                    s/ ( ^ | '|' ) $next-number 'a' /{$0 ~ $next-number ~ 'o'}/;
                    s/ ( ^ | '|' ) $next-number 'b' /{$0 ~ $next-number ~ 'i'}/;
                }
                %other-state<complete-spaces> = %state<complete-spaces>.clone;
                %other-state<segments-left> = %state<segments-left>.clone;
                %other-state<seen-segments> = %state<seen-segments>.clone;

                # we'll need to redo this crossing in the copy
                %other-state<segments-left>.unshift( $next-segment );
                @states.push( %other-state );

                if $debug {
                    say '(other';
                    dd(
                      grouped-spaces => %other-state<grouped-incomplete-spaces>,
                      active-group => %other-state<active-group>,
                      complete-groups => %other-state<complete-spaces>,
                      seen => %other-state<seen-segments>,
                      :$next-number,
                    );
                    say ')';
                }

                for %state<active-group>.values {
                    s/ ( ^ | '|' ) $next-number 'a' /{$0 ~ $next-number ~ 'i'}/;
                    s/ ( ^ | '|' ) $next-number 'b' /{$0 ~ $next-number ~ 'o'}/;
                }

                @options-for-in = %state<active-group>.grep( { / ^ $next-number 'i' / } );
            }

            if $debug {
                dd :@options-for-in;
            }

            # if found only "a" or "b"
            if @options-for-in.elems and @options-for-in[0] ~~ / ^ $next-number (<[ab]>) / {
                my $in-placeholder = $0;
                my $out-placeholder = ( $in-placeholder eq 'a' ?? 'b' !! 'a' );

                if $debug {
                    dd(
                        :$in-placeholder,
                        :$out-placeholder,
                    );
                }

                # + rename the found one to "i"
                for %state<active-group>.values {
                    s/ ( ^ | '|' ) $next-number $in-placeholder /{$0 ~ $next-number ~ 'i'}/;
                }

                # + search the other incomplete groups and rename the other to "o"
                for %state<grouped-incomplete-spaces>.grep( { $_.grep( { / ^ $next-number $out-placeholder / } ).elems } )[0].values {
                    s/ ( ^ | '|' ) $next-number $out-placeholder /{$0 ~ $next-number ~ 'o'}/;
                }

                @options-for-in = %state<active-group>.grep( { / ^ $next-number 'i' / } );

                if $debug {
                    say '(';
                    dd(
                      grouped-spaces => %state<grouped-incomplete-spaces>,
                      active-group => %state<active-group>,
                      complete-groups => %state<complete-spaces>,
                      seen => %state<seen-segments>,
                      :$next-number,
                    );
                    say ')';
                }
            }

            if $debug {
                dd :@options-for-in;
            }

            if @options-for-in.elems and @options-for-in[0] ~~ / ^ $next-number i / {
                if $debug {
                    say '(';
                    dd(
                      grouped-spaces => %state<grouped-incomplete-spaces>,
                      active-group => %state<active-group>,
                      complete-groups => %state<complete-spaces>,
                      seen => %state<seen-segments>,
                      :$next-number,
                    );
                    say ')';
                }

                # + remove the active group from grouped-incomplete-spaces
                %state<grouped-incomplete-spaces> = [ %state<grouped-incomplete-spaces>.grep( { not $_ === %state<active-group> } ) ];

                if $debug {
                    dd(
                      grouped-spaces => %state<grouped-incomplete-spaces>,
                    );
                }

                # + split the active group at the "i" (should be one element ending with "Ni" followed by one starting with "Ni")
                my $divide-index = %state<active-group>.first( / ^ $next-number 'i' /, :k );

                my @left-items = %state<active-group>[0..^$divide-index];
                my @right-items = %state<active-group>[$divide-index..*];

                if @left-items.elems == 1 {
                    #   + if is only one element, push it onto complete-spaces
                    %state<complete-spaces>.push( @left-items );
                }
                else {
                    #     + join the last elment and first element (in that order) w "-" as the new first element
                    @left-items.unshift( @left-items.pop ~ '-' ~ @left-items.shift );
                    #     + add this group to grouped-incomplete-spaces
                    %state<grouped-incomplete-spaces>.push( @left-items );
                }

                if @right-items.elems == 1 {
                    #   + if is only one element, push it onto complete-spaces
                    %state<complete-spaces>.push( @right-items );
                }
                else {
                    #     + join the last elment and first element (in that order) w "-" as the new first element
                    @right-items.unshift( @right-items.pop ~ '-' ~ @right-items.shift );
                    #     + add this group to grouped-incomplete-spaces
                    %state<grouped-incomplete-spaces>.push( @right-items );
                }

                if $debug {
                    say '(';
                    dd(
                      grouped-spaces => %state<grouped-incomplete-spaces>,
                      active-group => %state<active-group>,
                      complete-groups => %state<complete-spaces>,
                      seen => %state<seen-segments>,
                      :$next-number,
                    );
                    say ')';
                }

                # + search grouped-incomplete-spaces for the group with the "o"
                # + set that group to the active group
                %state<active-group> = %state<grouped-incomplete-spaces>.grep( { $_.grep( { / ^ $next-number 'o' / } ) } )[0];

                # + rotate the group so that the elemnt starting with "No" is first and the element ending with "No" is last
                while %state<active-group>[0] !~~ / ^ $next-number 'o' / {
                    %state<active-group>.push( %state<active-group>.shift );
                }
            }
            else {
                # else { this state is a bust; discard it }
                next;
            }

            if %state<segments-left>.elems {
                @states.push( %state );
            }
            else {
                if
                    %state<grouped-incomplete-spaces>.elems == 1 and
                    %state<active-group>.elems == 2 and
                    %state<active-group>.grep( { / ^ '1i' / } )
                {
                    if $debug {
                        say '(';
                        dd(
                          grouped-spaces => %state<grouped-incomplete-spaces>,
                          active-group => %state<active-group>,
                          complete-groups => %state<complete-spaces>,
                          seen => %state<seen-segments>,
                          :$next-number,
                        );
                        say ')';
                    }

                    return True;
                }
            }
        }

        return False;
    }

    method getOrderedList( Segment :$first? is copy ) {
        $first //= $!preferred-first // $!segments.keys[0];

        fail "not mine!" unless $first ∈ $!segments;

        my @return-list = ( $first.predecessor );

        # build working backwards so we can always only at the 0th element
        while @return-list[0] !=== $first {
            @return-list.unshift( @return-list[0].predecessor );
        }

        return @return-list;
    }

    method cross( PlainSegment:D :$over, PlainSegment:D :$under ) {
        if $over ∉ $!segments or $under ∉ $!segments {
            fail "not my segment(s)";
        }

        if $over === $under {
            fail "crossing a segment over/under itself is ambiguous: split it first";
        }

        if (
            $over.predecessor !~~ PlainSegment or
            $over.predecessor === $under
        ) {
            $!segments{ $over.split( after => False ) } = True;
        }

        if (
            $over.successor !~~ PlainSegment or
            $over.successor === $under
        ) {
            $!segments{ $over.split( after => True ) } = True;
        }

        if $under.predecessor !~~ PlainSegment {
            $!segments{ $under.split( after => False ) } = True;
        }

        if $over.successor !~~ PlainSegment {
            $!segments{ $under.split( after => True ) } = True;
        }

        my $new-over = CrossedSegment.new( position => over, successor => $over.successor, predecessor => $over.predecessor );
        my $new-under = CrossedSegment.new( position => under, successor => $under.successor, predecessor => $under.predecessor );

        $over.predecessor.successor = $new-over;
        $over.successor.predecessor = $new-over;
        $under.predecessor.successor = $new-under;
        $under.successor.predecessor = $new-under;

        my $crossing = Crossing.new( segments => [ $new-under, $new-over ] );
        $new-over.crossing = $crossing;
        $new-under.crossing = $crossing;

        $!segments{ $new-over } = True;
        $!segments{ $new-under } = True;

        $!crossings{ $crossing } = True;

        $over.predecessor = $over.successor = Nil;
        $under.predecessor = $under.successor = Nil;

        $!segments{ $over } = False;
        $!segments{ $under } = False;

        return $over, $under;
    }

    # With unknown Knots it's tricky to even refer to them in an
    # unambiguous way that doesn't depend on the current choice
    # of "first crossing".
    #
    # This works around that particular difficulty by coming up
    # with a way of designating one crossing as "first" in a way
    # that comes up with the same answer no matter where one
    # starts. For Knots, like the trefoil, that have N
    # symmetrical subsets there are N choices that are
    # completely equivalent and indistinguishable.
    #
    # The Knot does need to be directed, though this method does
    # not preserve or distinguish between the left-handedness or
    # right-handedness of the total Knot or any independently
    # orientable subsections of it.
    #
    # Each crossing segment (so a Knot with 3 crossings has 6
    # segments) is assigned a number based on the number of other
    # crossing segments that are passed through before reaching
    # the segment that it crosses.
    #
    # These numbers will range from 0 to 2(N -1), where N is the
    # number of crossings. In a "real" knot these numbers will
    # always be even.
    #
    # Next, for each crossing segment construct a number in base
    # 2(N-1) with 2N digits, where the first (highest-order)
    # digit is that crossing's number and the remaining digits
    # are obtained from all of the other segments in the knot in
    # the order that they would be visited when traversing the
    # entire Knot in the designated direction.
    #
    # Any crossing whose 2N digit number in base 2(N-1) is
    # lowest is indistinguishable from any other crossing with
    # the same number and can be considered to be the "first"
    # crossing.
    method findCanonFirst {
        return unless $!crossings;

        my $number-base = 2 * $!crossings;

        my @segments = self.getOrderedList.grep( { $_ ~~ CrossedSegment } );

        my %distances;

        my %seen-crossings;

        for 0 ..^ @segments -> $i {
            my $segment = @segments[ $i ];

            if %seen-crossings{ $segment.crossing }:exists {
                my $prev-i = %seen-crossings{ $segment.crossing };
                %distances{ @segments[ $i ] } = $number-base - $i + $prev-i;
                %distances{ @segments[ $prev-i ] } = $i - $prev-i;
            }
            else {
                %seen-crossings{ $segment.crossing } = $i;
            }
        }

        #my $best-sum = ∞;
        my $best-sum = $number-base ** @segments;
        my $best-first-segment;

        for 1 .. @segments {
            %seen-crossings = ();

            my $sum = 0;

            for @segments -> $segment {
                next if %seen-crossings{ $segment.crossing }:exists;

                $sum *= $number-base;
                $sum += %distances{ $segment };
            }

            #say $sum;
            #say $best-sum;
            #say $sum <=> $best-sum;
            if ( $sum < $best-sum ) or ( $sum == $best-sum && $best-first-segment.position == over ) {
                $best-sum = $sum;
                $best-first-segment = @segments[0];
            }

            @segments = @segments.rotate( 1 );
        }

        return $best-first-segment;
    }

    method excise-inclusive( Segment:D :$first, Segment:D :$last, :$exclude-marked = True ) {
        if $first ∉ $!segments or $last ∉ $!segments {
            fail "not my segment(s)";
        }

        my @to-remove = ( $first );
        while @to-remove[0] !=== $last {
            @to-remove.unshift( @to-remove[0].successor );
        }

        self.excise( :@to-remove, :$exclude-marked );

        return @to-remove;
    }

    method excise( :@to-remove, :$exclude-marked = True ) {
        if @to-remove.grep( { $_ ∉ $!segments } ) {
            fail "not my segment(s)";
        }

        my $to-remove = @to-remove.SetHash;

        if $to-remove ⊆ $!segments and $!segments ⊆ $to-remove {
            # asked to excise everything
            $!segments = SetHash.new;
            $!crossings = SetHash.new;
            $!preferred-first = Nil;
            return;
        }
        elsif $to-remove ⊄ $!segments {
            fail "not mine!";
        }

        for @to-remove.grep( { $_ ~~ CrossedSegment } ) -> $segment {
            # this relies on an enum where over == 1 and under == 0
            my $other = $segment.crossing.segments[ over - $segment.position ];

            fail "cannot excise only half a crossing" unless $other ∈ $to-remove;
        }

        if $exclude-marked and @to-remove.grep( { $_ ~~ MarkedSegment } ) {
            fail "cannot excise marked segments while exclude-marked = True";
        }

        if $!preferred-first {
            while $!preferred-first ∈ $to-remove {
                $!preferred-first = $!preferred-first.successor;
            }
        }

        # The logic here could be much simpler by having each excised segment
        # clear its own relationships and then directly link its predecessor
        # to its successor, except that we're choosing to preserve
        # predecessor/successor relationships among excised segments
        for @to-remove -> $segment {
            # $segment.predecessor may have been set to Any while processing a
            # segment that came earlier in @to-remove
            if $segment.predecessor and $segment.predecessor ∉ $to-remove {
                my $predecessor = $segment.predecessor;

                my $candidate-successor = $segment.successor;

                while $candidate-successor ∈ $to-remove {
                    $candidate-successor = $candidate-successor.successor;
                }

                $candidate-successor.predecessor.successor = Nil;
                $candidate-successor.predecessor = $predecessor;
                $predecessor.successor = $candidate-successor;
                $segment.predecessor = Nil;
            }

            # $segment.successor may have been set to Any while processing a
            # segment that came earlier in @to-remove
            if $segment.successor and $segment.successor ∉ $to-remove {
                my $successor = $segment.successor;

                my $candidate-predecessor = $segment.predecessor;

                while $candidate-predecessor ∈ $to-remove {
                    $candidate-predecessor = $candidate-predecessor.predecessor;
                }

                $candidate-predecessor.successor.predecessor = Nil;
                $candidate-predecessor.successor = $successor;
                $successor.predecessor = $candidate-predecessor;
                $segment.successor = Nil;
            }

            if $segment ~~ CrossedSegment {
                $!crossings{ $segment.crossing } = False;
            }
            $!segments{ $segment} = False;
        }
    }

    multi method mark( Segment: $segment, :$mark ) {
        fail "can only mark PlainSegments";
    }

    multi method mark( PlainSegment:D :$segment, :$mark ) {
        if $segment ∉ $!segments {
            fail "not mine!";
        }

        if $segment.predecessor !~~ PlainSegment {
            $!segments{ $segment.split( after => False ) } = True;
        }

        if $segment.successor !~~ PlainSegment {
            $!segments{ $segment.split( after => True ) } = True;
        }

        my $marked-segment = MarkedSegment.new(
            predecessor => $segment.predecessor,
            successor => $segment.successor,
            mark => $mark,
        );

        $marked-segment.predecessor.successor = $marked-segment;
        $marked-segment.successor.predecessor = $marked-segment;

        $!segments{ $segment } = False;
        $!segments{ $marked-segment } = True;
    }

    method canReduce() {
        return self.reduce( check-only => True );
    }

    method reduce( :$check-only = False ) {
        my $did-reduce = False;

        my @subknots;

        REDUCE: for 1 {
            last unless $!crossings;

            my $canon-first = self.findCanonFirst;

            #say self.asDowkerStr( first => $canon-first );
            say self.asGaussStr( first => $canon-first );

            my @ordered-segments = self.getOrderedList( first => $canon-first ).grep( { $_ ~~ CrossedSegment } );

            # the canon ordering will always place a simple
            # twist at the front of the tangle
            if @ordered-segments[0].crossing === @ordered-segments[1].crossing {
                $did-reduce = True;
                last REDUCE if $check-only;
                self.excise( to-remove => [ @ordered-segments[0], @ordered-segments[1] ] );
                redo REDUCE;
            }

            my %indexes-by-segment = @ordered-segments.antipairs;

            my $original-first = @ordered-segments[0];
            my @same-position-adjacent-segments;

            repeat {
                if @ordered-segments[0].position == @ordered-segments[1].position {
                    @same-position-adjacent-segments.push( [ @ordered-segments[0], @ordered-segments[1] ] );
                }
                @ordered-segments = @ordered-segments.rotate( 1 );
            } until @ordered-segments[0] === $original-first;

            if @same-position-adjacent-segments {
                # first check for trivial cases where one pair of adjacent segments
                # in the same position matches up exactly with another pair of
                # adjacent segments (that will both have to be in the other position)
                for @same-position-adjacent-segments -> @adjacent-pair {
                    my @partners = @adjacent-pair.map( { $_.crossing.segments[ over - $_.position ] } );

                    my $partners-delta = [-] @partners.map( { %indexes-by-segment{ $_ } } );

                    # Note that we don't have to worry about handling the case where
                    # the partners have the first and last indexes, since those
                    # partners will also be in @same-position-adjacent-segments
                    # and their partners will have indexes that only differ by 1
                    if $partners-delta.abs == 1 {
                        $did-reduce = True;
                        last REDUCE if $check-only;
                        self.excise( to-remove => [ |@adjacent-pair, |@partners ] );
                        redo REDUCE;
                    }
                }

                # next check for cases where moving a strand (as defined by a pair
                # of adjacent segments) to the other side of another strand (as
                # defined by the segments they cross) and introduce fewer new
                # crossings than will be eliminated by the move

                # every place where we have adjacent over-over or under-under there
                # is a subloop created by the crossed segments.  the pair of crossings
                # can be eliminated by sliding the strand over the loop.  If the loop
                # intersects with other subloops then doing so will create additional
                # new crossings, potentially very many.  The cases we're looking for
                # are when this action will only create zero or one new crossing to
                # replace the two crossings being eliminated.  This makes the operation
                # a simplifying operation.

                # a reducing Reidmeister type II move is merely the simplest example
                # of this class of operation

                # The operation performed here can be accomplished by a series of reidmeister
                # moves, generally requiring complicating type I and II moves prior to one or
                # more type III moves, before finishing with simplifying type I and II moves.
                # Rather than trying to figure out the necessary sequence, if you have a
                # sufficient map of the subloops crossed by the subloop you're trying to
                # slide over you can calculate the end state directly.

                # we prefer to eliminate 2 crossings if we can, but we'll eliminate
                # only one if that's the best option we have.  Prefer the first
                # found.
                my %fallback-action;

                ADJACENT_PAIR: for @same-position-adjacent-segments -> @adjacent-pair {
                    # the maths are easier if we use a segment/crossing ordering
                    # in which the found pair is the first and last segment in the
                    # ordering
                    my @reordered-segments = @ordered-segments.rotate( %indexes-by-segment{ @adjacent-pair[1] } );
                    my %reindexes-by-segment = @reordered-segments.antipairs;

                    my @partners = @adjacent-pair.map( { .crossing.segments[ over - .position ] } ).sort( { %reindexes-by-segment{ $^a } <=> %reindexes-by-segment{ $^b } } );

                    # call the strand formed by @adjacent-pair 'A', the strand
                    # formed by @partners 'B', the strand formed from
                    # A.successor -> B.predecessor 'C', and the strand formed from
                    # B.successor -> A.predecessor 'D'.
                    my $a-start = %reindexes-by-segment{ @adjacent-pair[0] };
                    my $a-end = %reindexes-by-segment{ @adjacent-pair[1] };
                    my $b-start = %reindexes-by-segment{ @partners[0] };
                    my $b-end = %reindexes-by-segment{ @partners[1] };

                    my $inline-involved = SetHash.new;
                    my $also-involved = SetHash.new;

                    for $b-start ^..^ $b-end -> $i {
                        my $segment = @reordered-segments[ $i ];
                        my $segment-partner = $segment.crossing.segments[ over - $segment.position ];

                        $inline-involved{ $segment } = True;

                        my $segment-partner-index = %reindexes-by-segment{ $segment-partner };
                        if $segment-partner-index < $b-start or $segment-partner-index > $b-end {
                            $also-involved{ $segment-partner } = True;
                        }
                        else {
                            # will come up as inline-involved on its own
                        }
                    }

                    if !$also-involved {
                        # the other strand is a self-contained subknot, so no new crossings are needed
                        $did-reduce = True;
                        last REDUCE if $check-only;
                        self.excise( to-remove => [ |@adjacent-pair, |@partners ] );
                        redo REDUCE;
                    }

                    # need to check $also-involved to see how many crossings we'd
                    # need to introduce.  at this point we know that, at best,
                    # we'll only be able to eliminate one crossing, so no point
                    # in looking further if we already have our fallback selected
                    next ADJACENT_PAIR if %fallback-action;

                    # @adjacent-pair and @partners[0] .. @partners[1] separate the rest
                    # of the tangle into two substrands:
                    #   @adjacent-pair[0] ^..^ @partners[0]
                    #   @partners[1] ^..^ @adjacent-pair[1]

                    my @tracking;

                    @tracking[ $a-start ] = 'A';
                    @tracking[ $a-end ] = 'A';
                    for $b-start .. $b-end -> $i {
                        @tracking[ $i ] = 'B';
                    }

                    for $also-involved.keys -> $involved-segment {
                        my $i = %reindexes-by-segment{ $involved-segment };
                        @tracking[ $i ] = $i;
                    }

                    # this transform will only be considered iff there are involved
                    # segments in one of strand C or strand D, but not both.
                    # we already know that there are involved segments in at least
                    # one of them...
                    my $c-range = $a-end ^..^ $b-start;
                    my $d-range = $b-end ^..^ $a-start;
                    my $has-c = @tracking[ $c-range.cache ].grep( { $_ } );
                    my $has-d = @tracking[ $d-range.cache ].grep( { $_ } );
                    next unless $has-c ^^ $has-d;

                    if $has-c {
                        # if all of C is included, we don't have to add any crossings
                        # but we can only remove one crossing, so still a net reduction
                        if $has-c.cache == $c-range.cache {
                            # the two sequences have the same number of values,
                            # which means, based on how they are constructed,
                            # that they are identical values
                            # I have resisted the urge to compare the lists that I
                            # know are identical to prove that they are identical,
                            # but if that is desired it can be done with:
                            #   [&&] $has-c.cache »==« $c-range.cache
                            if @adjacent-pair[0].crossing === @partners[1].crossing {
                                # this means that there are two completely isolated
                                # substrands, A-C-B and D, which are joined together
                                # at the $b-end/$a-start crossing.  this crossing
                                # can be eliminated as if it were a simple twist,
                                # which we do immediately
                                %fallback-action<to-remove> = [ @adjacent-pair[0], @partners[1] ];
                            }
                            else {
                                # this tangle is imaginary and I don't
                                # know how to reduce it from this configuration
                            }
                            next;
                        }

                        # if neither the immediate successor to A is included nor
                        # the immediate predecessor to B is included, then abort
                        # because we can't reduce the overall number of crossings
                        # by performing this operation
                        # also abort if both are present, because that means that
                        # we have multiple unconnected ranges and therefore also
                        # can't reduce the overall number of crossings
                        next unless @tracking[ $a-end + 1 ] xor @tracking[ $b-start - 1 ];

                        my $range = $a-end ^..^ $b-start;
                        my $ascending = True;

                        if @tracking[ $b-start - 1 ] {
                            $range = $range.reverse;
                            $ascending = False;
                        }

                        my $seen-break = False;
                        my $last-inside;

                        for $range -> $i {
                            if $seen-break and @tracking[ $i ] {
                                next ADJACENT_PAIR;
                            }

                            if @tracking[ $i ] {
                                $last-inside = @reordered-segments[ $i ];
                            }
                            else {
                                $seen-break = True;
                            }
                        }

                        %fallback-action<to-remove> = [ |@adjacent-pair, |@partners ];
                        # this logic relies on the policy that there are PlainSegments both before
                        # and after all CrossedSegments
                        %fallback-action{ @adjacent-pair[0].position } = @adjacent-pair[0].successor;
                        if $ascending {
                            %fallback-action{ over - @adjacent-pair[0].position } = $last-inside.successor;
                        }
                        else {
                            %fallback-action{ over - @adjacent-pair[0].position } = $last-inside.predecessor;
                        }
                    }
                    else { # $has-d
                        # if all of D is included, we don't have to add any crossings
                        # but we can only remove one crossing, so still a net reduction
                        if $has-d.cache == $d-range.cache {
                            # the two sequences have the same number of values,
                            # which means, based on how they are constructed,
                            # that they are identical values
                            # I have resisted the urge to compare the lists that I
                            # know are identical to prove that they are identical,
                            # but if that is desired it can be done with:
                            #   [&&] $has-d.cache »==« $d-range.cache
                            if @adjacent-pair[1].crossing === @partners[0].crossing {
                                # this means that there are two completely isolated
                                # substrands, B-D-A and C, which are joined together
                                # at the $a-end/$b-start crossing.  this crossing
                                # can be eliminated as if it were a simple twist,
                                # which we do immediately
                                %fallback-action<to-remove> = [ @adjacent-pair[1], @partners[0] ];
                            }
                            else {
                                # this tangle is imaginary and I don't
                                # know how to reduce it from this configuration
                            }
                            next;
                        }

                        # if neither the immediate successor to B is included nor
                        # the immediate predecessor to A is included, then abort
                        # because we can't reduce the overall number of crossings
                        # by performing this operation
                        # also abort if both are present, because that means that
                        # we have multiple unconnected ranges and therefore also
                        # can't reduce the overall number of crossings
                        next unless @tracking[ $b-end + 1 ] xor @tracking[ $a-start - 1 ];

                        my $range = $b-end ^..^ $a-start;
                        my $ascending = True;

                        if @tracking[ $a-start - 1 ] {
                            $range = $range.reverse;
                            $ascending = False;
                        }

                        my $seen-break = False;
                        my $last-inside;

                        for $range -> $i {
                            if $seen-break and @tracking[ $i ] {
                                next ADJACENT_PAIR;
                            }

                            if @tracking[ $i ] {
                                $last-inside = @reordered-segments[ $i ];
                            }
                            else {
                                $seen-break = True;
                            }
                        }

                        if !$last-inside {
                            dd $range, $seen-break, $last-inside, @tracking, $a-start, $a-end, $b-start, $b-end;
                            die;
                        }

                        %fallback-action<to-remove> = [ |@adjacent-pair, |@partners ];
                        # this logic relies on the policy that there are PlainSegments both before
                        # and after all CrossedSegments
                        %fallback-action{ @adjacent-pair[0].position } = @adjacent-pair[0].successor;
                        if $ascending {
                            %fallback-action{ over - @adjacent-pair[0].position } = $last-inside.successor;
                        }
                        else {
                            %fallback-action{ over - @adjacent-pair[0].position } = $last-inside.predecessor;
                        }
                    }
                }

                if %fallback-action {
                    $did-reduce = True;
                    last REDUCE if $check-only;
                    self.excise( to-remove => %fallback-action<to-remove> );
                    if %fallback-action<over> or %fallback-action<under> {
                        self.cross( over => %fallback-action<over>, under => %fallback-action<under> );
                    }
                    redo REDUCE;
                }
            }

=begin comment
            my $seen-crossings = SetHash.new;
            my @ordered-crossings;

            for @ordered-segments -> $segment {
                next if $seen-crossings{ $segment.crossing };
                $seen-crossings{ $segment.crossing } = True;
                @ordered-crossings.push( $segment.crossing );
            }

            my %indexes-by-crossing = @ordered-crossings.antipairs;

            # the canon ordering will always place a self-contained
            # subknot at the front of the tangle, preferring the
            # shortest if there are multiple
            my $highest-segment-index-seen = -∞;

            for @ordered-crossings -> $crossing {
                my $crossing-highest-index = $crossing.segments.map( { %indexes-by-segment{ $_ } } ).max;

                if $crossing-highest-index > $highest-segment-index-seen {
                    $highest-segment-index-seen = $crossing-highest-index;
                }

                # early out for when we know there can't be a self-contained subknot
                last if $highest-segment-index-seen == @ordered-segments;

                if $highest-segment-index-seen == 1 + 2 * %indexes-by-crossing{ $crossing } {
                    # we've looked at N crossings, covering 2N segments, and the
                    # highest segment index we've seen is 2N-1, meaning that we've
                    # found a self-contained subknot

                    my $segment-to-mark = @ordered-segments[0].predecessor;

                    my @removed = self.excise-inclusive( first => @ordered-segments[0], last => @ordered-segments[ $highest-segment-index-seen ], exclude-marked => False );

                    @subknots.push( @removed );
                }
            }
=end comment
        }

        # TODO - restore marked excised subknots

        return $did-reduce;
    }
};

