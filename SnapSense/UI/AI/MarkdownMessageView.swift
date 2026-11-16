import SwiftUI

struct MarkdownMessageView: View {
    let markdown: String
    let isStreaming: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(MarkdownParser.parse(markdown)) { block in
                blockView(block)
            }

            if isStreaming {
                RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                    .fill(Color.accentColor)
                    .frame(width: 7, height: 14)
                    .padding(.top, 1)
                    .accessibilityLabel("Идёт генерация")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockView(_ block: MarkdownBlock) -> some View {
        switch block.content {
        case .prose(let text):
            if let attributed = markdownText(text) {
                Text(attributed)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text(text)
                    .font(.system(size: 12.5))
                    .lineSpacing(3)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .code(let language, let code):
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(language?.uppercased() ?? "КОД")
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.10))

                ScrollView(.horizontal, showsIndicators: false) {
                    Text(code)
                        .font(.system(size: 11.5, design: .monospaced))
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: true, vertical: false)
                        .padding(10)
                }
            }
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.black.opacity(0.14))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.09), lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private func markdownText(_ text: String) -> AttributedString? {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return try? AttributedString(markdown: text, options: options)
    }
}

private struct MarkdownBlock: Identifiable {
    enum Content {
        case prose(String)
        case code(language: String?, text: String)
    }

    let id: Int
    let content: Content
}

private enum MarkdownParser {
    static func parse(_ markdown: String) -> [MarkdownBlock] {
        let lines = markdown.components(separatedBy: "\n")
        var blocks: [MarkdownBlock] = []
        var proseLines: [String] = []
        var codeLines: [String]?
        var codeLanguage: String?
        var nextID = 0

        func appendProse() {
            let text = proseLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !text.isEmpty {
                blocks.append(MarkdownBlock(id: nextID, content: .prose(text)))
                nextID += 1
            }
            proseLines.removeAll(keepingCapacity: true)
        }

        func appendCode() {
            guard let currentCode = codeLines else { return }
            blocks.append(
                MarkdownBlock(
                    id: nextID,
                    content: .code(
                        language: codeLanguage,
                        text: currentCode.joined(separator: "\n")
                    )
                )
            )
            nextID += 1
            codeLines = nil
            codeLanguage = nil
        }

        for line in lines {
            if line.hasPrefix("```") {
                if codeLines != nil {
                    appendCode()
                } else {
                    appendProse()
                    let language = String(line.dropFirst(3))
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    codeLanguage = language.isEmpty ? nil : language
                    codeLines = []
                }
            } else if codeLines != nil {
                codeLines?.append(line)
            } else {
                proseLines.append(line)
            }
        }

        appendProse()
        appendCode()

        if blocks.isEmpty, !markdown.isEmpty {
            return [MarkdownBlock(id: 0, content: .prose(markdown))]
        }
        return blocks
    }
}
