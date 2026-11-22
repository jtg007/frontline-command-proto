extends TestCase


func test_new_duplicate_stale() -> void:
	var l := RequestLedger.new()
	check_eq(l.classify(1, 1), RequestLedger.Verdict.NEW, "first request is new")
	l.remember(1, 1, true, "")
	check_eq(l.classify(1, 1), RequestLedger.Verdict.DUPLICATE, "same id is a duplicate")
	check_eq(l.classify(1, 2), RequestLedger.Verdict.NEW, "higher id is new")
	l.remember(1, 5, false, "Too far")
	check_eq(l.classify(1, 3), RequestLedger.Verdict.STALE, "lower id is stale")
	check_eq(l.cached_message(1), "Too far", "cached result for duplicate replies")
	check(not l.cached_ok(1), "cached ok flag")


func test_peers_are_independent_and_forgettable() -> void:
	var l := RequestLedger.new()
	l.remember(1, 10, true, "")
	check_eq(l.classify(2, 1), RequestLedger.Verdict.NEW, "other peer unaffected")
	l.forget(1)
	check_eq(l.classify(1, 1), RequestLedger.Verdict.NEW, "forgotten peer starts fresh")
