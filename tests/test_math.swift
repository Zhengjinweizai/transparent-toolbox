import Foundation

// MathParser 单元测试：swiftc tests/test_math.swift Sources/MathParser.swift -o /tmp/test_math && /tmp/test_math
var failures = 0

func expect(_ expr: String, _ want: Double) {
    let got = MathParser.evaluate(expr)
    if let got, abs(got - want) < 1e-9 {
        print("✔ \(expr) = \(got)")
    } else {
        print("✘ \(expr) 期望 \(want)，实际 \(String(describing: got))")
        failures += 1
    }
}

func expectNil(_ expr: String) {
    if MathParser.evaluate(expr) == nil {
        print("✔ \(expr) → 无效（符合预期）")
    } else {
        print("✘ \(expr) 应解析失败")
        failures += 1
    }
}

expect("1+2*3", 7)
expect("(3+5)/2", 4)
expect("10/4", 2.5)
expect("2*(3+4)", 14)
expect("-4*2", -8)
expect("1-2-3", -4)
expect("100/10/2", 5)
expect("0.5*8", 4)
expect(" 1 + 2 ", 3)
expectNil("12+")
expectNil("(1+2")
expectNil("1/0")
expectNil("abc")
expectNil("")

if failures == 0 {
    print("全部通过 ✔")
} else {
    print("失败 \(failures) 项")
    exit(1)
}
