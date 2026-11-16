//
//  ResourceSearchModels.swift
//  AniXPlayer
//
//  macOS：资源搜索（res.dandanplay.net）的数据模型。
//

import Foundation

struct ResourceSearchItem: Equatable, Identifiable {
    let title: String
    let typeId: Int
    let typeName: String
    let subgroupId: Int
    let subgroupName: String
    let magnet: String
    let torrentUrl: String?
    let pageUrl: String?
    let fileSize: String
    let publishDate: String

    init(
        title: String,
        typeId: Int = 0,
        typeName: String = "",
        subgroupId: Int = 0,
        subgroupName: String = "",
        magnet: String = "",
        torrentUrl: String? = nil,
        pageUrl: String? = nil,
        fileSize: String = "",
        publishDate: String = ""
    ) {
        self.title = title
        self.typeId = typeId
        self.typeName = typeName
        self.subgroupId = subgroupId
        self.subgroupName = subgroupName
        self.magnet = magnet
        self.torrentUrl = torrentUrl
        self.pageUrl = pageUrl
        self.fileSize = fileSize
        self.publishDate = publishDate
    }

    var id: String {
        let magnet = self.magnet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !magnet.isEmpty { return magnet }
        if let torrentUrl = torrentUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !torrentUrl.isEmpty {
            return torrentUrl
        }
        return "\(title)|\(publishDate)|\(subgroupId)"
    }

    /// 优先磁力链接，缺失时回退到种子下载地址。
    var downloadSource: String? {
        let magnet = self.magnet.trimmingCharacters(in: .whitespacesAndNewlines)
        if !magnet.isEmpty { return magnet }
        if let torrentUrl = torrentUrl?.trimmingCharacters(in: .whitespacesAndNewlines), !torrentUrl.isEmpty {
            return torrentUrl
        }
        return nil
    }

    var displayTypeName: String {
        typeName.isEmpty ? NSLocalizedString("未分类", comment: "") : typeName
    }

    var displaySubgroupName: String {
        subgroupName.isEmpty ? NSLocalizedString("未知字幕组", comment: "") : subgroupName
    }

    var displayFileSize: String {
        fileSize.isEmpty ? "-" : fileSize
    }

    var displayPublishDate: String {
        publishDate.isEmpty ? "-" : publishDate
    }
}

extension ResourceSearchItem: Decodable {

    private enum CodingKeys: String, CodingKey {
        case title
        case typeId
        case typeName
        case subgroupId
        case subgroupName
        case magnet
        case torrentUrl
        case pageUrl
        case fileSize
        case publishDate
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        typeId = try container.decodeIfPresent(Int.self, forKey: .typeId) ?? 0
        typeName = try container.decodeIfPresent(String.self, forKey: .typeName) ?? ""
        subgroupId = try container.decodeIfPresent(Int.self, forKey: .subgroupId) ?? 0
        subgroupName = try container.decodeIfPresent(String.self, forKey: .subgroupName) ?? ""
        magnet = try container.decodeIfPresent(String.self, forKey: .magnet) ?? ""
        torrentUrl = try container.decodeIfPresent(String.self, forKey: .torrentUrl)
        pageUrl = try container.decodeIfPresent(String.self, forKey: .pageUrl)
        fileSize = try container.decodeIfPresent(String.self, forKey: .fileSize) ?? ""
        publishDate = try container.decodeIfPresent(String.self, forKey: .publishDate) ?? ""
    }
}

struct ResourceSearchResponse: Decodable {
    let hasMore: Bool
    let resources: [ResourceSearchItem]

    private enum CodingKeys: String, CodingKey {
        case hasMore
        case resources
    }

    init(hasMore: Bool = false, resources: [ResourceSearchItem] = []) {
        self.hasMore = hasMore
        self.resources = resources
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        hasMore = try container.decodeIfPresent(Bool.self, forKey: .hasMore) ?? false
        resources = try container.decodeIfPresent([ResourceSearchItem].self, forKey: .resources) ?? []
    }
}

struct ResourceSearchOption: Equatable, Identifiable {
    let id: Int
    let name: String
}

extension ResourceSearchOption: Decodable {

    private enum CodingKeys: String, CodingKey {
        case id
        case name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
    }
}

struct ResourceTypeListResponse: Decodable {
    let types: [ResourceSearchOption]

    private enum CodingKeys: String, CodingKey {
        case types
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        types = try container.decodeIfPresent([ResourceSearchOption].self, forKey: .types) ?? []
    }
}

struct ResourceSubgroupListResponse: Decodable {
    let subgroups: [ResourceSearchOption]

    private enum CodingKeys: String, CodingKey {
        case subgroups
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        subgroups = try container.decodeIfPresent([ResourceSearchOption].self, forKey: .subgroups) ?? []
    }
}

/// 资源列表的本地筛选条件。`nil` 代表全部。
struct ResourceSearchFilter: Equatable {
    var typeId: Int?
    var subgroupId: Int?

    var isActive: Bool {
        typeId != nil || subgroupId != nil
    }

    func apply(to items: [ResourceSearchItem]) -> [ResourceSearchItem] {
        items.filter { item in
            if let typeId = typeId, item.typeId != typeId { return false }
            if let subgroupId = subgroupId, item.subgroupId != subgroupId { return false }
            return true
        }
    }
}
