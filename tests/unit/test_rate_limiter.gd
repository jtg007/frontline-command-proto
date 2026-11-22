extends TestCase


func test_burst_then_refill() -> void:
	var r := RateLimiter.new(3.0, 2.0)
	check(r.allow(1, 0.0) and r.allow(1, 0.0) and r.allow(1, 0.0), "burst of 3 allowed")
	check(not r.allow(1, 0.0), "4th denied")
	check(not r.allow(1, 0.2), "not yet refilled")
	check(r.allow(1, 0.6), "refilled after 0.5 s")
	check(r.allow(2, 0.0), "other peers have their own bucket")
