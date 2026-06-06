import Foundation

/// 从 catbreak.txt 加载名人语录，每次休息随机抽取一条
struct QuoteStore {
    /// 解析后的语录列表（纯文本，不含序号和空行）
    static let quotes: [String] = {
        guard let path = Bundle.main.path(forResource: "catbreak", ofType: "txt") else {
            return []
        }
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return []
        }

        let lines = content.components(separatedBy: .newlines)
        var result: [String] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // 跳过空行、分类标题行（如"名言名句警句摘抄大全【一】"）
            if trimmed.isEmpty { continue }
            if trimmed.contains("名言名句警句摘抄大全") { continue }
            if trimmed.hasPrefix("http") { continue }

            // 匹配格式："数字、 内容" 或 "数字、内容"
            if let range = trimmed.range(of: #"^\d+、\s*"#, options: .regularExpression) {
                let quoteText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !quoteText.isEmpty {
                    result.append(quoteText)
                }
            }
        }

        return result
    }()

    /// 随机获取一条语录
    static func random() -> String {
        guard !quotes.isEmpty else {
            return "放下键盘，起来活动一下吧！"
        }
        return quotes.randomElement()!
    }
}
