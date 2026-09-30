///|
/// A participant's constraints for a possible group activity.
pub struct Member {
  name : String
  availability : Array[Int]
  interests : Array[String]
  travel_cost : Int
}

///|
/// Create a participant without exposing mutable internal state.
pub fn Member::new(
  name : String,
  availability : Array[Int],
  interests : Array[String],
  travel_cost : Int,
) -> Member {
  Member::{ name, availability, interests, travel_cost, }
}

///|
/// A ranked group-activity recommendation.
pub struct Plan {
  slot : Int
  interest : String
  participant_count : Int
  interest_match_count : Int
  travel_gap : Int
  score : Int
  explanation : String
}

///|
/// A candidate venue. `commute_minutes[i]` belongs to `members[i]`.
/// Keeping the matrix in the input makes venue trade-offs explicit and keeps
/// the core independent of any map provider.
pub struct Venue {
  name : String
  commute_minutes : Array[Int]
}

///|
/// Build a venue from per-member travel estimates.
pub fn Venue::new(name : String, commute_minutes : Array[Int]) -> Venue {
  Venue::{ name, commute_minutes, }
}

///|
/// One concrete activity choice: topic, time, and venue.
pub struct ActivityOption {
  slot : Int
  interest : String
  venue : Venue
}

///|
/// Build an activity option.
pub fn ActivityOption::new(
  slot : Int,
  interest : String,
  venue : Venue,
) -> ActivityOption {
  ActivityOption::{ slot, interest, venue, }
}

///|
/// A venue-aware recommendation with inclusion and exclusion evidence.
pub struct DetailedPlan {
  slot : Int
  interest : String
  venue_name : String
  participant_count : Int
  interest_match_count : Int
  average_travel : Int
  travel_gap : Int
  attendees : Array[String]
  unavailable : Array[String]
  too_far : Array[String]
  score : Int
  explanation : String
}

///|
/// A concrete option that was rejected by a non-negotiable group rule.
pub struct RejectedOption {
  slot : Int
  interest : String
  venue_name : String
  reason : String
}

///|
/// The complete decision record: ranked viable options plus transparent
/// rejections. A UI can show both rather than presenting a black-box winner.
pub struct RecommendationReport {
  recommended : Array[DetailedPlan]
  rejected : Array[RejectedOption]
}

///|
/// Scoring policy for one planning context.
///
/// The defaults favor attendance, while still rewarding shared interest and
/// protecting a member from bearing a disproportionate travel burden.
pub struct PlannerConfig {
  participation_weight : Int
  interest_weight : Int
  travel_gap_penalty : Int
  min_participants : Int
}

///|
/// Build a scoring policy. The weights are explicit product decisions rather
/// than hidden constants, so callers can explain why a plan won.
pub fn PlannerConfig::new(
  participation_weight : Int,
  interest_weight : Int,
  travel_gap_penalty : Int,
  min_participants : Int,
) -> PlannerConfig {
  PlannerConfig::{
    participation_weight,
    interest_weight,
    travel_gap_penalty,
    min_participants,
  }
}

///|
/// The balanced policy used by `evaluate` and `rank_plans`.
pub fn default_config() -> PlannerConfig {
  PlannerConfig::new(100, 20, 1, 1)
}

///|
/// Safety and fairness constraints for venue-aware recommendations.
pub struct VenuePolicy {
  config : PlannerConfig
  max_travel_minutes : Int
  average_travel_penalty : Int
}

///|
/// Create a venue policy. Members above `max_travel_minutes` are marked as
/// too far rather than silently counted as absent.
pub fn VenuePolicy::new(
  config : PlannerConfig,
  max_travel_minutes : Int,
  average_travel_penalty : Int,
) -> VenuePolicy {
  VenuePolicy::{ config, max_travel_minutes, average_travel_penalty, }
}

///|
/// Balanced venue policy for a normal campus activity.
pub fn default_venue_policy() -> VenuePolicy {
  VenuePolicy::new(default_config(), 45, 1)
}

///|
/// Return whether an integer appears in an array.
fn contains_int(items : Array[Int], target : Int) -> Bool {
  for i = 0, found = false
      i < items.length()
      i = i + 1, found = found || items[i] == target {

  } nobreak {
    found
  }
}

///|
/// Return whether a string appears in an array.
fn contains_string(items : Array[String], target : String) -> Bool {
  for i = 0, found = false
      i < items.length()
      i = i + 1, found = found || items[i] == target {

  } nobreak {
    found
  }
}

///|
/// Return the matching commute estimate, treating missing data as infeasible
/// instead of making up a travel time.
fn commute_for(venue : Venue, member_index : Int) -> Int {
  if member_index < venue.commute_minutes.length() {
    venue.commute_minutes[member_index]
  } else {
    1000000
  }
}

///|
/// Score one time-and-interest candidate.
///
/// Participation is weighted most heavily, then shared interest. A larger
/// travel-cost gap is a fairness penalty, so a convenient plan does not win
/// merely because it works for the people nearest the venue.
pub fn evaluate_with_config(
  members : Array[Member],
  slot : Int,
  interest : String,
  config : PlannerConfig,
) -> Plan {
  let (participants, matches, min_travel, max_travel) = for i = 0, participants = 0, matches = 0, min_travel = 1000000, max_travel = 0
                                                            i < members.length()
                                                            i = i + 1, participants = participants, matches = matches, min_travel = min_travel, max_travel = max_travel {
    let person = members[i]
    if contains_int(person.availability, slot) {
      let next_participants = participants + 1
      let next_matches = if contains_string(person.interests, interest) {
        matches + 1
      } else {
        matches
      }
      let next_min = if person.travel_cost < min_travel {
        person.travel_cost
      } else {
        min_travel
      }
      let next_max = if person.travel_cost > max_travel {
        person.travel_cost
      } else {
        max_travel
      }
      continue i + 1, next_participants, next_matches, next_min, next_max
    }
  } nobreak {
    (participants, matches, min_travel, max_travel)
  }
  let travel_gap = if participants == 0 { 0 } else { max_travel - min_travel }
  let score = participants * config.participation_weight +
    matches * config.interest_weight -
    travel_gap * config.travel_gap_penalty
  let explanation = "\{participants} 人可参加；\{matches} 人偏好 \{interest}；通勤差 \{travel_gap} 分钟。"
  Plan::{
    slot,
    interest,
    participant_count: participants,
    interest_match_count: matches,
    travel_gap,
    score,
    explanation,
  }
}

///|
/// Score one candidate with the balanced default policy.
pub fn evaluate(members : Array[Member], slot : Int, interest : String) -> Plan {
  evaluate_with_config(members, slot, interest, default_config())
}

///|
/// Rank every time-and-interest candidate from strongest to weakest.
pub fn rank_plans(
  members : Array[Member],
  slots : Array[Int],
  interests : Array[String],
) -> Array[Plan] {
  rank_plans_with_config(members, slots, interests, default_config())
}

///|
/// Rank candidates with caller-controlled weights and a minimum group size.
pub fn rank_plans_with_config(
  members : Array[Member],
  slots : Array[Int],
  interests : Array[String],
  config : PlannerConfig,
) -> Array[Plan] {
  let plans : Array[Plan] = []
  for slot in slots {
    for interest in interests {
      let plan = evaluate_with_config(members, slot, interest, config)
      if plan.participant_count >= config.min_participants {
        plans.push(plan)
      }
    }
  }
  for i = 0; i < plans.length(); i = i + 1 {
    for j = i + 1; j < plans.length(); j = j + 1 {
      if plans[j].score > plans[i].score {
        let saved = plans[i]
        plans[i] = plans[j]
        plans[j] = saved
      }
    }
  }
  plans
}

///|
/// Evaluate a topic-time-venue combination and retain why each member was
/// included or excluded. This is the product-facing API.
pub fn evaluate_option(
  members : Array[Member],
  option : ActivityOption,
  policy : VenuePolicy,
) -> DetailedPlan {
  let attendees : Array[String] = []
  let unavailable : Array[String] = []
  let too_far : Array[String] = []
  let mut matches = 0
  let mut total_travel = 0
  let mut min_travel = 1000000
  let mut max_travel = 0
  for i = 0; i < members.length(); i = i + 1 {
    let person = members[i]
    if !contains_int(person.availability, option.slot) {
      unavailable.push(person.name)
    } else {
      let commute = commute_for(option.venue, i)
      if commute > policy.max_travel_minutes {
        too_far.push(person.name)
      } else {
        attendees.push(person.name)
        total_travel = total_travel + commute
        if commute < min_travel {
          min_travel = commute
        }
        if commute > max_travel {
          max_travel = commute
        }
        if contains_string(person.interests, option.interest) {
          matches = matches + 1
        }
      }
    }
  }
  let participant_count = attendees.length()
  let average_travel = if participant_count == 0 {
    0
  } else {
    total_travel / participant_count
  }
  let travel_gap = if participant_count == 0 {
    0
  } else {
    max_travel - min_travel
  }
  let score = participant_count * policy.config.participation_weight +
    matches * policy.config.interest_weight -
    travel_gap * policy.config.travel_gap_penalty -
    average_travel * policy.average_travel_penalty
  let explanation = "\{option.venue.name}：\{participant_count} 人可参加，\{matches} 人偏好 \{option.interest}；平均通勤 \{average_travel} 分钟，通勤差 \{travel_gap} 分钟；\{unavailable.length()} 人没空，\{too_far.length()} 人距离过远。"
  DetailedPlan::{
    slot: option.slot,
    interest: option.interest,
    venue_name: option.venue.name,
    participant_count,
    interest_match_count: matches,
    average_travel,
    travel_gap,
    attendees,
    unavailable,
    too_far,
    score,
    explanation,
  }
}

///|
/// Rank concrete options, filtering out combinations that cannot form a
/// group under the supplied minimum-group rule.
pub fn rank_options(
  members : Array[Member],
  options : Array[ActivityOption],
  policy : VenuePolicy,
) -> Array[DetailedPlan] {
  let plans : Array[DetailedPlan] = []
  for option in options {
    let plan = evaluate_option(members, option, policy)
    if plan.participant_count >= policy.config.min_participants {
      plans.push(plan)
    }
  }
  for i = 0; i < plans.length(); i = i + 1 {
    for j = i + 1; j < plans.length(); j = j + 1 {
      if plans[j].score > plans[i].score {
        let saved = plans[i]
        plans[i] = plans[j]
        plans[j] = saved
      }
    }
  }
  plans
}

///|
/// Return the first hard-constraint violation, if any.
fn rejection_reason(
  plan : DetailedPlan,
  policy : VenuePolicy,
  required_members : Array[String],
) -> String? {
  if plan.participant_count < policy.config.min_participants {
    Some(
      "无法成团：仅 \{plan.participant_count} 人可参加，最低要求 \{policy.config.min_participants} 人。",
    )
  } else {
    for name in required_members {
      if !contains_string(plan.attendees, name) {
        return Some(
          "关键成员 \{name} 无法参加（时间冲突或通勤超限）。",
        )
      }
    }
    None
  }
}

///|
/// Analyze all options under hard constraints before ranking the viable ones.
///
/// `required_members` is deliberately separate from the soft scoring model:
/// a founder, organizer, or birthday person should not be silently traded away
/// for a higher aggregate score.
pub fn analyze_options(
  members : Array[Member],
  options : Array[ActivityOption],
  policy : VenuePolicy,
  required_members : Array[String],
) -> RecommendationReport {
  let recommended : Array[DetailedPlan] = []
  let rejected : Array[RejectedOption] = []
  for option in options {
    let plan = evaluate_option(members, option, policy)
    match rejection_reason(plan, policy, required_members) {
      Some(reason) =>
        rejected.push(RejectedOption::{
          slot: option.slot,
          interest: option.interest,
          venue_name: option.venue.name,
          reason,
        })
      None => recommended.push(plan)
    }
  }
  for i = 0; i < recommended.length(); i = i + 1 {
    for j = i + 1; j < recommended.length(); j = j + 1 {
      if recommended[j].score > recommended[i].score {
        let saved = recommended[i]
        recommended[i] = recommended[j]
        recommended[j] = saved
      }
    }
  }
  RecommendationReport::{ recommended, rejected, }
}

///|
/// A real time interval measured in local minutes after midnight.  The legacy
/// `slot` API above remains for small examples; product integrations should
/// use this type so an "evening" selection cannot accidentally mean any hour.
pub struct TimeWindow {
  date : String
  start_minute : Int
  end_minute : Int
}

///|
pub fn TimeWindow::new(
  date : String,
  start_minute : Int,
  end_minute : Int,
) -> TimeWindow {
  TimeWindow::{ date, start_minute, end_minute, }
}

///|
/// Returns true only if `available` completely covers `requested`.
pub fn covers(available : TimeWindow, requested : TimeWindow) -> Bool {
  available.date == requested.date &&
  available.start_minute <= requested.start_minute &&
  available.end_minute >= requested.end_minute
}

///|
/// Product-facing member input.  `id` should be a stable pseudonymous user id,
/// not a phone number or other private contact detail.
pub struct TimedMember {
  id : String
  availability : Array[TimeWindow]
  interests : Array[String]
}

///|
pub fn TimedMember::new(
  id : String,
  availability : Array[TimeWindow],
  interests : Array[String],
) -> TimedMember {
  TimedMember::{ id, availability, interests, }
}

///|
/// A venue estimate may be unknown.  Unknown is deliberately different from
/// "too far": the UI should ask for a route estimate instead of blaming a
/// member or fabricating a number.
pub struct TimedVenue {
  name : String
  commute_minutes : Array[Int?]
}

///|
pub fn TimedVenue::new(
  name : String,
  commute_minutes : Array[Int?],
) -> TimedVenue {
  TimedVenue::{ name, commute_minutes, }
}

///|
pub struct TimedOption {
  id : String
  window : TimeWindow
  interest : String
  venue : TimedVenue
}

///|
pub fn TimedOption::new(
  id : String,
  window : TimeWindow,
  interest : String,
  venue : TimedVenue,
) -> TimedOption {
  TimedOption::{ id, window, interest, venue, }
}

///|
/// Hard rules are separate from the ranking score.  `require_everyone` is the
/// user-approved strict mode: no candidate is recommended unless every member
/// can attend within the travel limit.
pub struct DecisionRules {
  min_participants : Int
  required_members : Array[String]
  require_everyone : Bool
  max_travel_minutes : Int
}

///|
pub fn DecisionRules::new(
  min_participants : Int,
  required_members : Array[String],
  require_everyone : Bool,
  max_travel_minutes : Int,
) -> DecisionRules {
  DecisionRules::{
    min_participants,
    required_members,
    require_everyone,
    max_travel_minutes,
  }
}

///|
pub fn default_decision_rules() -> DecisionRules {
  DecisionRules::new(2, [], false, 45)
}

///|
/// A transparent decision record.  The four exclusion arrays are mutually
/// exclusive, which lets the product tell people whether it needs a time
/// change, a closer venue, or missing route information.
pub struct TimedDecision {
  option_id : String
  window : TimeWindow
  interest : String
  venue_name : String
  attendee_ids : Array[String]
  unavailable_ids : Array[String]
  too_far_ids : Array[String]
  unknown_travel_ids : Array[String]
  interest_match_count : Int
  average_travel : Int
  travel_gap : Int
  score : Int
  needs_confirmation : Bool
  explanation : String
}

///|
pub struct TimedRejection {
  option_id : String
  reason : String
}

///|
/// A small, actionable repair rather than a dead-end "no solution" state.
pub struct RepairSuggestion {
  option_id : String
  suggested_window : TimeWindow
  reason : String
}

///|
pub struct DecisionReport {
  ranked : Array[TimedDecision]
  pareto_frontier : Array[TimedDecision]
  most_inclusive : TimedDecision?
  least_travel : TimedDecision?
  best_interest_fit : TimedDecision?
  rejected : Array[TimedRejection]
  repairs : Array[RepairSuggestion]
}

///|
fn member_is_available(person : TimedMember, window : TimeWindow) -> Bool {
  for item in person.availability {
    if covers(item, window) {
      return true
    }
  }
  false
}

///|
fn timed_commute_for(venue : TimedVenue, member_index : Int) -> Int? {
  if member_index < venue.commute_minutes.length() {
    venue.commute_minutes[member_index]
  } else {
    None
  }
}

///|
pub fn evaluate_timed_option(
  members : Array[TimedMember],
  option : TimedOption,
  rules : DecisionRules,
) -> TimedDecision {
  let attendee_ids : Array[String] = []
  let unavailable_ids : Array[String] = []
  let too_far_ids : Array[String] = []
  let unknown_travel_ids : Array[String] = []
  let mut matches = 0
  let mut total_travel = 0
  let mut min_travel = 1000000
  let mut max_travel = 0
  for i = 0; i < members.length(); i = i + 1 {
    let person = members[i]
    if !member_is_available(person, option.window) {
      unavailable_ids.push(person.id)
    } else {
      match timed_commute_for(option.venue, i) {
        None => unknown_travel_ids.push(person.id)
        Some(commute) =>
          if commute > rules.max_travel_minutes {
            too_far_ids.push(person.id)
          } else {
            attendee_ids.push(person.id)
            total_travel = total_travel + commute
            if commute < min_travel {
              min_travel = commute
            }
            if commute > max_travel {
              max_travel = commute
            }
            if contains_string(person.interests, option.interest) {
              matches = matches + 1
            }
          }
      }
    }
  }
  let count = attendee_ids.length()
  let average_travel = if count == 0 { 0 } else { total_travel / count }
  let travel_gap = if count == 0 { 0 } else { max_travel - min_travel }
  let score = count * 100 + matches * 20 - average_travel - travel_gap
  let needs_confirmation = unknown_travel_ids.length() > 0
  let explanation = "\{option.venue.name}：\{count} 人可参加，\{matches} 人偏好 \{option.interest}；平均通勤 \{average_travel} 分钟，通勤差 \{travel_gap} 分钟；\{unavailable_ids.length()} 人时间冲突，\{too_far_ids.length()} 人通勤超限，\{unknown_travel_ids.length()} 人待补路线。"
  TimedDecision::{
    option_id: option.id,
    window: option.window,
    interest: option.interest,
    venue_name: option.venue.name,
    attendee_ids,
    unavailable_ids,
    too_far_ids,
    unknown_travel_ids,
    interest_match_count: matches,
    average_travel,
    travel_gap,
    score,
    needs_confirmation,
    explanation,
  }
}

///|
fn timed_rejection_reason(
  plan : TimedDecision,
  members : Array[TimedMember],
  rules : DecisionRules,
) -> String? {
  if plan.attendee_ids.length() < rules.min_participants {
    Some(
      "无法成团：仅 \{plan.attendee_ids.length()} 人满足时间与通勤要求，最低要求 \{rules.min_participants} 人。",
    )
  } else if rules.require_everyone &&
    plan.attendee_ids.length() != members.length() {
    Some(
      "全员模式：仍有成员因时间、通勤或路线信息缺失无法确认。",
    )
  } else {
    for id in rules.required_members {
      if !contains_string(plan.attendee_ids, id) {
        return Some("关键成员 \{id} 无法确认参加。")
      }
    }
    None
  }
}

///|
fn sort_timed_decisions(items : Array[TimedDecision]) -> Unit {
  for i = 0; i < items.length(); i = i + 1 {
    for j = i + 1; j < items.length(); j = j + 1 {
      let left = items[i]
      let right = items[j]
      let should_swap = right.score > left.score ||
        (
          right.score == left.score &&
          right.attendee_ids.length() > left.attendee_ids.length()
        )
      if should_swap {
        items[i] = right
        items[j] = left
      }
    }
  }
}

///|
fn dominates(left : TimedDecision, right : TimedDecision) -> Bool {
  let no_worse = left.attendee_ids.length() >= right.attendee_ids.length() &&
    left.interest_match_count >= right.interest_match_count &&
    left.average_travel <= right.average_travel &&
    left.travel_gap <= right.travel_gap
  let strictly_better = left.attendee_ids.length() > right.attendee_ids.length() ||
    left.interest_match_count > right.interest_match_count ||
    left.average_travel < right.average_travel ||
    left.travel_gap < right.travel_gap
  no_worse && strictly_better
}

///|
fn pareto_decisions(items : Array[TimedDecision]) -> Array[TimedDecision] {
  let result : Array[TimedDecision] = []
  for i = 0; i < items.length(); i = i + 1 {
    let mut dominated = false
    for j = 0; j < items.length(); j = j + 1 {
      if i != j && dominates(items[j], items[i]) {
        dominated = true
      }
    }
    if !dominated {
      result.push(items[i])
    }
  }
  result
}

///|
fn shift_window(window : TimeWindow, minutes : Int) -> TimeWindow? {
  let start = window.start_minute + minutes
  let end = window.end_minute + minutes
  if start < 0 || end > 1440 || start >= end {
    None
  } else {
    Some(TimeWindow::new(window.date, start, end))
  }
}

///|
fn first_repair(
  members : Array[TimedMember],
  option : TimedOption,
  rules : DecisionRules,
) -> RepairSuggestion? {
  let shifts = [-60, -30, 30, 60]
  for minutes in shifts {
    match shift_window(option.window, minutes) {
      None => ()
      Some(window) => {
        let shifted = TimedOption::new(
          option.id,
          window,
          option.interest,
          option.venue,
        )
        let trial = evaluate_timed_option(members, shifted, rules)
        match timed_rejection_reason(trial, members, rules) {
          None =>
            return Some(RepairSuggestion::{
              option_id: option.id,
              suggested_window: window,
              reason: "将开始时间平移 \{minutes} 分钟后，可满足当前硬约束。",
            })
          Some(_) => ()
        }
      }
    }
  }
  None
}

///|
/// Analyze timed options.  Results include a stable score ordering for a
/// default card, a Pareto frontier for honest trade-offs, three named choices
/// for the UI, and time-shift repairs for otherwise rejected candidates.
pub fn analyze_timed_options(
  members : Array[TimedMember],
  options : Array[TimedOption],
  rules : DecisionRules,
) -> DecisionReport {
  let ranked : Array[TimedDecision] = []
  let rejected : Array[TimedRejection] = []
  let repairs : Array[RepairSuggestion] = []
  for option in options {
    let plan = evaluate_timed_option(members, option, rules)
    match timed_rejection_reason(plan, members, rules) {
      None => ranked.push(plan)
      Some(reason) => {
        rejected.push(TimedRejection::{ option_id: option.id, reason, })
        match first_repair(members, option, rules) {
          Some(repair) => repairs.push(repair)
          None => ()
        }
      }
    }
  }
  sort_timed_decisions(ranked)
  let pareto_frontier = pareto_decisions(ranked)
  let mut most_inclusive : TimedDecision? = None
  let mut least_travel : TimedDecision? = None
  let mut best_interest_fit : TimedDecision? = None
  for plan in ranked {
    match most_inclusive {
      None => most_inclusive = Some(plan)
      Some(current) =>
        if plan.attendee_ids.length() > current.attendee_ids.length() {
          most_inclusive = Some(plan)
        }
    }
    match least_travel {
      None => least_travel = Some(plan)
      Some(current) =>
        if plan.average_travel < current.average_travel {
          least_travel = Some(plan)
        }
    }
    match best_interest_fit {
      None => best_interest_fit = Some(plan)
      Some(current) =>
        if plan.interest_match_count > current.interest_match_count {
          best_interest_fit = Some(plan)
        }
    }
  }
  DecisionReport::{
    ranked,
    pareto_frontier,
    most_inclusive,
    least_travel,
    best_interest_fit,
    rejected,
    repairs,
  }
}

///|
/// A small, runnable example using a realistic campus-group scenario.
pub fn demo() -> String {
  let members = [
    Member::{
      name: "Ava",
      availability: [18, 19],
      interests: ["ai", "robotics"],
      travel_cost: 20,
    },
    Member::{
      name: "Ben",
      availability: [19, 20],
      interests: ["ai", "finance"],
      travel_cost: 35,
    },
    Member::{
      name: "Chen",
      availability: [18, 19],
      interests: ["robotics", "finance"],
      travel_cost: 25,
    },
  ]
  let options = [
    ActivityOption::new(19, "ai", Venue::new("大学城站", [20, 35, 25])),
    ActivityOption::new(19, "ai", Venue::new("南山", [55, 20, 40])),
    ActivityOption::new(18, "robotics", Venue::new("校内", [5, 5, 5])),
  ]
  let policy = VenuePolicy::new(default_config(), 45, 1)
  let report = analyze_options(members, options, policy, ["Ava"])
  let best = report.recommended[0]
  "推荐 \{best.slot}:00 在 \{best.venue_name} 的 \{best.interest} 活动（得分 \{best.score}）：\{best.explanation} 已淘汰 \{report.rejected.length()} 个不满足硬约束的方案。"
}
