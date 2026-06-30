## ADDED Requirements

### Requirement: Bangumi detail page display

The system SHALL display a bangumi detail page using NSCollectionView with a supplementary header and multiple content sections.

#### Scenario: Detail page loads

- **WHEN** `BangumiDetailViewController(animateId:)` is pushed onto the navigation stack
- **THEN** `BangumiNetworkHandle.detail(animateId:)` SHALL be called
- **AND** on success, the NSCollectionView SHALL display the detail data

### Requirement: Supplementary header

The system SHALL display an anime info header as an NSCollectionView supplementary header view.

#### Scenario: Header content

- **WHEN** detail data loads
- **THEN** the header SHALL display: cover image (100×120), anime title, rating score (main color, bold), favorite toggle button (Like/Unlike icon), on-air status ("连载中" or "已完结"), and tags (comma-separated, sorted by popularity)

#### Scenario: Favorite toggle in header

- **WHEN** user clicks the favorite button in the header
- **THEN** `FavoriteNetworkHandle.changeFavorite()` SHALL be called
- **AND** on success, the button state SHALL toggle between Like and Unlike

### Requirement: Episodes row

The system SHALL display a tappable row linking to the episode list.

#### Scenario: Tap episodes row

- **WHEN** user clicks the "分集详情" row
- **THEN** the navigator SHALL push a `BangumiDetailEpisodeViewController` with `detail.episodes` as data source

### Requirement: Related works section

The system SHALL display a horizontally scrolling section of related anime.

#### Scenario: Related works display

- **WHEN** `detail.relateds` is non-empty
- **THEN** a section titled "关联作品" SHALL display with horizontally scrolling anime items

#### Scenario: Tap related work

- **WHEN** user clicks a related anime item
- **THEN** the navigator SHALL push a new `BangumiDetailViewController` with the item's `animeId`

#### Scenario: Empty related works

- **WHEN** `detail.relateds` is empty
- **THEN** the related works section SHALL be hidden

### Requirement: Similar works section

The system SHALL display a horizontally scrolling section of similar anime.

#### Scenario: Similar works display

- **WHEN** `detail.similars` is non-empty
- **THEN** a section titled "相似作品" SHALL display with horizontally scrolling anime items

#### Scenario: Tap similar work

- **WHEN** user clicks a similar anime item
- **THEN** the navigator SHALL push a new `BangumiDetailViewController` with the item's `animeId`

### Requirement: Related and similar item cell

The system SHALL use a reusable cell for related/similar items, displaying cover image, title, rating, and favorite toggle.

#### Scenario: Favorite toggle on related/similar item

- **WHEN** user clicks the favorite button on a related or similar anime item
- **THEN** `FavoriteNetworkHandle.changeFavorite()` SHALL be called
- **AND** on success, the UI SHALL update accordingly
