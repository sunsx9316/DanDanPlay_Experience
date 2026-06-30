## ADDED Requirements

### Requirement: Home page window display

The system SHALL display a home page window (600×800) containing an NSCollectionView with banner carousel, function grid, and bangumi queue sections.

#### Scenario: Window opens with home page content

- **WHEN** user opens the home page window from the menu
- **THEN** the window SHALL display at size 600×800 centered on screen
- **AND** the content SHALL be a vertically scrolling NSCollectionView with 3 sections

### Requirement: Banner carousel

The system SHALL display a horizontally paging banner carousel at the top of the home page using NSCollectionView.

#### Scenario: Banner displays items from API

- **WHEN** the home page data loads successfully
- **THEN** the banner section SHALL display items from `Homepage.banners`
- **AND** each item SHALL show its image (via Kingfisher), title, and description
- **AND** a UIPageControl-like indicator SHALL show the current page

#### Scenario: Banner auto-scrolls

- **WHEN** the banner is displayed with more than one item
- **THEN** the banner SHALL auto-scroll to the next item every 8 seconds
- **AND** scrolling past the last item SHALL wrap to the first

#### Scenario: Banner click opens URL

- **WHEN** user clicks on a banner item that has a URL
- **THEN** the system SHALL open the URL in the default browser

### Requirement: Function grid

The system SHALL display a function entry grid below the banner.

#### Scenario: Function items when logged out

- **WHEN** user is not logged in (`Preferences.shared.loginInfo == nil`)
- **THEN** the function section SHALL display only "新番时间表" item

#### Scenario: Function items when logged in

- **WHEN** user is logged in (`Preferences.shared.loginInfo != nil`)
- **THEN** the function section SHALL display both "新番时间表" and "我的关注" items

#### Scenario: Function grid refreshes on login state change

- **WHEN** a `AnixUserLoginStateDidChange` notification is received
- **THEN** the function section SHALL rebuild its data source and refresh display
- **AND** the home page data SHALL be re-fetched from the API

#### Scenario: Tap "新番时间表"

- **WHEN** user clicks the "新番时间表" function item
- **THEN** the navigator SHALL push a `TimelineViewController`

#### Scenario: Tap "我的关注"

- **WHEN** user clicks the "我的关注" function item
- **THEN** the navigator SHALL push a `FavoriteViewController`

### Requirement: Data fetching and refresh

The system SHALL fetch home page data from `HomePageNetworkHandle.homePage()` on initial load.

#### Scenario: Data loads successfully

- **WHEN** the home page data fetch succeeds
- **THEN** the NSCollectionView SHALL reload with banners, function items, and bangumi queue data
- **AND** if the fetch fails, an error message SHALL be displayed

### Requirement: Bangumi queue section

The system SHALL display a bangumi queue section (initially as a placeholder stub, matching iOS behavior).

#### Scenario: Queue section placeholder

- **WHEN** the home page is displayed
- **THEN** the bangumi queue section SHALL be rendered as a placeholder area
