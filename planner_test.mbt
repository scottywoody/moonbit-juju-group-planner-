///|
test "more participation outranks a niche preference" {
  let members = [
    @planner.Member::new("A", [18, 19], ["ai"], 10),
    @planner.Member::new("B", [19], ["robotics"], 20),
    @planner.Member::new("C", [19], ["ai"], 30),
  ]
  let plans = @planner.rank_plans(members, [18, 19], ["ai", "robotics"])
  assert_eq(plans[0].slot, 19)
  assert_eq(plans[0].interest, "ai")
}

///|
test "travel gap becomes a fairness penalty" {
  let members = [
    @planner.Member::new("A", [18], ["ai"], 10),
    @planner.Member::new("B", [18], ["ai"], 40),
  ]
  let plan = @planner.evaluate(members, 18, "ai")
  assert_eq(plan.participant_count, 2)
  assert_eq(plan.interest_match_count, 2)
  assert_eq(plan.travel_gap, 30)
  assert_eq(plan.score, 210)
}

///|
test "no participant has zero travel penalty" {
  let members = [@planner.Member::new("A", [18], ["ai"], 10)]
  let plan = @planner.evaluate(members, 20, "ai")
  assert_eq(plan.participant_count, 0)
  assert_eq(plan.travel_gap, 0)
  assert_eq(plan.score, 0)
}

///|
test "minimum group size filters plans that cannot form a group" {
  let members = [
    @planner.Member::new("A", [18], ["ai"], 10),
    @planner.Member::new("B", [19], ["ai"], 10),
  ]
  let config = @planner.PlannerConfig::new(100, 20, 1, 2)
  let plans = @planner.rank_plans_with_config(members, [18, 19], ["ai"], config)
  assert_eq(plans.length(), 0)
}

///|
test "a stronger fairness penalty changes a close decision" {
  let members = [
    @planner.Member::new("A", [18, 19], ["ai"], 10),
    @planner.Member::new("B", [18, 19], ["ai"], 11),
    @planner.Member::new("C", [18], ["ai"], 80),
  ]
  let balanced = @planner.rank_plans(members, [18, 19], ["ai"])
  assert_eq(balanced[0].slot, 18)
  let fair = @planner.PlannerConfig::new(100, 20, 3, 1)
  let fairness_first = @planner.rank_plans_with_config(
    members,
    [18, 19],
    ["ai"],
    fair,
  )
  assert_eq(fairness_first[0].slot, 19)
}

///|
test "venue-aware planning explains unavailable and too-far members" {
  let members = [
    @planner.Member::new("A", [19], ["ai"], 0),
    @planner.Member::new("B", [19], ["robotics"], 0),
    @planner.Member::new("C", [18], ["ai"], 0),
  ]
  let option = @planner.ActivityOption::new(
    19,
    "ai",
    @planner.Venue::new("南山", [20, 60, 20]),
  )
  let policy = @planner.VenuePolicy::new(@planner.default_config(), 45, 1)
  let plan = @planner.evaluate_option(members, option, policy)
  assert_eq(plan.participant_count, 1)
  assert_eq(plan.interest_match_count, 1)
  assert_eq(plan.average_travel, 20)
  assert_eq(plan.unavailable.length(), 1)
  assert_eq(plan.too_far.length(), 1)
}

///|
test "closer venue can win after travel-aware scoring" {
  let members = [
    @planner.Member::new("A", [19], ["ai"], 0),
    @planner.Member::new("B", [19], ["ai"], 0),
  ]
  let options = [
    @planner.ActivityOption::new(
      19,
      "ai",
      @planner.Venue::new("远场地", [40, 40]),
    ),
    @planner.ActivityOption::new(
      19,
      "ai",
      @planner.Venue::new("近场地", [10, 10]),
    ),
  ]
  let policy = @planner.VenuePolicy::new(@planner.default_config(), 45, 1)
  let plans = @planner.rank_options(members, options, policy)
  assert_eq(plans[0].venue_name, "近场地")
}

///|
test "required member is a hard constraint instead of a soft score" {
  let members = [
    @planner.Member::new("A", [19], ["ai"], 0),
    @planner.Member::new("B", [19], ["ai"], 0),
  ]
  let options = [
    @planner.ActivityOption::new(
      19,
      "ai",
      @planner.Venue::new("远场地", [20, 60]),
    ),
    @planner.ActivityOption::new(
      19,
      "ai",
      @planner.Venue::new("近场地", [20, 20]),
    ),
  ]
  let policy = @planner.VenuePolicy::new(@planner.default_config(), 45, 1)
  let report = @planner.analyze_options(members, options, policy, ["B"])
  assert_eq(report.recommended.length(), 1)
  assert_eq(report.recommended[0].venue_name, "近场地")
  assert_eq(report.rejected.length(), 1)
  assert_eq(report.rejected[0].venue_name, "远场地")
}

///|
test "report keeps a reason for an option that cannot form a group" {
  let members = [@planner.Member::new("A", [19], ["ai"], 0)]
  let option = @planner.ActivityOption::new(
    19,
    "ai",
    @planner.Venue::new("校内", [5]),
  )
  let config = @planner.PlannerConfig::new(100, 20, 1, 2)
  let policy = @planner.VenuePolicy::new(config, 45, 1)
  let report = @planner.analyze_options(members, [option], policy, [])
  assert_eq(report.recommended.length(), 0)
  assert_eq(report.rejected.length(), 1)
}

///|
test "missing commute data is treated as infeasible instead of guessed" {
  let members = [
    @planner.Member::new("A", [19], ["ai"], 0),
    @planner.Member::new("B", [19], ["ai"], 0),
  ]
  let option = @planner.ActivityOption::new(
    19,
    "ai",
    @planner.Venue::new("数据不完整场地", [15]),
  )
  let policy = @planner.VenuePolicy::new(@planner.default_config(), 45, 1)
  let plan = @planner.evaluate_option(members, option, policy)
  assert_eq(plan.participant_count, 1)
  assert_eq(plan.too_far.length(), 1)
}

///|
test "real availability must cover the entire activity window" {
  let available = @planner.TimeWindow::new("2026-10-10", 1080, 1200)
  let fits = @planner.TimeWindow::new("2026-10-10", 1110, 1170)
  let overruns = @planner.TimeWindow::new("2026-10-10", 1110, 1230)
  assert_true(@planner.covers(available, fits))
  assert_false(@planner.covers(available, overruns))
}

///|
test "unknown travel is kept separate from excessive travel" {
  let members = [
    @planner.TimedMember::new(
      "a",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["ai"],
    ),
    @planner.TimedMember::new(
      "b",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["ai"],
    ),
    @planner.TimedMember::new(
      "c",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["robotics"],
    ),
  ]
  let option = @planner.TimedOption::new(
    "ai-campus",
    @planner.TimeWindow::new("2026-10-10", 1140, 1200),
    "ai",
    @planner.TimedVenue::new("校内", [Some(10), Some(15), None]),
  )
  let report = @planner.analyze_timed_options(
    members,
    [option],
    @planner.default_decision_rules(),
  )
  assert_eq(report.ranked.length(), 1)
  assert_eq(report.ranked[0].attendee_ids.length(), 2)
  assert_eq(report.ranked[0].unknown_travel_ids.length(), 1)
  assert_eq(report.ranked[0].too_far_ids.length(), 0)
  assert_true(report.ranked[0].needs_confirmation)
}

///|
test "all-member mode is a hard constraint" {
  let members = [
    @planner.TimedMember::new(
      "a",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["ai"],
    ),
    @planner.TimedMember::new(
      "b",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1140)],
      ["ai"],
    ),
  ]
  let option = @planner.TimedOption::new(
    "after-class",
    @planner.TimeWindow::new("2026-10-10", 1140, 1200),
    "ai",
    @planner.TimedVenue::new("校内", [Some(10), Some(10)]),
  )
  let rules = @planner.DecisionRules::new(2, [], true, 45)
  let report = @planner.analyze_timed_options(members, [option], rules)
  assert_eq(report.ranked.length(), 0)
  assert_eq(report.rejected.length(), 1)
}

///|
test "pareto frontier retains an inclusive and a low-travel tradeoff" {
  let members = [
    @planner.TimedMember::new(
      "a",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["ai"],
    ),
    @planner.TimedMember::new(
      "b",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["robotics"],
    ),
    @planner.TimedMember::new(
      "c",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["robotics"],
    ),
  ]
  let window = @planner.TimeWindow::new("2026-10-10", 1140, 1200)
  let options = [
    @planner.TimedOption::new(
      "inclusive",
      window,
      "ai",
      @planner.TimedVenue::new("远一点", [Some(35), Some(35), Some(35)]),
    ),
    @planner.TimedOption::new(
      "easy",
      window,
      "ai",
      @planner.TimedVenue::new("校内", [Some(5), Some(5), None]),
    ),
  ]
  let report = @planner.analyze_timed_options(
    members,
    options,
    @planner.default_decision_rules(),
  )
  assert_eq(report.pareto_frontier.length(), 2)
  match report.most_inclusive {
    Some(plan) => assert_eq(plan.option_id, "inclusive")
    None => fail("expected an inclusive recommendation")
  }
  match report.least_travel {
    Some(plan) => assert_eq(plan.option_id, "easy")
    None => fail("expected a low-travel recommendation")
  }
}

///|
test "rejected option receives a time-shift repair when one exists" {
  let members = [
    @planner.TimedMember::new(
      "a",
      [@planner.TimeWindow::new("2026-10-10", 1080, 1260)],
      ["ai"],
    ),
    @planner.TimedMember::new(
      "b",
      [@planner.TimeWindow::new("2026-10-10", 1140, 1260)],
      ["ai"],
    ),
  ]
  let option = @planner.TimedOption::new(
    "early-ai",
    @planner.TimeWindow::new("2026-10-10", 1080, 1140),
    "ai",
    @planner.TimedVenue::new("校内", [Some(10), Some(10)]),
  )
  let report = @planner.analyze_timed_options(
    members,
    [option],
    @planner.default_decision_rules(),
  )
  assert_eq(report.rejected.length(), 1)
  assert_eq(report.repairs.length(), 1)
  assert_eq(report.repairs[0].suggested_window.start_minute, 1140)
}
