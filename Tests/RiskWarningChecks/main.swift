import DictionaryKit

private var failures: [String] = []

private func expect(_ condition: @autoclosure () -> Bool, _ description: String) {
    if !condition() { failures.append(description) }
}

expect(RiskWarning.check("the") != nil, "warns for an unmistakably common word")
expect(RiskWarning.check("THE") != nil, "comparison is case-insensitive")
expect(RiskWarning.check("Brewberry") == nil, "allows a project or person name")
expect(RiskWarning.check("Claude Code") == nil, "allows multiword terms")
expect(RiskWarning.check("x") != nil, "warns for very short unknown terms")

guard failures.isEmpty else {
    for failure in failures { print("FAIL: \(failure)") }
    fatalError("\(failures.count) RiskWarning check(s) failed")
}

print("PASS: 5 RiskWarning checks")
