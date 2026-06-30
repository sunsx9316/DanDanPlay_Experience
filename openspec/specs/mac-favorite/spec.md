## ADDED Requirements

### Requirement: Favorite list display

The system SHALL display a vertically scrolling NSCollectionView showing the user's favorited anime.

#### Scenario: Fetch favorites on load

- **WHEN** the favorite page is displayed
- **THEN** `FavoriteNetworkHandle.getFavoriteList()` SHALL be called
- **AND** on success, the NSCollectionView SHALL display the list of `UserFavoriteItem`

#### Scenario: Favorite item display

- **WHEN** favorites data is loaded
- **THEN** each item SHALL display: cover image (100×120), title, rating score, on-air status, favorite button, and last watch time

#### Scenario: Favorite item click

- **WHEN** user clicks a favorite item
- **THEN** the navigator SHALL push a `BangumiDetailViewController` initialized with the anime's `animeId`

#### Scenario: Unfavorite from list

- **WHEN** user clicks the favorite button on a favorite item
- **THEN** `FavoriteNetworkHandle.changeFavorite(animateId:, isLike: false)` SHALL be called
- **AND** on success, the item SHALL be removed from the list

### Requirement: Login state check

The system SHALL check login state when the favorite page appears.

#### Scenario: Not logged in

- **WHEN** the favorite page appears and `Preferences.shared.loginInfo == nil`
- **THEN** the page SHALL display a prompt to log in
- **AND** no API call SHALL be made

#### Scenario: Logged in

- **WHEN** the favorite page appears and `Preferences.shared.loginInfo != nil`
- **THEN** the page SHALL proceed to fetch favorites from the API
