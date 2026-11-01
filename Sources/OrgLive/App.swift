import ElementaryUI
import JavaScriptKit
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
            div {
                label(.custom(name: "for", value: "editor")) { "org-live" }
                span(.class("spacer")) {}
                button(.type(.button)) { "Save HTML" }
                    .onClick { save(renderHTML(editorValue()), extension: "html") }
                button(.type(.button)) { "Save Org" }
                    .onClick { save(editorValue(), extension: "org") }
            }
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
            .onInput { event in
                preview.innerHTML = .string(renderHTML(event.targetValue ?? ""))
            }
        }
        div(.id("preview")) {}
    }
}

private let document = JSObject.global.document.object!
private var preview: JSObject { document.getElementById!("preview").object! }

private func editorValue() -> String {
    document.getElementById!("editor").value.string ?? ""
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
