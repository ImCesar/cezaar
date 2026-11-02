# Scenario: Pog Roguelike, whole-game feature set

You are a game designer's assistant. Produce a one-page design document for
the game below, as a single HTML file written to the path given at the end.
The reader is a programmer who has never seen the design. They should get
the whole game from the page.

## The design

Single-player roguelike on desktop, mouse and controller, against AI
opponents. Core loop: one stack of pogs built from both combatants' rosters
combined. You aim a slammer and it drops with real physics. Pogs that land
face up activate their effect for the slammer, whoever contributed them;
effects can help or hurt the slammer. Everything that did not flip is
shuffled into a fresh pile. When the pile is low, the discard is shuffled
back in. Turns alternate until one combatant is dead.

Readability: a 3D tower in the middle, and a strip beside it listing every
pog top to bottom with its icon, value and contributor colour, plus a
bracket showing how deep the chosen slammer usually reaches from the aim
point. Effects resolve one at a time top-down, each with a number popping
up, then a summary card.

Slammers: three, by striking-face shape. Dome (flips the top few), Ring
(hollow, tips one side), Flat (broad, reaches deep). You own up to three and
choose one before each fight after seeing the opponent's roster.

Effects (placeholders): Strike 4, Heal 3, Poison 3 (hurts the slammer),
Guard 3, Drain 2, Recoil (them -6, you -2), Deep Strike (doubled from the
bottom half), Capstone (+2 if on top). Pogs may be Heavy, Slick or Sticky.

Roster: eight slots. After each fight take one of three offered pogs into
an empty slot, or remove one, never both. Three copies of a pog merge into
a stronger one (numbers x1.5) and free two slots. An empty slot holds a
Blank pog with no effect so the tower is always 16 high. Opponents field
eight slots too.

Run: a branching map of about 12 nodes ending in a boss, 40 to 50 minutes.
Node types: fight, elite, shop (charms and slammers), rest (heals 30%).
Health carries over between fights. Items are charms: number-only, three
slots, they fire only on the holder's own slam.

Risks the design must answer: an obvious best shot; unreadable outcomes;
shared healing prolonging fights (Heals lose 1 point each reshuffle);
poison stalls (a slam that flips nothing is a dud and costs 1 health);
conversion items erasing trade-offs; long animations (3 s turn budget).

## Output

Write the HTML to: {OUTPUT_PATH}
Then reply with three sentences on what you made and why it is shaped
that way.
