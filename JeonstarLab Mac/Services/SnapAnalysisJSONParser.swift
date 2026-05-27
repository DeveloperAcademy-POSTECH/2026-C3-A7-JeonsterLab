//
//  SnapAnalysisJSONParser.swift
//  JeonstarLab Mac
//

import Foundation

enum SnapAnalysisJSONParser {
    static func parse(url: URL) throws -> SnapAnalysisExport {
        let data = try Data(contentsOf: url)
        return try JSONDecoder.exportDecoder.decode(SnapAnalysisExport.self, from: data)
    }
}
