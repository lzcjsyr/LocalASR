import Foundation

struct LLMConfiguration: Equatable {
    let baseURL: String
    let model: String
    let prompt: String

    static let defaultPrompt = """
    你是一名专业的中文文字编辑。请在不改变原意、不编造事实的前提下，整理下面的语音转写稿：修正明显的识别错误，删除口头禅和无意义重复，合并零散句子，并按自然段排版。保留专有名词、数字和关键信息。只输出整理后的正文，不要解释修改过程。
    """
}
