# KCD2 Farkle Optimizer — Design

## Goal
A native macOS app (SwiftUI, Swift Package) that (1) recommends which six dice to
play from the user's inventory and (2) during a match recommends which rolled dice to
hold and whether to *Score and Continue* or *Score and Pass*, using the KCD2 dice rules
and the per-face weights of every special die.

## Assumptions
- Scoring: 1 = 100, 5 = 50, three of a kind = face×100 (1s = 1000), each extra die of
  the kind doubles; straights 1-5 = 500, 2-6 = 750, 1-6 = 1500. No three-pairs. A held
  selection must consist entirely of scoring units. Hot dice: holding all six lets you
  roll all six again. Any roll with no scoring unit busts the turn.
- The opponent plays six ordinary dice and follows a sensible expected-score policy.
  Badges are out of scope.
- Reaching or exceeding the goal on a bank wins immediately.
- The user always has enough ordinary dice to fill a set of six.

## Architecture (Swift Package, macOS 14+)
- `FarkleCore` (library, no UI, fully tested)
  - `DieType`: name + six face weights; catalog of all dice from the KCD2 table.
  - `Scoring`: best score of a face-count vector (nil when not fully scorable).
  - `TurnModel`: for a six-die set, groups dice by identical type (symmetry
    reduction), enumerates every roll outcome per remaining-dice state, and stores
    the distinct "option sets" (next state, score) with their probability.
  - `TurnSolver`: generic backward DP over (turn total in 50-point units, remaining
    state) with pluggable bank/bust rewards; forward pass producing the banked-score
    distribution for each remaining-to-goal cap.
  - `GameSolver`: win-probability table P(me to move | my score, opp score) from the
    two players' turn distributions under fixed policies (2×2 linear solve for the
    double-bust self loop).
  - `RollAdvisor`: for the live situation, runs the DP with win-probability rewards
    (one step of policy improvement over the table) and ranks every legal hold with
    Continue vs Pass values.
  - `SetOptimizer`: enumerates multisets of owned special dice (≤6, ordinary fill),
    ranks by expected turn score in parallel, re-ranks the top few by win probability.
- `FarkleOptimizer` (executable, SwiftUI): two screens, "Dice Bag" and "Table",
  KCD2-styled (dark leather, parchment panels, bronze/gold accents, serif type, pip dice).
- `scripts/make-app.sh` assembles a `.app` bundle from the release build.

## Data flow
Inventory → SetOptimizer → chosen set → TurnModel + win table (cached per set/goal)
→ Table screen: scores, goal, held/rolled dice, turn points → RollAdvisor → advice.

## Testing
XCTest on FarkleCore: scoring table cases, legal selections, probability mass
conservation, DP sanity (ordinary-dice expected turn score in known range, first-mover
win probability slightly above 0.5), advisor endgame behaviour (bank when the bank wins).
