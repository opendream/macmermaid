import AppKit
import SwiftUI

enum MermaidSyntax {
    enum Kind { case keyword, string, comment, arrow, number }
    struct Token { let range: NSRange; let kind: Kind }
    private static let rules: [(NSRegularExpression, Kind)] = [
        (#"\b(flowchart|graph|sequenceDiagram|classDiagram|stateDiagram(?:-v2)?|erDiagram|gantt|pie|mindmap|timeline|gitGraph|journey|subgraph|end|participant|actor|autonumber|activate|deactivate|loop|alt|else|opt|par|and|rect|Note|note|over|section|title|dateFormat|classDef|class|style|linkStyle|direction|click|TD|TB|LR|RL|BT)\b"#, Kind.keyword),
        (#"(?:--+>|==+>|-\.->|-->>|->>|--|\|[^|\n]+\|)"#, Kind.arrow),
        (#"\b\d+(?:\.\d+)?\b"#, Kind.number),
        (#"\"[^\"\n]*\""#, Kind.string),
        (#"%%[^\n]*"#, Kind.comment)
    ].map { (try! NSRegularExpression(pattern: $0.0), $0.1) }

    static func tokens(in text: String) -> [Token] {
        guard text.utf16.count <= 200_000 else { return [] }
        let range = NSRange(location: 0, length: (text as NSString).length)
        return rules.flatMap { regex, kind in regex.matches(in: text, range: range).map { Token(range: $0.range, kind: kind) } }
    }
}

struct CodeEditor: NSViewRepresentable {
    @Binding var text: String
    var fontSize: Double
    var wraps: Bool
    var dark: Bool
    var palette: CatppuccinPalette? = nil
    var selectionChanged: (Int, Int) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeNSView(context: Context) -> NSScrollView {
        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        let container = NSTextContainer(containerSize: NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude))
        layout.addTextContainer(container)
        let editor = SourceTextView(frame: .zero, textContainer: container)
        editor.isRichText = false
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isContinuousSpellCheckingEnabled = false
        editor.isGrammarCheckingEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.allowsUndo = true
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.textContainerInset = NSSize(width: 12, height: 18)
        editor.minSize = NSSize(width: 0, height: 0)
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.isVerticallyResizable = true
        editor.autoresizingMask = [.width]
        editor.delegate = context.coordinator
        editor.setAccessibilityLabel("Mermaid source code")

        let scroll = NSScrollView()
        scroll.documentView = editor
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = false
        scroll.hasVerticalRuler = true
        scroll.verticalRulerView = LineNumberRuler(editor: editor, scrollView: scroll)
        scroll.rulersVisible = true
        context.coordinator.editor = editor
        editor.string = text
        configure(editor, scroll: scroll)
        context.coordinator.highlight()
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let editor = scroll.documentView as? SourceTextView else { return }
        let configurationChanged = editor.font?.pointSize != CGFloat(fontSize) || context.coordinator.dark != dark || context.coordinator.palette != palette
        if editor.string != text {
            let range = editor.selectedRange()
            editor.string = text
            editor.setSelectedRange(NSRange(location: min(range.location, (text as NSString).length), length: 0))
            context.coordinator.highlight()
        }
        configure(editor, scroll: scroll)
        if configurationChanged { context.coordinator.highlight() }
        scroll.verticalRulerView?.needsDisplay = true
    }

    private func configure(_ editor: SourceTextView, scroll: NSScrollView) {
        editor.font = .monospacedSystemFont(ofSize: fontSize, weight: .regular)
        editor.backgroundColor = palette?.color("base") ?? (dark ? NSColor(calibratedRed: 0.105, green: 0.135, blue: 0.15, alpha: 1) : NSColor(calibratedRed: 0.985, green: 0.987, blue: 0.985, alpha: 1))
        editor.insertionPointColor = palette?.color("rosewater") ?? .controlAccentColor
        editor.selectedTextAttributes = [.backgroundColor: palette?.color("surface1") ?? .selectedTextBackgroundColor,
                                         .foregroundColor: palette?.color("text") ?? .selectedTextColor]
        (scroll.verticalRulerView as? LineNumberRuler)?.textColor = palette?.color("subtext0") ?? .tertiaryLabelColor
        editor.isHorizontallyResizable = !wraps
        editor.textContainer?.widthTracksTextView = wraps
        editor.textContainer?.containerSize = NSSize(width: wraps ? max(100, scroll.contentSize.width - 24) : CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        scroll.hasHorizontalScroller = !wraps
        if wraps { editor.setFrameSize(NSSize(width: scroll.contentSize.width, height: editor.frame.height)) }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: CodeEditor
        weak var editor: SourceTextView?
        var dark = false
        var palette: CatppuccinPalette?
        init(_ parent: CodeEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor else { return }
            parent.text = editor.string
            highlight()
            editor.enclosingScrollView?.verticalRulerView?.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard let editor else { return }
            let text = editor.string as NSString
            let location = min(editor.selectedRange().location, text.length)
            let before = text.substring(to: location)
            let line = before.filter { $0 == "\n" }.count + 1
            let column = (before.components(separatedBy: "\n").last?.count ?? 0) + 1
            parent.selectionChanged(line, column)
        }

        func highlight() {
            guard let editor, let storage = editor.textStorage else { return }
            dark = parent.dark
            palette = parent.palette
            let range = NSRange(location: 0, length: storage.length)
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 5
            paragraph.tabStops = []
            paragraph.defaultTabInterval = parent.fontSize * 2.4
            let base: [NSAttributedString.Key: Any] = [
                .font: NSFont.monospacedSystemFont(ofSize: parent.fontSize, weight: .regular),
                .foregroundColor: palette?.color("text") ?? (dark ? NSColor(calibratedWhite: 0.84, alpha: 1) : NSColor(calibratedRed: 0.25, green: 0.31, blue: 0.34, alpha: 1)),
                .paragraphStyle: paragraph
            ]
            storage.beginEditing()
            storage.setAttributes(base, range: range)
            for token in MermaidSyntax.tokens(in: editor.string) {
                let color: NSColor
                switch token.kind {
                case .keyword: color = dark ? .systemTeal : NSColor(calibratedRed: 0.12, green: 0.43, blue: 0.43, alpha: 1)
                case .string: color = dark ? .systemOrange : NSColor(calibratedRed: 0.63, green: 0.35, blue: 0.17, alpha: 1)
                case .comment: color = .secondaryLabelColor
                case .arrow: color = dark ? .systemPurple : NSColor(calibratedRed: 0.52, green: 0.39, blue: 0.68, alpha: 1)
                case .number: color = .systemOrange
                }
                storage.addAttribute(.foregroundColor, value: palette?.syntaxColor(token.kind) ?? color, range: token.range)
            }
            storage.endEditing()
            editor.typingAttributes = base
        }
    }
}

final class SourceTextView: NSTextView {
    override func insertTab(_ sender: Any?) { indent(outdent: false) }
    override func insertBacktab(_ sender: Any?) { indent(outdent: true) }
    override func insertNewline(_ sender: Any?) {
        let source = string as NSString
        let line = source.substring(with: source.lineRange(for: NSRange(location: selectedRange().location, length: 0)))
        let indentation = String(line.prefix { $0 == " " || $0 == "\t" })
        insertText("\n" + indentation, replacementRange: selectedRange())
    }
    private func indent(outdent: Bool) {
        let selection = selectedRange()
        if selection.length == 0 && !outdent {
            insertText("    ", replacementRange: selection)
            return
        }
        let source = string as NSString
        let adjusted = NSRange(location: selection.location, length: max(0, selection.length - 1))
        let range = source.lineRange(for: adjusted)
        let value = source.substring(with: range)
        var lines = value.components(separatedBy: "\n")
        let hasTrailingNewline = value.hasSuffix("\n")
        if hasTrailingNewline { lines.removeLast() }
        let replacement = lines.map { line in
            if !outdent { return "    " + line }
            if line.hasPrefix("\t") { return String(line.dropFirst()) }
            return String(line.dropFirst(line.prefix(4).prefix { $0 == " " }.count))
        }.joined(separator: "\n") + (hasTrailingNewline ? "\n" : "")
        insertText(replacement, replacementRange: range)
        setSelectedRange(NSRange(location: range.location, length: (replacement as NSString).length))
    }
}

final class LineNumberRuler: NSRulerView {
    weak var editor: NSTextView?
    var textColor: NSColor = .tertiaryLabelColor
    override var isFlipped: Bool { true }
    init(editor: NSTextView, scrollView: NSScrollView) {
        self.editor = editor
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        // Keep AppKit's ruler border inside the editor, out of the window chrome.
        clipsToBounds = true
        clientView = editor
        ruleThickness = 48
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(self, selector: #selector(scrolled), name: NSView.boundsDidChangeNotification, object: scrollView.contentView)
    }
    required init(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    @objc private func scrolled() { needsDisplay = true }
    override func drawHashMarksAndLabels(in rect: NSRect) {
        guard let editor, let layout = editor.layoutManager, let container = editor.textContainer else { return }
        editor.backgroundColor.setFill(); bounds.fill()
        let source = editor.string as NSString
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular), .foregroundColor: textColor]
        let visible = editor.visibleRect
        let glyphRange = layout.glyphRange(forBoundingRect: visible, in: container)
        let visibleCharacters = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
        var index = 0, number = 1
        while index < source.length {
            if index >= visibleCharacters.location {
                let glyph = layout.glyphIndexForCharacter(at: index)
                let fragment = layout.lineFragmentRect(forGlyphAt: glyph, effectiveRange: nil)
                let origin = convert(NSPoint(x: 0, y: fragment.minY + editor.textContainerOrigin.y), from: editor)
                let label = "\(number)" as NSString
                label.draw(at: NSPoint(x: ruleThickness - label.size(withAttributes: attributes).width - 12, y: origin.y + 2), withAttributes: attributes)
                if index > NSMaxRange(visibleCharacters) { break }
            }
            index = NSMaxRange(source.lineRange(for: NSRange(location: index, length: 0)))
            number += 1
        }
        if source.length == 0 || editor.string.hasSuffix("\n") {
            let origin = convert(NSPoint(x: 0, y: layout.extraLineFragmentRect.minY + editor.textContainerOrigin.y), from: editor)
            let label = "\(number)" as NSString
            label.draw(at: NSPoint(x: ruleThickness - label.size(withAttributes: attributes).width - 12, y: origin.y + 2), withAttributes: attributes)
        }
    }
}
