## ADDED Requirements

### Requirement: Timeline weekday tabs

The system SHALL display a SegmentBar with weekday tabs ("周日" through "周六") at the top of the timeline page.

#### Scenario: Weekday tabs displayed

- **WHEN** the timeline page is displayed
- **THEN** a SegmentBar SHALL be shown with 7 tabs labeled "周日", "周一", "周二", "周三", "周四", "周五", "周六"
- **AND** today's tab SHALL be selected by default

#### Scenario: Switch weekday by clicking tab

- **WHEN** user clicks a weekday tab
- **THEN** the NSCollectionView below SHALL reload to show only anime airing on that day

### Requirement: Timeline anime list

The system SHALL display a vertically scrolling NSCollectionView showing anime items filtered by the selected weekday.

#### Scenario: Anime items display

- **WHEN** a weekday tab is selected and data is available
- **THEN** each item SHALL display: cover image (100×120), title, rating score, on-air status, and favorite toggle button

#### Scenario: Anime item click

- **WHEN** user clicks an anime item
- **THEN** the navigator SHALL push a `BangumiDetailViewController` initialized with the anime's `animeId`

#### Scenario: Favorite toggle on anime item

- **WHEN** user clicks the favorite button on an anime item
- **THEN** `FavoriteNetworkHandle.changeFavorite()` SHALL be called
- **AND** on success, the item's favorite state SHALL update in the UI

### Requirement: Timeline data

The system SHALL receive `[BangumiIntro]` data passed from the home page, grouped by `airDay`.

#### Scenario: Data grouped by weekday

- **WHEN** `shinBangumiList` is passed to TimelineViewController
- **THEN** anime items SHALL be grouped by `airDay` (0 = Sunday, 1-6 = Monday through Saturday)
- **AND** each group corresponds to a weekday tab
