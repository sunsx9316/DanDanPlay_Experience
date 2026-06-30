## ADDED Requirements

### Requirement: Metadata categories

The system SHALL display metadata in three NSTableView sections: titles, production info, and external links.

#### Scenario: Titles section

- **WHEN** metadata page is displayed with `[BangumiTitle]` data
- **THEN** the first section SHALL display each title with its language as subtitle
- **AND** clicking a title row SHALL copy the title to clipboard

#### Scenario: Metadata section

- **WHEN** metadata page is displayed with `[String]` metadata
- **THEN** the second section "制作信息" SHALL display each string as a single row
- **AND** clicking a row SHALL copy the text to clipboard

#### Scenario: External links section

- **WHEN** metadata page is displayed with `[BangumiOnlineDatabase]` data
- **THEN** the third section "站外相关链接" SHALL display each link with site name and URL
- **AND** clicking a link SHALL open the URL in the default browser

### Requirement: Data input

The system SHALL accept metadata, titles, and online databases via a configure method.

#### Scenario: Data configured before display

- **WHEN** `update(metaData:titles:onlineDatabases:)` is called before the view appears
- **THEN** the NSTableView SHALL display all three sections with the provided data
