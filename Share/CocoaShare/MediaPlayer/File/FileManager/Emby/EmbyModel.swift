//
//  EmbyModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

import Foundation

// MARK: - Auth

struct EmbyAuthResponse: Decodable {
    let user: EmbyUser
    let accessToken: String

    private enum CodingKeys: String, CodingKey {
        case user = "User"
        case accessToken = "AccessToken"
    }
}

struct EmbyUser: Decodable {
    let id: String
    let name: String

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
    }
}

// MARK: - Items

struct EmbyItemsResponse: Decodable {
    let items: [EmbyItem]
    let totalRecordCount: Int

    private enum CodingKeys: String, CodingKey {
        case items = "Items"
        case totalRecordCount = "TotalRecordCount"
    }
}

struct EmbyItem: Decodable {

    let id: String
    let name: String
    let type: String

    let imageTags: [String: String]?

    let seriesName: String?
    let seasonName: String?
    let indexNumber: Int?
    let parentIndexNumber: Int?
    let productionYear: Int?
    let runTimeTicks: Int64?
    let mediaSources: [EmbyMediaSource]?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case name = "Name"
        case type = "Type"
        case imageTags = "ImageTags"
        case seriesName = "SeriesName"
        case seasonName = "SeasonName"
        case indexNumber = "IndexNumber"
        case parentIndexNumber = "ParentIndexNumber"
        case productionYear = "ProductionYear"
        case runTimeTicks = "RunTimeTicks"
        case mediaSources = "MediaSources"
    }

    var isFolder: Bool {
        switch type {
        case "Series", "Season", "BoxSet", "Folder", "CollectionFolder", "UserView", "Playlist":
            return true
        default:
            return false
        }
    }

    var primaryImageTag: String? {
        return imageTags?["Primary"]
    }

    var size: Int64? {
        return mediaSources?.first?.size
    }
}

struct EmbyMediaSource: Decodable {
    let id: String
    let size: Int64?

    private enum CodingKeys: String, CodingKey {
        case id = "Id"
        case size = "Size"
    }
}
