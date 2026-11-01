/// Highlights org source for the editor: one `<div class="ln">` per source line, with
/// `<span>` classes for markup. Line-oriented with block state; it does not parse the
/// document, so it stays cheap enough to run on every keystroke.
public enum OrgHighlighter {

    /// The HTML of each source line, in order.
    public static func lines(_ source: String) -> [String] {
        var block: [UInt8]? = nil
        var out: [UInt8] = []
        return source.utf8.split(separator: UInt8(ascii: "\n"), omittingEmptySubsequences: false).map { line in
            out.removeAll(keepingCapacity: true)
            out.append(contentsOf: lineOpen)
            highlightLine(Array(line), block: &block, into: &out)
            out.append(contentsOf: lineClose)
            return String(decoding: out, as: UTF8.self)
        }
    }

    private static let lineOpen = Array("<div class=\"ln\">".utf8)
    private static let lineClose = Array("\n</div>".utf8)

    /// Blocks whose bodies are shown verbatim, without inline markup.
    private static let verbatimBlocks: [[UInt8]] = ["src", "example", "export", "comment"].map { Array($0.utf8) }

    private static func highlightLine(_ b: [UInt8], block: inout [UInt8]?, into out: inout [UInt8]) {
        var w = Writer(b: b, out: out)
        defer { out = w.out }
        let start = indentEnd(b)

        if let name = block {
            if lowerHasPrefix(b, at: start, "#+end_") {
                block = nil
                w.span("meta", 0, b.count)
            } else if verbatimBlocks.contains(name) {
                w.span("blk", 0, b.count)
            } else {
                inline(&w, 0, b.count)
            }
            return
        }

        // Headings: stars at column 0 followed by a space.
        var stars = 0
        while stars < b.count && b[stars] == UInt8(ascii: "*") { stars += 1 }
        if stars > 0 && stars < b.count && b[stars] == UInt8(ascii: " ") {
            heading(&w, stars)
            return
        }

        if lowerHasPrefix(b, at: start, "#+begin_") {
            var e = start + 8
            while e < b.count && !isSpace(b[e]) { e += 1 }
            block = b[(start + 8)..<e].map(lower)
            w.span("meta", 0, b.count)
            return
        }
        if hasPrefix(b, at: start, "#+") {
            var e = start + 2
            while e < b.count && isKeyChar(b[e]) { e += 1 }
            if e > start + 2 && e < b.count && b[e] == UInt8(ascii: ":") {
                w.span("kw", 0, e + 1)
                w.text(e + 1, b.count)
            } else {
                w.span("meta", 0, b.count)
            }
            return
        }
        if start < b.count && b[start] == UInt8(ascii: "#") && (start + 1 == b.count || isSpace(b[start + 1])) {
            w.span("cmt", 0, b.count)
            return
        }
        if start < b.count && b[start] == UInt8(ascii: "|") {
            w.span("tbl", 0, b.count)
            return
        }
        if start < b.count && b[start] == UInt8(ascii: ":") {
            if start + 1 == b.count || b[start + 1] == UInt8(ascii: " ") {
                w.span("fix", 0, b.count)
                return
            }
            var e = start + 1
            while e < b.count && isKeyChar(b[e]) { e += 1 }
            if e > start + 1 && e < b.count && b[e] == UInt8(ascii: ":") && (e + 1 == b.count || isSpace(b[e + 1])) {
                w.span("drw", 0, e + 1)
                w.text(e + 1, b.count)
                return
            }
        }
        if b.count - start >= 5 && b[start...].allSatisfy({ $0 == UInt8(ascii: "-") || isSpace($0) })
            && b[start..<(start + 5)].allSatisfy({ $0 == UInt8(ascii: "-") }) {
            w.span("hr", 0, b.count)
            return
        }
        if let bulletEnd = bullet(b, start) {
            w.span("bul", 0, bulletEnd)
            var i = bulletEnd
            if i + 3 <= b.count && b[i] == UInt8(ascii: "[") && b[i + 2] == UInt8(ascii: "]")
                && (b[i + 1] == UInt8(ascii: " ") || b[i + 1] == UInt8(ascii: "X") || b[i + 1] == UInt8(ascii: "x") || b[i + 1] == UInt8(ascii: "-")) {
                w.span("cb", i, i + 3)
                i += 3
            }
            inline(&w, i, b.count)
            return
        }
        inline(&w, 0, b.count)
    }

    private static func heading(_ w: inout Writer, _ stars: Int) {
        let b = w.b
        let level = (stars - 1) % 3 + 1
        w.open("h\(level)")
        var i = stars + 1
        w.text(0, i)
        if let (word, cls) = todoKeyword(b, i) {
            w.span(cls, i, word)
            i = word
        }
        if i + 4 <= b.count && b[i] == UInt8(ascii: " ") && b[i + 1] == UInt8(ascii: "[") && b[i + 2] == UInt8(ascii: "#") && b[i + 4] == UInt8(ascii: "]") {
            w.text(i, i + 1)
            w.span("pri", i + 1, i + 5)
            i += 5
        } else if i + 3 <= b.count && b[i] == UInt8(ascii: "[") && b[i + 1] == UInt8(ascii: "#") && b[i + 3] == UInt8(ascii: "]") {
            w.span("pri", i, i + 4)
            i += 4
        }
        if let tags = tagsStart(b, from: i) {
            inline(&w, i, tags)
            w.span("tag", tags, b.count)
        } else {
            inline(&w, i, b.count)
        }
        w.close()
    }

    private static func todoKeyword(_ b: [UInt8], _ i: Int) -> (Int, String)? {
        for (word, cls) in [("TODO", "todo"), ("DONE", "done")] {
            let u = Array(word.utf8)
            if hasPrefix(b, at: i, word) && (i + u.count == b.count || b[i + u.count] == UInt8(ascii: " ")) {
                return (i + u.count, cls)
            }
        }
        return nil
    }

    /// Start of a trailing `:tag1:tag2:` group preceded by whitespace, if any.
    private static func tagsStart(_ b: [UInt8], from: Int) -> Int? {
        var end = b.count
        while end > from && isSpace(b[end - 1]) { end -= 1 }
        guard end - from >= 3, b[end - 1] == UInt8(ascii: ":") else { return nil }
        var s = end - 1
        while s > from && (isTagChar(b[s - 1]) || b[s - 1] == UInt8(ascii: ":")) { s -= 1 }
        while s < end && b[s] != UInt8(ascii: ":") { s += 1 }
        guard s < end - 1, s > from, isSpace(b[s - 1]) else { return nil }
        return s
    }

    /// End of a list bullet and its following space, if the line has one.
    private static func bullet(_ b: [UInt8], _ start: Int) -> Int? {
        guard start < b.count else { return nil }
        var e = start
        let c = b[start]
        if c == UInt8(ascii: "-") || c == UInt8(ascii: "+") || (c == UInt8(ascii: "*") && start > 0) {
            e += 1
        } else {
            while e < b.count && isDigit(b[e]) { e += 1 }
            guard e > start, e < b.count, b[e] == UInt8(ascii: ".") || b[e] == UInt8(ascii: ")") else { return nil }
            e += 1
        }
        if e == b.count { return e }
        guard b[e] == UInt8(ascii: " ") else { return nil }
        return e + 1
    }

    // MARK: - Inline

    private static func inline(_ w: inout Writer, _ from: Int, _ to: Int) {
        let b = w.b
        var i = from
        var plain = from
        while i < to {
            var match: (end: Int, cls: String)? = nil
            let c = b[i]
            if c == UInt8(ascii: "[") {
                if i + 1 < to && b[i + 1] == UInt8(ascii: "["), let e = find(b, "]]", i + 2, to) {
                    match = (e + 2, "lnk")
                } else if hasPrefix(b, at: i, "[fn:"), let e = find(b, "]", i + 4, to) {
                    match = (e + 1, "fn")
                } else if isDate(b, i + 1, to), let e = find(b, "]", i + 1, to) {
                    match = (e + 1, "ts")
                }
            } else if c == UInt8(ascii: "<") && isDate(b, i + 1, to), let e = find(b, ">", i + 1, to) {
                match = (e + 1, "ts")
            } else if c == UInt8(ascii: "h") && (i == from || !isWordChar(b[i - 1]))
                        && (hasPrefix(b, at: i, "https://") || hasPrefix(b, at: i, "http://")) {
                var e = i
                while e < to && !isSpace(b[e]) { e += 1 }
                match = (e, "lnk")
            } else if let cls = emphasisClass(c), let e = emphasisEnd(b, i, from, to) {
                match = (e, cls)
            }
            if let m = match {
                w.text(plain, i)
                w.span(m.cls, i, m.end)
                i = m.end
                plain = i
            } else {
                i += 1
            }
        }
        w.text(plain, to)
    }

    private static func emphasisClass(_ c: UInt8) -> String? {
        switch c {
        case UInt8(ascii: "*"): "b"
        case UInt8(ascii: "/"): "i"
        case UInt8(ascii: "_"): "u"
        case UInt8(ascii: "+"): "s"
        case UInt8(ascii: "="), UInt8(ascii: "~"): "v"
        default: nil
        }
    }

    /// End (past the closing marker) of an emphasis span opening at `i`, following org's
    /// rules for the characters allowed around markers.
    private static func emphasisEnd(_ b: [UInt8], _ i: Int, _ from: Int, _ to: Int) -> Int? {
        let m = b[i]
        if i > from && !isSpace(b[i - 1]) && !contains("-('\"{", b[i - 1]) { return nil }
        guard i + 2 < to, !isSpace(b[i + 1]), b[i + 1] != m else { return nil }
        var k = i + 2
        while k < to {
            if b[k] == m && !isSpace(b[k - 1]) && (k + 1 == to || isSpace(b[k + 1]) || contains("-.,;:!?')}[\"\\", b[k + 1])) {
                return k + 1
            }
            k += 1
        }
        return nil
    }

    // MARK: - Output

    private struct Writer {
        let b: [UInt8]
        var out: [UInt8]

        mutating func text(_ from: Int, _ to: Int) {
            var i = from
            while i < to {
                switch b[i] {
                case UInt8(ascii: "&"): out.append(contentsOf: "&amp;".utf8)
                case UInt8(ascii: "<"): out.append(contentsOf: "&lt;".utf8)
                case UInt8(ascii: ">"): out.append(contentsOf: "&gt;".utf8)
                default: out.append(b[i])
                }
                i += 1
            }
        }

        mutating func open(_ cls: String) {
            out.append(contentsOf: "<span class=\"".utf8)
            out.append(contentsOf: cls.utf8)
            out.append(contentsOf: "\">".utf8)
        }

        mutating func close() {
            out.append(contentsOf: "</span>".utf8)
        }

        mutating func span(_ cls: String, _ from: Int, _ to: Int) {
            open(cls)
            text(from, to)
            close()
        }
    }

    // MARK: - Bytes

    private static func indentEnd(_ b: [UInt8]) -> Int {
        var i = 0
        while i < b.count && isSpace(b[i]) { i += 1 }
        return i
    }

    private static func hasPrefix(_ b: [UInt8], at i: Int, _ p: String) -> Bool {
        var j = i
        for c in p.utf8 {
            guard j < b.count, b[j] == c else { return false }
            j += 1
        }
        return true
    }

    private static func lowerHasPrefix(_ b: [UInt8], at i: Int, _ p: String) -> Bool {
        var j = i
        for c in p.utf8 {
            guard j < b.count, lower(b[j]) == c else { return false }
            j += 1
        }
        return true
    }

    private static func find(_ b: [UInt8], _ s: String, _ from: Int, _ to: Int) -> Int? {
        let n = Array(s.utf8)
        var i = from
        while i + n.count <= to {
            if b[i] == n[0] && Array(b[i..<(i + n.count)]) == n { return i }
            i += 1
        }
        return nil
    }

    /// `YYYY-MM-DD` at `i`.
    private static func isDate(_ b: [UInt8], _ i: Int, _ to: Int) -> Bool {
        guard i + 10 <= to else { return false }
        for k in 0..<10 {
            let ok = (k == 4 || k == 7) ? b[i + k] == UInt8(ascii: "-") : isDigit(b[i + k])
            if !ok { return false }
        }
        return true
    }

    private static func contains(_ set: String, _ c: UInt8) -> Bool { set.utf8.contains(c) }
    private static func lower(_ c: UInt8) -> UInt8 { c >= 65 && c <= 90 ? c + 32 : c }
    private static func isSpace(_ c: UInt8) -> Bool { c == 32 || c == 9 }
    private static func isDigit(_ c: UInt8) -> Bool { c >= 48 && c <= 57 }
    private static func isAlpha(_ c: UInt8) -> Bool { (c >= 65 && c <= 90) || (c >= 97 && c <= 122) }
    private static func isWordChar(_ c: UInt8) -> Bool { isAlpha(c) || isDigit(c) || c >= 0x80 }
    private static func isKeyChar(_ c: UInt8) -> Bool { isAlpha(c) || isDigit(c) || c == 95 || c == 45 }
    private static func isTagChar(_ c: UInt8) -> Bool { isWordChar(c) || c == 95 || c == 64 || c == 35 || c == 37 }
}
