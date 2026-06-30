## ADDED Requirements

### Requirement: Episode list display

The system SHALL display a list of episodes using NSTableView.

#### Scenario: Episode list loads

- **WHEN** `BangumiDetailEpisodeViewController` is pushed with `[BangumiEpisode]` data
- **THEN** an NSTableView SHALL display one row per episode
- **AND** each row SHALL show: episode title, episode number, last watched date (yyyy-MM-dd HH:mm:ss), and air date

#### Scenario: No further navigation

- **WHEN** user clicks an episode row
- **THEN** the row SHALL deselect without triggering any navigation (leaf page)
