## ADDED Requirements

### Requirement: Navigation window with toolbar

The system SHALL provide a reusable navigation window (`HomePageNavigationWindowController`) that manages a stack of view controllers and displays back/forward buttons in a toolbar.

#### Scenario: Push view controller

- **WHEN** a view controller calls `navigator.pushViewController(newVC)`
- **THEN** the new VC's view replaces the window's `contentViewController`
- **AND** back toolbar button becomes enabled
- **AND** window title updates to the new VC's title

#### Scenario: Pop view controller

- **WHEN** user clicks the back toolbar button
- **THEN** the current VC is removed from the navigation stack
- **AND** the previous VC's view becomes the window content
- **AND** back button becomes disabled if stack is at root

#### Scenario: Forward navigation

- **WHEN** user clicks the forward toolbar button (after having popped)
- **THEN** the previously popped VC is restored as content

#### Scenario: Toolbar button state at root

- **WHEN** the navigation stack has only one VC (the root)
- **THEN** both back and forward toolbar buttons SHALL be disabled

### Requirement: Navigation protocol for view controllers

The system SHALL define a `HomePageNavigation` protocol that view controllers use to request navigation.

#### Scenario: View controller accesses navigator

- **WHEN** a view controller conforms to the navigation protocol pattern (holding `weak var navigator: HomePageNavigation?`)
- **THEN** it SHALL be able to call `navigator?.pushViewController(_:)` to navigate forward
- **AND** the navigator SHALL be injected when the VC is first pushed

### Requirement: Menu integration

The system SHALL add a "主页" menu item to the app's main menu that opens the home page window.

#### Scenario: Open home page from menu

- **WHEN** user clicks "主页" in the menu bar
- **THEN** the home page window SHALL be created and shown at center of screen
- **AND** subsequent clicks SHALL bring the existing window to front rather than creating a new one
