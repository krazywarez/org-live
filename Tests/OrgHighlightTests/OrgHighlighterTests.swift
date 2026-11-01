import Testing
@testable import OrgHighlight

/// The inner HTML of each line, without the `<div class="ln">` wrapper.
private func lines(_ source: String) -> [String] {
    OrgHighlighter.lines(source).map { line in
        #expect(line.hasPrefix("<div class=\"ln\">") && line.hasSuffix("\n</div>"))
        return String(line.dropFirst("<div class=\"ln\">".count).dropLast("\n</div>".count))
    }
}

@Test func oneDivPerSourceLine() {
    #expect(lines("").count == 1)
    #expect(lines("a\n").count == 2)
    #expect(lines("a\n\nb").count == 3)
}

@Test func escapesHTML() {
    #expect(lines("<script>&") == ["&lt;script&gt;&amp;"])
}

@Test func headings() {
    #expect(lines("* Title") == [#"<span class="h1">* Title</span>"#])
    #expect(lines("** TODO [#A] Fix it :work:urgent:") == [
        #"<span class="h2">** <span class="todo">TODO</span> <span class="pri">[#A]</span> Fix it <span class="tag">:work:urgent:</span></span>"#
    ])
    #expect(lines("**** DONE x") == [#"<span class="h1">**** <span class="done">DONE</span> x</span>"#])
    #expect(lines("*bold* text") == [#"<span class="b">*bold*</span> text"#])
    #expect(lines("* TODOs") == [#"<span class="h1">* TODOs</span>"#])
    #expect(lines("* a:b:") == [#"<span class="h1">* a:b:</span>"#])
}

@Test func blocks() {
    let src = "#+BEGIN_SRC swift\nlet x = *y*\n#+end_src\n*b*"
    #expect(lines(src) == [
        #"<span class="meta">#+BEGIN_SRC swift</span>"#,
        #"<span class="blk">let x = *y*</span>"#,
        #"<span class="meta">#+end_src</span>"#,
        #"<span class="b">*b*</span>"#,
    ])
    #expect(lines("#+begin_quote\n* not a heading /i/\n#+end_quote") == [
        #"<span class="meta">#+begin_quote</span>"#,
        #"* not a heading <span class="i">/i/</span>"#,
        #"<span class="meta">#+end_quote</span>"#,
    ])
}

@Test func lineKinds() {
    #expect(lines("#+TITLE: Notes") == [#"<span class="kw">#+TITLE:</span> Notes"#])
    #expect(lines("# a comment") == [#"<span class="cmt"># a comment</span>"#])
    #expect(lines("#hashtag") == ["#hashtag"])
    #expect(lines("| a | b |") == [#"<span class="tbl">| a | b |</span>"#])
    #expect(lines("  :PROPERTIES:") == [#"<span class="drw">  :PROPERTIES:</span>"#])
    #expect(lines(":ID: 42") == [#"<span class="drw">:ID:</span> 42"#])
    #expect(lines(": fixed") == [#"<span class="fix">: fixed</span>"#])
    #expect(lines("-----") == [#"<span class="hr">-----</span>"#])
}

@Test func lists() {
    #expect(lines("- [X] done") == [#"<span class="bul">- </span><span class="cb">[X]</span> done"#])
    #expect(lines("  1. one") == [#"<span class="bul">  1. </span>one"#])
    #expect(lines("  * star item") == [#"<span class="bul">  * </span>star item"#])
    #expect(lines("-5 degrees") == ["-5 degrees"])
}

@Test func inlineMarkup() {
    #expect(lines("a /it/ _u_ +s+ =v= ~c~.") == [
        #"a <span class="i">/it/</span> <span class="u">_u_</span> <span class="s">+s+</span> <span class="v">=v=</span> <span class="v">~c~</span>."#
    ])
    #expect(lines("a/b/c and 2*3*4") == ["a/b/c and 2*3*4"])
    #expect(lines("* not closed") == [#"<span class="h1">* not closed</span>"#])
    #expect(lines("x * y * z") == ["x * y * z"])
}

@Test func linksAndTimestamps() {
    #expect(lines("see [[https://a.b][A <b>]] now") == [
        #"see <span class="lnk">[[https://a.b][A &lt;b&gt;]]</span> now"#
    ])
    #expect(lines("at https://a.b/c/d/ ok") == [#"at <span class="lnk">https://a.b/c/d/</span> ok"#])
    #expect(lines("<2026-11-01 Sun> [2026-11-01]") == [
        #"<span class="ts">&lt;2026-11-01 Sun&gt;</span> <span class="ts">[2026-11-01]</span>"#
    ])
    #expect(lines("note[fn:1]") == [#"note<span class="fn">[fn:1]</span>"#])
}

@Test func nonASCII() {
    #expect(lines("* Café /naïve/ 日本") == [#"<span class="h1">* Café <span class="i">/naïve/</span> 日本</span>"#])
}
