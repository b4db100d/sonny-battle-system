extends RefCounted
## Base class for test files. Tests define methods named test_* and use the
## assert helpers; failures are collected, not fatal, so all tests report.

var failures: Array[String] = []
var assert_count := 0
var _current_test := ""


func assert_true(cond: bool, msg: String = "") -> void:
	assert_count += 1
	if not cond:
		failures.append("%s: expected true. %s" % [_current_test, msg])


func assert_false(cond: bool, msg: String = "") -> void:
	assert_true(not cond, msg)


func assert_eq(got: Variant, expected: Variant, msg: String = "") -> void:
	assert_count += 1
	if got != expected:
		failures.append("%s: expected %s, got %s. %s" % [_current_test, expected, got, msg])


func assert_ne(got: Variant, not_expected: Variant, msg: String = "") -> void:
	assert_count += 1
	if got == not_expected:
		failures.append("%s: expected != %s. %s" % [_current_test, not_expected, msg])


func assert_almost_eq(got: float, expected: float, tolerance: float = 0.0001, msg: String = "") -> void:
	assert_count += 1
	if absf(got - expected) > tolerance:
		failures.append("%s: expected ~%s, got %s. %s" % [_current_test, expected, got, msg])


func fail(msg: String) -> void:
	assert_count += 1
	failures.append("%s: %s" % [_current_test, msg])
