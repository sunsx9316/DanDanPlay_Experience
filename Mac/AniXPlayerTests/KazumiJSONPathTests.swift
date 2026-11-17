import XCTest

final class KazumiJSONPathTests: XCTestCase {

    private let document: [String: Any] = [
        "items": [
            [
                "type": "tv",
                "name": "A",
                "episodes": [["name": "A1"], ["name": "A2"]]
            ],
            [
                "type": "movie",
                "name": "B",
                "episodes": [["name": "B1"]]
            ],
            [
                "type": "tv",
                "name": "C",
                "episodes": []
            ]
        ],
        "other": ["name": "D"]
    ]

    // MARK: - Filters

    func testFilterEqualityExistsAndInequality() throws {
        XCTAssertEqual(
            try names("$.items[?(@.type == 'tv')].name"),
            ["A", "C"]
        )
        XCTAssertEqual(
            try names("$.items[?(@.type != 'movie')].name"),
            ["A", "C"]
        )
        XCTAssertEqual(
            try names("$.items[?(@.name)].name"),
            ["A", "B", "C"]
        )
        XCTAssertEqual(
            try names("$.items[?(@.missing == 'x')]"),
            []
        )
        // 字段缺失时 != 视为不相等，便于规则排除某个具体类型。
        XCTAssertEqual(
            try names("$.items[?(@.missing != 'x')].name"),
            ["A", "B", "C"]
        )
        XCTAssertEqual(
            try names("$.items[?(@.type == \"tv\")].name"),
            ["A", "C"]
        )
        XCTAssertEqual(
            try names("$.items[?(@['type'] == 'tv')].name"),
            ["A", "C"]
        )
    }

    func testFilterSupportsNumbersAndBooleans() throws {
        let value: [String: Any] = [
            "list": [
                ["id": 1, "enabled": true, "label": "one"],
                ["id": 2, "enabled": false, "label": "two"]
            ]
        ]
        XCTAssertEqual(
            try KazumiJSONPath.read(value, path: "$.list[?(@.id == 2)].label")
                .compactMap { $0 as? String },
            ["two"]
        )
        XCTAssertEqual(
            try KazumiJSONPath.read(value, path: "$.list[?(@.enabled == true)].label")
                .compactMap { $0 as? String },
            ["one"]
        )
    }

    // MARK: - Recursive descent and slices

    func testRecursiveDescent() throws {
        XCTAssertEqual(
            try names("$..name"),
            ["A", "A1", "A2", "B", "B1", "C", "D"]
        )
        XCTAssertEqual(
            try names("$..episodes[0].name"),
            ["A1", "B1"]
        )
        XCTAssertFalse(try KazumiJSONPath.read(document, path: "$..*").isEmpty)
    }

    func testArraySlices() throws {
        XCTAssertEqual(
            try names("$.items[0:2].name"),
            ["A", "B"]
        )
        XCTAssertEqual(
            try names("$.items[:2].name"),
            ["A", "B"]
        )
        XCTAssertEqual(
            try names("$.items[-2:].name"),
            ["B", "C"]
        )
        XCTAssertEqual(
            try names("$.items[5:9].name"),
            []
        )
    }

    // MARK: - Union

    func testIndexAndKeyUnions() throws {
        XCTAssertEqual(
            try names("$.items[0,2].name"),
            ["A", "C"]
        )

        let value: [String: Any] = [
            "a": ["k": "1"],
            "b": ["k": "2"],
            "c": ["k": "3"]
        ]
        XCTAssertEqual(
            try KazumiJSONPath.read(value, path: "$['a','c'].k")
                .compactMap { $0 as? String },
            ["1", "3"]
        )
    }

    func testQuotedKeysWithCommasAreNotTreatedAsUnion() throws {
        let value: [String: Any] = [
            "a,b": ["k": "value"]
        ]
        XCTAssertEqual(
            try KazumiJSONPath.read(value, path: "$['a,b'].k")
                .compactMap { $0 as? String },
            ["value"]
        )
    }

    // MARK: - Unsupported syntax

    func testUnsupportedSyntaxThrowsInsteadOfReturningEmpty() {
        let paths = [
            "$.items[?(@.score > 8)]",
            "$.items[?(@.score < 8)]",
            "$.items[?(@.name =~ 'A')]",
            "$.items[?(@.name == 'A' && @.type == 'tv')]",
            "$.items[::2]",
            "$.items[?(@.name ==)]",
            "$..",
            "$.items[?(@.[0])]"
        ]

        for path in paths {
            XCTAssertThrowsError(try KazumiJSONPath.read(document, path: path), path) { error in
                XCTAssertTrue(
                    error.localizedDescription.contains("JSONPath"),
                    "\(path) 应给出明确的 JSONPath 错误，实际：\(error.localizedDescription)"
                )
            }
        }
    }

    // MARK: - Helpers

    private func names(_ path: String) throws -> [String] {
        return try KazumiJSONPath.read(document, path: path)
            .compactMap { $0 as? String }
    }
}
