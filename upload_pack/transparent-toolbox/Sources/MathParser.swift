import Foundation

/// 极简四则运算解析器：+ - * / ( ) 与一元负号，完全无崩溃风险
enum MathParser {
    static func evaluate(_ s: String) -> Double? {
        let p = Parser(s.replacingOccurrences(of: " ", with: ""))
        guard let v = p.parseExpression(), p.pos == p.chars.count, v.isFinite else { return nil }
        return v
    }

    private final class Parser {
        let chars: [Character]
        var pos = 0

        init(_ s: String) { chars = Array(s) }

        func parseExpression() -> Double? {
            var left = parseTerm()
            while pos < chars.count {
                let c = chars[pos]
                if c == "+" { pos += 1; guard let l = left, let r = parseTerm() else { return nil }; left = l + r }
                else if c == "-" { pos += 1; guard let l = left, let r = parseTerm() else { return nil }; left = l - r }
                else { break }
            }
            return left
        }

        func parseTerm() -> Double? {
            var left = parseFactor()
            while pos < chars.count {
                let c = chars[pos]
                if c == "*" { pos += 1; guard let l = left, let r = parseFactor() else { return nil }; left = l * r }
                else if c == "/" { pos += 1; guard let l = left, let r = parseFactor() else { return nil }; left = l / r }
                else { break }
            }
            return left
        }

        func parseFactor() -> Double? {
            guard pos < chars.count else { return nil }
            let c = chars[pos]
            if c == "(" {
                pos += 1
                guard let v = parseExpression() else { return nil }
                guard pos < chars.count, chars[pos] == ")" else { return nil }
                pos += 1
                return v
            }
            if c == "-" { pos += 1; return parseFactor().map { -$0 } }
            if c == "+" { pos += 1; return parseFactor() }
            let start = pos
            while pos < chars.count, chars[pos].isNumber || chars[pos] == "." { pos += 1 }
            guard pos > start, let v = Double(String(chars[start..<pos])) else { return nil }
            return v
        }
    }
}
