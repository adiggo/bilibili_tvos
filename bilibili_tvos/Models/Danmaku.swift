import Foundation

struct DanmakuItem: Identifiable {
    let id = UUID()
    let time: Double
    let text: String
}

final class DanmakuXMLParser: NSObject, XMLParserDelegate {
    private(set) var items: [DanmakuItem] = []
    private var currentText = ""
    private var currentTime: Double?
    private var isInDanmaku = false
    
    func parse(data: Data) throws -> [DanmakuItem] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        if parser.parse() {
            return items
        } else {
            throw parser.parserError ?? NSError(domain: "Danmaku", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to parse danmaku XML"]) 
        }
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName == "d" {
            isInDanmaku = true
            currentText = ""
            if let p = attributeDict["p"], let first = p.split(separator: ",").first, let time = Double(first) {
                currentTime = time
            } else {
                currentTime = nil
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        if isInDanmaku {
            currentText += string
        }
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        if elementName == "d" {
            if let time = currentTime {
                let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    items.append(DanmakuItem(time: time, text: trimmed))
                }
            }
            isInDanmaku = false
            currentText = ""
            currentTime = nil
        }
    }
}
