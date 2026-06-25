import Foundation

/// 从语录文件加载名人语录，使用洗牌算法确保短期内不重复
///
/// 根据当前语言设置自动选择：
/// - 中文：catbreak.txt
/// - 英文：catbreak-en.txt
///
/// `@MainActor` 约束：`shuffledQuotes` / `currentIndex` 为静态可变状态，
/// 仅允许从主线程访问，避免并发竞争。当前调用点（BreakOverlayWindow.show）均在主线程。
@MainActor
struct QuoteStore {
    /// 当前语言的语录列表
    static var quotes: [String] {
        let lang = LanguageManager.shared.resolvedCode
        let fileName = (lang == "en") ? "catbreak-en" : "catbreak"
        return loadQuotes(from: fileName)
    }

    /// 从指定文件加载语录
    private static func loadQuotes(from fileName: String) -> [String] {
        guard let path = Bundle.main.path(forResource: fileName, ofType: "txt") else {
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

            // 匹配格式："数字、 内容" 或 "数字、内容"（中文顿号）
            if let range = trimmed.range(of: #"^\d+、\s*"#, options: .regularExpression) {
                let quoteText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !quoteText.isEmpty {
                    result.append(quoteText)
                }
            }
            // 匹配格式："数字. 内容" 或 "数字.内容"（英文句点）
            else if let range = trimmed.range(of: #"^\d+\.\s*"#, options: .regularExpression) {
                let quoteText = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if !quoteText.isEmpty {
                    result.append(quoteText)
                }
            }
        }

        return result
    }

    /// 洗牌后的语录列表
    static private var shuffledQuotes: [String] = []
    /// 当前取语录的索引
    static private var currentIndex: Int = 0
    /// 上次加载语录时的语言代码，用于检测语言切换
    static private var lastLanguageCode: String?

    /// 使用洗牌算法获取一条语录，确保短期内不重复
    static func random() -> String {
        let currentLang = LanguageManager.shared.resolvedCode

        // 如果语言切换了，清空之前的洗牌列表，强制重新加载
        if lastLanguageCode != currentLang {
            shuffledQuotes = []
            currentIndex = 0
            lastLanguageCode = currentLang
        }

        guard !quotes.isEmpty else {
            return L10n.tr("break.default_quote")
        }

        // 如果洗牌列表已空或已遍历完，重新洗牌
        if shuffledQuotes.isEmpty || currentIndex >= shuffledQuotes.count {
            shuffledQuotes = quotes.shuffled()
            currentIndex = 0
        }

        // 从洗牌列表中依次取出
        let quote = shuffledQuotes[currentIndex]
        currentIndex += 1
        return quote
    }
}
