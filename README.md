# MoonPlan

An explainable multi-objective constraint solver written in MoonBit. MoonPlan
ranks concrete time, topic, and venue choices using attendance, shared
interest, travel fairness, uncertainty, and explicit hard constraints.

## Why it exists

Picking a time by simple intersection often creates an unfair result: a plan
can work for the most people while making one member travel much farther.
MoonPlan is product-neutral: use it for social events, study groups, team
offsites, or any group decision with time and venue constraints.

## Run

```bash
moon test
moon run cmd/main
moon build --target js
```

The command prints a runnable campus scenario. The core is dependency-free and
supports native and JavaScript builds.

## Current scoring model

The legacy demo uses:

`score = participants * 100 + interest_matches * 20 - travel_gap`

`PlannerConfig` makes these weights explicit. `VenuePolicy` adds a hard travel
limit and a penalty for high average travel. An option that cannot form a
viable group is not recommended at all.

## What makes this more than a time-intersection demo

- **Attendance:** reward plans that more people can actually join.
- **Shared interest:** distinguish a technically possible plan from one people
  will enjoy.
- **Travel fairness:** penalize plans that shift a large commute onto one
  person.
- **Real intervals:** the product API uses dated start/end minutes, so the
  planner checks that an activity fits a whole availability window.
- **Venue-aware feasibility:** each venue supplies a member-by-member travel
  estimate; time conflict, travel over-limit, and missing travel data are
  distinct states.
- **Hard constraints:** minimum group size and named required attendees are
  checked before scoring, so a key participant is never silently sacrificed.
- **Explainability:** every result includes counts, average travel, travel gap,
  and the number excluded by schedule or distance. Rejected options retain a
  concrete reason for product UI or post-hoc review.
- **Honest trade-offs:** a Pareto frontier and three UI highlights (most
  inclusive, least travel, best interest fit) avoid hiding meaningful choices
  behind one score.
- **Recovery:** rejected timed options are checked at +/-30 and +/-60 minutes;
  feasible changes become repair suggestions.

## API highlights

- `analyze_timed_options`: real dated time windows, travel limits, required
  members, and optional all-member mode.
- `DecisionReport`: score-ranked results, Pareto frontier, named UI highlights,
  rejected options, and time-shift repairs.
- `TimedVenue`: `Some(minutes)` is a known route; `None` means route data is
  incomplete and remains visible to callers.

## First integration: 聚聚星

The versioned request contract, a CommonJS input normalizer, and a sample live
in [`docs/聚聚星接入设计.md`](docs/聚聚星接入设计.md). The scoring module remains
independent and testable, so it can be evaluated without map credentials, user
accounts, or cloud functions.

## Development

```bash
moon fmt
moon test --deny-warn
moon build --target js
node integration/juju-planner-contract.test.js
```

See [CONTRIBUTING.md](CONTRIBUTING.md), [CHANGELOG.md](CHANGELOG.md), and the
[Chinese competition proposal](docs/项目申报书.md).
