
use v6;

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
        transition inline - N|1,→

    transition inline - compact
       ┌──┐
       │┌╖│
       ╘╪╫╪╕
        │╙┘│
        └──┘
    
    transition inline - N|0
       ┌─────┐
       │ ┌─╖ │
       │1│5║3│  
       ╘═╪─╫═╪╕
        4│2║6││
         │ ╙─┘│
         └────┘
    
    transition inline - N|0,→
       ┌────────┐
       │  ┌──╖  │
       │1→│5↓║3→│  
       ╘══╪──╫══╪╕
        4↑│2→║6↑││
          │  ╙──┘│
          └──────┘
    
    transition inline - N|1
       ┌───────┐
       │ ┌──╖  │
       │1│ 5║ 3│  
       ╘═╪═─╫─═╪═╕
        4│ 2║ 6│ │
         │  ╙──┘ │
         └───────┘
    
    transition inline - N|1,→
       ┌──────────┐
       │  ┌───╖   │
       │1→│ 5↓║ 3→│  
       ╘══╪═──╫─══╪═╕
        4↑│ 2→║ 6↑│ │
          │   ╙───┘ │
          └─────────┘
    
    transition inline - N+1|0
       ┌────────┐
       │  ┌──╖  │
       │ 1│ 5║ 3│  
       ╘══╪──╫══╪╕
         4│ 2║ 6││
          │  ╙──┘│
          └──────┘
    
    transition inline - N+1|0,→
       ┌───────────┐
       │   ┌───╖   │
       │ 1→│ 5↓║ 3→│  
       ╘═══╪───╫═══╪╕
         4↑│ 2→║ 6↑││
           │   ╙───┘│
           └────────┘
    
    transition inline - N+1|1
       ┌──────────┐
       │  ┌───╖   │
       │ 1│  5║  3│  
       ╘══╪═──╫─══╪═╕
         4│  2║  6│ │
          │   ╙───┘ │
          └─────────┘
    
    transition inline - N+1|1,→
       ┌─────────────┐
       │   ┌────╖    │
       │ 1→│  5↓║  3→│  
       ╘═══╪═───╫─═══╪═╕
         4↑│  2→║  6↑│ │
           │    ╙────┘ │
           └───────────┘
    
    transition only on corner - compact
       ┌────┐
       │┌──┐│
       ╘╪═╕││
        │╒╪╛│
        ││╘═╪╕
        │└──┘│
        └────┘
    
    transition only on corner - N|0
       ┌──────┐
       │ ┌───┐│
       │1│   ││
       ╘═╪══╕││
        4│ 5│││
         │╒═╪╛│
         ││2│3│ 
         ││ ╘═╪╕
         ││  6││
         │└───┘│
         └─────┘
    
    transition only on corner - N|0,→
       ┌─────────┐
       │  ┌────┐ │
       │1→│    │ │
       ╘══╪═══╕│ │
        4↑│ 5←││ │
          │╒══╪╛ │
          ││2↓│3→│ 
          ││  ╘══╪╕
          ││   6↑││
          │└─────┘│
          └───────┘
    
    transition only on corner - N|1
       ┌───────┐
       │ ┌────┐│
       │1│    ││
       ╘═╪══╕ ││
        4│ 5│ ││
         │╒═╪═╛│
         ││2│ 3│ 
         ││ ╘══╪═╕
         ││   6│ │
         │└────┘ │
         └───────┘
    
    transition only on corner - N|1,→
       ┌─────────┐
       │  ┌─────┐│
       │1→│     ││
       ╘══╪═══╕ ││
        4↑│ 5←│ ││
          │╒══╪═╛│
          ││2↓│3→│ 
          ││  ╘══╪═╕
          ││   6↑│ │
          │└─────┘ │
          └────────┘
    
    transition only on corner - N+1|0
       ┌─────────┐
       │  ┌────┐ │
       │ 1│    │ │
       ╘══╪═══╕│ │
         4│  5││ │
          │╒══╪╛ │
          ││ 2│ 3│ 
          ││  ╘══╪╕
          ││    6││
          │└─────┘│
          └───────┘
    
    transition only on corner - N+1|0,→
       ┌────────────┐
       │   ┌─────┐  │
       │ 1→│     │  │
       ╘═══╪════╕│  │
         4↑│  5←││  │
           │╒═══╪╛  │
           ││ 2↓│ 3→│ 
           ││   ╘═══╪╕
           ││     6↑││
           │└───────┘│
           └─────────┘
    
    transition only on corner - N+1|1
       ┌─────────┐
       │  ┌─────┐│
       │ 1│     ││
       ╘══╪═══╕ ││
         4│  5│ ││
          │╒══╪═╛│
          ││ 2│ 3│ 
          ││  ╘══╪═╕
          ││    6│ │
          │└─────┘ │
          └────────┘
    
    transition only on corner - N+1|1,→
       ┌────────────┐
       │   ┌──────┐ │
       │ 1→│      │ │
       ╘═══╪════╕ │ │
         4↑│  5←│ │ │
           │╒═══╪═╛ │
           ││ 2↓│ 3→│ 
           ││   ╘═══╪═╕
           ││     6↑│ │
           │└───────┘ │
           └──────────┘
    
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
    
possible step-by-step method
(needs revised to give more room between crossings and lines)
 ·····
 ·····
 ·····
 ···╪·
 ·····
    start
    moving forward (east)
    placed new crossing

 ·······
 ·······
 ·······
 ···╪-╫·
 ·······
    moving forward (east)
    placed new crossing

 ·········
 ·········
 ·········
 ···╪-╫-╪·
 ·········
    moving forward (east)
    placed new crossing

 ···········
 ···········
 ···········
 ···╪-╫-╪-?·
 ···········
    moving forward (east)
    seeking existing crossing
  
 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-↻·   ···╪-╫-╪-↺·
 ···········   ···········
    exploring CW|CCW (south|north)
    seeking existing crossing

 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-╕·   ·········↻·
 ·········|·   ·········|·
 ·········↻·   ···╪-╫-╪-╛·
 ···········   ···········
    exploring CW|CCW (south|north)
    seeking existing crossing

 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-╕·   ·······↺-┐·
 ·········|·   ·········|·
 ·······↻-┘·   ···╪-╫-╪-╛·
 ···········   ···········
    exploring CW|CCW (west|west)
    seeking existing crossing

 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-╕·   ·····↺---┐·
 ·········|·   ·········|·
 ·····↻---┘·   ···╪-╫-╪-╛·
 ···········   ···········
    exploring CW|CCW (west|west)
    seeking existing crossing

 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-╕·   ···↺-----┐·
 ·········|·   ·········|·
 ···↻-----┘·   ···╪-╫-╪-╛·
 ···········   ·············
    exploring CW|CCW (west|west)
    seeking existing crossing


 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-╕·   ···┌-----┐·
 ···|·····|·   ···|·····|·
 ···└-----┘·   ···╪-╫-╪-╛·
 ···········   ···········
    exploring CW|CCW (north|south)
    seeking existing crossing
    found CW and CCW paths

 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···╪-╫-╪-╕·   ···┌-----┐·
 ···|·····|·   ···|·····|·
 ···|·····|·   ···|·····|·
 ···|·····|·   ···|·····|·
 ···└-----┘·   ···╪-╫-╪-╛·
 ···········   ···········
    encroachment fixup

 ···········   ···········
 ···········   ···········
 ···········   ···········
 ···?·······   ···┌-----┐·
 ···|·······   ···|·····|·
 ···╪-╫-╪-╕·   ···|·····|·
 ···|·····|·   ···|·····|·
 ···|·····|·   ···╪-╫-╪-╛·
 ···|·····|·   ···|·······
 ···└-----┘·   ···?·······
 ···········   ···········
    moving forward (north|south)
    seeking existing crossing

  ↻          ↺
  |          |
  ╪-╫-╪-╕    ╪-╫-╪-╕ 
  |     |    |     |
  └-─-─-┘    └-─-─-┘
    exploring CW|CCW (east|west)
    seeking existing crossing

  ┌-↻      ↺-┐
  |          |
  ╪-╫-╪-╕    ╪-╫-╪-╕ 
  |     |    |     |
  └-─-─-┘    └-─-─-┘
    exploring CW|CCW (east|west)
    seeking existing crossing

  ┌-╖      ┌-┐
  | ║      | |
  ╪-╫-╪-╕  ↺ ╪-╫-╪-╕ 
  |     |    |     |
  └-─-─-┘    └-─-─-┘
    exploring CW|CCW
    seeking existing crossing
    found CW path (south)

  ┌-╖    
  | |    
  ╪-╫-╪-╕
  |     |
  └-─-─-┘
    chose CW path
    moving forward (south)
    seeking existing crossing

  ┌-╖    
  | |    
  ╪-╫-╪-╕
  | |   |
  │ ?   │
  |     |
  └-─-─-┘
    internal expansion
    moving forward (south)
    seeking existing crossing

  ┌-╖    
  | |    
  ╪-╫-╪-╕
  | |   |
  │ ╙-? │
  |     |
  └-─-─-┘
    moving forward (east)
    seeking existing crossing

  ┌-╖    
  | |    
  ╪-╫-╪-╕
  | | | |
  │ ╙-┘ │
  |     |
  └-─-─-┘
    moving forward (north)
    seeking existing crossing

  ┌-╖ ?  
  | | |  
  ╪-╫-╪-╕
  | | | |
  │ ╙-┘ │
  |     |
  └-─-─-┘
    moving forward (north)
    seeking existing crossing

    ┌-╖ ↺      ┌-╖ ↻  
    | | |      | | |  
    ╪-╫-╪-╕    ╪-╫-╪-╕
    | | | |    | | | |
    │ ╙-┘ │    │ ╙-┘ │
    |     |    |     |
    └-─-─-┘    └-─-─-┘
    exploring CW|CCW (east|north)
    seeking existing crossing

        ↺
        |
    ┌-╖ │      ┌-╖ ┌-↻
    | | |      | | |  
    ╪-╫-╪-╕    ╪-╫-╪-╕
    | | | |    | | | |
    │ ╙-┘ │    │ ╙-┘ │
    |     |    |     |
    └-─-─-┘    └-─-─-┘
    exploring CW|CCW (east|north)
    seeking existing crossing

      ↺-┐
        |
    ┌-╖ │      ┌-╖ ┌-─-↻
    | | |      | | |  
    ╪-╫-╪-╕    ╪-╫-╪-╕
    | | | |    | | | |
    │ ╙-┘ │    │ ╙-┘ │
    |     |    |     |
    └-─-─-┘    └-─-─-┘
    exploring CW|CCW (east|west)
    seeking existing crossing

    ↺-─-┐
        |
    ┌-╖ │      ┌-╖ ┌-─-┐
    | | |      | | |   |
    ╪-╫-╪-╕    ╪-╫-╪-╕ ↻
    | | | |    | | | |
    │ ╙-┘ │    │ ╙-┘ │
    |     |    |     |
    └-─-─-┘    └-─-─-┘
    exploring CW|CCW (south|west)
    seeking existing crossing

  ↺-─-─-┐
        |
    ┌-╖ │      ┌-╖ ┌-─-┐
    | | |      | | |   |
    ╪-╫-╪-╕    ╪-╫-╪-╕ │
    | | | |    | | | | |
    │ ╙-┘ │    │ ╙-┘ │ ↻
    |     |    |     |
    └-─-─-┘    └-─-─-┘
    exploring CW|CCW (south|west)
    seeking existing crossing

  ┌-─-─-┐
  |     |
  ↺ ┌-╖ │      ┌-╖ ┌-─-┐
    | | |      | | |   |
    ╪-╫-╪-╕    ╪-╫-╪-╕ │
    | | | |    | | | | |
    │ ╙-┘ │    │ ╙-┘ │ │
    |     |    |     | |
    └-─-─-┘    └-─-─-┘ ↻
    exploring CW|CCW (south|south)
    seeking existing crossing

  ┌-─-─-┐
  |     |
  │ ┌-╖ │      ┌-╖ ┌-─-┐
  | | | |      | | |   |
  ↺ ╪-╫-╪-╕    ╪-╫-╪-╕ │
    | | | |    | | | | |
    │ ╙-┘ │    │ ╙-┘ │ │
    |     |    |     | |
    └-─-─-┘    └-─-─-┘ │
                       |
                       ↻
    exploring CW|CCW (south|south)
    seeking existing crossing

  ┌-─-─-┐
  |     |
  │ ┌-╖ │      ┌-╖ ┌-─-┐
  | | | |      | | |   |
  ╘-╪-╫-╪-╕    ╪-╫-╪-╕ │
    | | | |    | | | | |
    │ ╙-┘ │    │ ╙-┘ │ │
    |     |    |     | |
    └-─-─-┘    └-─-─-┘ │
                       |
                     ↻-┘
    exploring CW|CCW (west|east)
    seeking existing crossing
    found CCW path

  ┌-─-─-┐
  |     |
  │ ┌-╖ │
  | | | |
  ╘-╪-╫-╪-╕
    | | | |
    │ ╙-┘ │
    |     |
    └-─-─-┘
    chose CCW path
    moving forward (east)
    complete

  ┌──┐
  │┌╖│
  ╘╪╫╪╕
   │╙┘│
   └──┘
    complete
    rendered - compact

=end comment

class Dowker {
    has @.numbers;

    submethod BUILD( Str:D :$notation ) {
        if $notation !~~ /^ [ '-'? [ <[2468]> | <[1..9]>+ <[24680]> ] ]+ % ' ' $/ {
            fail "invalid Dowker notation ($notation), invalid characters or numbers";
        }

        my @numbers = $notation.split( ' ' )».Int;

        my $uniq-numbers = |@numbers.Set;

        if $uniq-numbers.elems != @numbers.elems {
            fail "invalid Dowker notation, duplicates ( { $uniq-numbers.elems } vs. { @numbers.elems } )";
        }

        if @numbers.grep( *.abs > 2 * @numbers.elems ) {
            fail "invalid Dowker notation, crossing numbers out of range";
        }

        @!numbers = @numbers;
    }
};

enum CrossingPosition <under over>;

class Segment { ... };
class Segment {
    has Segment $.successor is rw;
    has Segment $.predecessor is rw;
};

class PlainSegment is Segment {
    method split( Bool:D :$after = True ) {
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

class Crossing {
    has @.segments[2] is rw;
};

class MarkedSegment is Segment {
    # thought:
    #   the mark can be of any type,
    #   so I could use it to simultaneously
    #   mark the location of an excised subset
    #   of a tangle *and* store the excised segments!
    has $.mark is rw;
};

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
# plotting layer:
#   holds plotted lines and crossings
#   holds current plotting location
#   shifts rows and columns
#   even numbered rows and columns never contain turns or crossings, this allows them to replicated for expansion
#   a gap of at least one odd column/row will be maintained as an aid to the pathfinding
#       this is detected and adjusted whenever plotting, whether on even or odd
#   whenever something is plotted into the 1 row/column, the 0 row/column will be replicated to push the
#       newly-plotted data into the 3 row/column
#   aside from the shift to keep the 0 row/column empty, it is critical that no other shifting be done while
#       seeking.  the shifting to maintain spacing must be done as a cleanup step between seeks.
#   another between-seeks cleanup task will be straightening paths, done where a path has empty space between one
#       of its segments and another of its segments.  this is done before encroachment is detected and corrected.
#       both of these things are only done for the newly-plotted path.

# (0,0) is the lower left corner
enum PlottingHeading <ph-pos-x ph-pos-y ph-neg-x ph-neg-y>;
enum PlottingDirection <pd-left pd-ahead pd-right pd-back>;

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

my %movmentChart = (
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

class PlottingGrid {
    has @!cells;
    has $!head-x;
    has $!head-y;
    has PlottingHeading $!heading;
    has @!uncommitted;
    has SetHash $!dangling;

    multi submethod BUILD( PlottingGrid:D :$original ) {
        fail "original not in copyable state" unless $original.canCopy();
        @!cells = $original.cells.deepmap( -> $c is copy { $c } );
        $!head-x = $original.head-x;
        $!head-y = $original.head-y;
        $!heading = $original.heading;
    };

    multi submethod BUILD() {
        @!cells = {} xx 3 xx 3;
        $!head-x = 1;
        $!head-y = 1;
        $!heading = ph-pos-x;
    };

    method canCopy {
        return @!uncommitted.elems == 0;
    }

    multi method copy-insert-before( Int:D :$x ) {
        fail "invalid x: $x" if $x % 2 || $x > @!cells.elems || $x < 0;

        @!cells.splice( $x, 0, @!cells[$x].deepmap( -> $c is copy { $c } ), @!cells[$x].deepmap( -> $c is copy { $c } ) );

        if $head-x >= $x {
            $head-x += 2;
        }

        return;
    }

    multi method copy-insert-before( Int:D :$y ) {
        fail "invalid y: $y" if $y % 2 || $y > @!cells[0].elems || $y < 0;

        @!cells.map( -> $t is rw { $t = ( |$t[ 0 ..^ $y ], $t[ $y ].deepmap( -> $c is copy { $c } ), $t[ $y ].deepmap( -> $c is copy { $c } ), |$t[ $y .. * ] ) } );

        if $head-y >= $y {
            $head-y += 2;
        }

        return;
    }

    method turn( PlottingDirection:D :$direction ) {
        $!heading = $turnChart{ $!heading }{ $direction };

        return;
    }

    method look( PlottingDirection:D :$direction ) {
        my $facing = $turnChart{ $!heading }{ $direction };
        my $into = turnChart{ $facing }{ pd-back };

        my $Δx = %movementChart{ $facing }< Δx >;
        my $Δy = %movementChart{ $facing }< Δy >;

        my $x = $!head-x;
        my $y = $!head-y;

        while( $x >= 0 and $x <= @!cells.elems and $y >= 0 and $y <= @!cells[0].elems ) {
            my %cell = $!cells[ $x ][ $y ];

            if %cell< segment >:exists {
                if %cell< dangling >:exists and %cell< dangling >{ $into }:exists {
                    return %cell< dangling >{ $into };
                }

                return Nil;
            }

            $x += $Δx;
            $y += $Δy;
        }

        return Nil;
    }

    multi method advance() {
        my $Δx = %movementChart{ $!heading }< Δx >;
        my $Δy = %movementChart{ $!heading }< Δy >;

        my $pilot-x = $!head-x + 2 * $Δx;
        my $pilot-y = $!head-y + 2 * $Δy;

        if $pilot-x < 1 {
            self.copy-insert-before( x => 0 );
        }
        elsif $pilot-x >= @!cells.elems {
            self.copy-insert-before( x => ( @!cells.elems - 1 ) );
        }
        elsif $pilot-y < 1 {
            self.copy-insert-before( y => 0 );
        }
        elsif $pilot-y >= @!cells[0].elems {
            self.copy-insert-before( y => ( @!cells[0].elems - 1 ) );
        }

        $!head-x += $Δx;
        $!head-y += $Δy;

        my $bridge-cell = @!cells[ $!head-x ][ $!head-y ];
        fail if $bridge-cell< segment >:exists;
        $bridge-cell< pending > = True;

        self.plot( uncommitted => True, 
        @!uncommitted.push( $bridge-cell );

        $!head-x += $Δx;
        $!head-y += $Δy;

        my $pier-cell = @!cells[ $!head-x ][ $!head-y ];
        fail if $pier-cell< segment >:exists;
        $pier-cell< pending > = True;

        @!uncommitted.push( $pier-cell );

        return;
    }

    multi method advance( :$to ) {
        fail "not advancing to anything" unless $to;

        my $looking-at = self.look( pd-ahead );
        fail "not looking at anything" unless $looking-at;

        fail "not lined up" unless $looking-at == $to;

        my $Δx = %movementChart{ $!heading }< Δx >;
        my $Δy = %movementChart{ $!heading }< Δy >;

        $!head-x += $Δx;
        $!head-y += $Δy;

        my $cell = @!cells[ $!head-x ][ $!head-y ];

        while( ! $cell< segment >:exists ) {
            @!uncommitted.push( $cell );
            $cell< pending > = True;

            $!head-x += $Δx;
            $!head-y += $Δy;

            $cell = @!cells[ $!head-x ][ $!head-y ];
        }
        
        my $into = turnChart{ $!heading }{ pd-back };

        $cell< dangling >:delete;

        $!dangling{ $to } = False;

        # optimize the path

        # spread things out
    }

    method can-go( PlottingDirection:D :$direction ) {
        my $facing = $turnChart{ $!heading }{ $direction };

        my $Δx = %movementChart{ $facing }< Δx >;
        my $Δy = %movementChart{ $facing }< Δy >;

        my $x = $!head-x;
        my $y = $!head-y;

        $x += $Δx;
        $y += $Δy;

        if @!cells[ $x ][ $y ].keys {
            return False;
        }

        $x += $Δx;
        $y += $Δy;

        if @!cells[ $x ][ $y ].keys {
            return False;
        }

        return True;
    }

    method plot( ... ) { ... }
    method commit() { ... } # contains path simplification, beautification, and encroachment prevention - simplification only looks at uncommitted path
    method drawn( ... ) { ... }
    method isDrawn( ... ) { ... }
    method TStart() { ... }
    method TEnd() { ... }
    method join() { ... }
}

class Plotter {
    method plot( :@segments is copy ) {
        fail "PlottingGrid not reusable" if $!done;
        fail "non-crossing segments" if @segments.grep( { $_ !~~ CrossingSegment } );
        fail "odd number of segments" if @segments % 2;

        if @segments.elems == 0 {
            # something
            return;
        }

        my %seen-crossings;
        my %looking-for;

        my $first-segment = @segments.shift;

        %looking-for{ $first-segment } = True;
        %seen-crossings{ $first-segment.crossing } = True;

        my $x = 1;
        my $y = 1;
        my $moving = 'px';

        {
            my $partner-of-first = $first-segment.crossing.segments[ over - $first-segment.position ];
            %looking-for{ $partner-of-first } = True;

            my $cell = @!cells[ $x ][ $y ];

            $cell{ $first-segment.position } = $first-segment;
            $cell<want-nx> = $first-segment;
            $cell<want-py> = $partner-of-first;
            $cell<want-ny> = $partner-of-first;
        }

        for @segments -> $segment {
            # drift, expanding if necessary
            my $moving-lookup = %lookup-by-moving{ $moving };
            my $Δx = $moving-lookup<Δx>;
            my $Δy = $moving-lookup<Δy>;

            given $x + $Δx {
                when 0 {
                }
                when @!cells.elems {
                }
            }
        }
    }
};

# the logic here is supposed to keep at least one
# PlainSegment on each side of any segment that
# isn't a PlainSegment

class Tangle {
    use fatal;

    has SetHash $!segments; # of Segment, but SetHash cannot be parameterized
    has SetHash $.crossings; # of Crossings
    # preferred-first really should have a setter method that validates that it is in $!segments
    has Segment $.preferred-first is rw;

    submethod build-strand( Int:D :$length ) {
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

    submethod build-from-dowker( Dowker:D :$dowker ) {
        my @expanded-pairs = ( 1, 3 ... ∞ ) Z $dowker.numbers;
        self.build-strand( length => 2 * @expanded-pairs );

        my @segments = self.getOrderedList;

        for @expanded-pairs -> $dowker-pair {
            if $dowker-pair[1] < 0 {
                self.cross( over => @segments[ $dowker-pair[1].abs - 1 ], under => @segments[ $dowker-pair[0] - 1 ] );
            }
            else {
                self.cross( over => @segments[ $dowker-pair[0] - 1 ], under => @segments[ $dowker-pair[1] - 1 ] );
            }
        }
    }

    multi submethod BUILD( Dowker:D :$dowker ) {
        self.build-from-dowker( :$dowker );
    }

    multi submethod BUILD( Str:D :$dowker-str ) {
        self.build-from-dowker( dowker => Dowker.new( notation => $dowker-str ) );
    }

    multi submethod BUILD( :@tok-pairs ) {
        self.build-strand( length => 2 * @tok-pairs );

        my @segments = self.getOrderedList;

        for @tok-pairs -> @tok-pair {
            self.cross( over => @segments[ @tok-pair[1] ], under => @segments[ @tok-pair[0] ] );
        }
    }

    method asDowkerStr( Segment :$first? is copy ) {
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
            return '-';
        }
    }

    method asGaussStr( Segment :$first? is copy ) {
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

    method getOrderedList( Segment :$first? is copy ) {
        $first //= $!preferred-first // $!segments.keys[0];

        fail "not mine!" unless $first ∈ $!segments;

        my @return-list = ( $first );

        # build in reverse order to be able to look
        # always only at the 0th element
        while @return-list[0].successor !=== $first {
            @return-list.unshift( @return-list[0].successor );
        }

        return @return-list.reverse;
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
    }

    # Each tangle can be represented by an N-digit number in base
    # 2N, where N is the number of crossings, where each digit
    # represents a crossing, in the order visited (most significant
    # digit first), with a value of the number of other crossings passed
    # through to get from the first visit of the crossing to the second
    # visit of the same crossing.  While this number will always be odd
    # for all real knots and tangles, which would allow using N as the
    # number base instead of 2N, once imaginary knots and tangles are
    # allowed the distance may not necessarily be odd, so 2N will be
    # necessary.
    # The "canonical" representation of a knot chooses a first
    # segment to minimize the value of this represtational number.
    # Where there is a tie, if possible, the first crossing
    # will be chosen so that it counts from under to over.
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



if 1 {
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
    of that article a "slow teleport" is a way of traversing from point C to
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
