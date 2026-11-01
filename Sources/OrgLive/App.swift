import ElementaryUI
import JavaScriptKit
import OrgHighlight
import OrgSwift

@main
struct App {
    static func main() {
        let app = Application(Editor())
        app.mount(in: .body)
    }
}

@View
struct Editor {
    var body: some View {
        form(.autocomplete(.on)) {
            div(.class("toolbar")) {
                label(.custom(name: "for", value: "editor")) { "org-live" }
                span(.class("spacer")) {}
                button(.type(.button)) { "Save HTML" }
                    .onClick { save(renderHTML(editorValue()), extension: "html") }
                button(.type(.button)) { "Save Org" }
                    .onClick { save(editorValue(), extension: "org") }
            }
            div(.id("source")) {
                div(.class("layers")) {
                    div(.id("highlight"), .custom(name: "aria-hidden", value: "true")) {}
                    textarea(
                        .id("editor"),
                        .name("editor"),
                        .custom(name: "autocapitalize", value: "on"),
                        .custom(name: "autocorrect", value: "on"),
                        .custom(name: "spellcheck", value: "true"),
                        .placeholder("* Lorem Ipsum"),
                        .cols(80),
                        .wrap(.hard),
                        .autofocus,
                        .required
                    ) {}
                    .onInput { event in update(event.targetValue ?? "") }
                    .onAppear {
                        let editor = document.getElementById!("editor").object!
                        editor.value = .string(sample)
                        _ = editor.focus!()
                        _ = editor.setSelectionRange!(0, 0)
                        update(sample)
                        document.getElementById!("source").object!.scrollTop = 0
                    }
                }
            }
        }
        div(.id("preview")) {}
    }
}

private let document = JSObject.global.document.object!
private var preview: JSObject { document.getElementById!("preview").object! }
private var highlight: JSObject { document.getElementById!("highlight").object! }

private func editorValue() -> String {
    document.getElementById!("editor").value.string ?? ""
}

/// Lines currently in #highlight, so an edit only replaces the lines that changed.
private var shownLines: [String] = []

private func update(_ org: String) {
    updateHighlight(OrgHighlighter.lines(org))
    preview.innerHTML = .string(renderHTML(org))
}

private func updateHighlight(_ lines: [String]) {
    var start = 0
    while start < lines.count && start < shownLines.count && lines[start] == shownLines[start] { start += 1 }
    var newEnd = lines.count
    var oldEnd = shownLines.count
    while newEnd > start && oldEnd > start && lines[newEnd - 1] == shownLines[oldEnd - 1] {
        newEnd -= 1
        oldEnd -= 1
    }
    shownLines = lines
    let element = highlight
    let children = element.children.object!
    if oldEnd > start {
        let range = document.createRange!().object!
        _ = range.setStartBefore!(children[start])
        _ = range.setEndAfter!(children[oldEnd - 1])
        _ = range.deleteContents!()
    }
    guard newEnd > start else { return }
    let html = JSValue.string(lines[start..<newEnd].joined())
    if start < Int(children.length.number!) {
        _ = children[start].object!.insertAdjacentHTML!("beforebegin", html)
    } else {
        _ = element.insertAdjacentHTML!("beforeend", html)
    }
}

private func renderHTML(_ org: String) -> String {
    var options = OrgRenderOptions()
    options.headingLevelOffset = 1
    return OrgRenderer.renderToHTML(org, options: options)
}

private func save(_ data: String, extension ext: String) {
    let filename = JSObject.global.Date.object!.new().toISOString!().string!
    let blob = JSObject.global.Blob.object!.new([data])
    let url = JSObject.global.URL.object!.createObjectURL!(blob)
    let a = document.createElement!("a").object!
    a.href = url
    a.download = .string("\(filename).\(ext)")
    _ = a.click!()
    _ = JSObject.global.URL.object!.revokeObjectURL!(url)
}
