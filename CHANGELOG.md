# Changelog
All notable changes to this project will be documented in this file.

## [0.0.11] - 2019-07-02
### Added
- Add option to disable the addon
- Add console.logAlways to log regardless of the user's logging settings
- Add message to tell user if the addon is disabled.

## [0.0.10] - 2019-07-02
### Changed
- Add checks to the code to make sure the frames have been created before using them.

## [0.0.9] - 2019-06-25
### Fixed
- Fixed a bug where the width of the main bar was not expanding to the edge of the screen because other addons were changing the UI Scale on initialization.
- Fixed various code formatting issues.

## [0.0.8] - 2019-06-25
### Fixed
- Fixed bug where total over time was displaying as zero
- AddOn is now combatible with patch 8.2

## [0.0.7] - 2019-06-24
### Added
- Ability to switch profiles in Menu > Interface > AddOns > DetailsHorizon > Profile.

## [0.0.6] - 2019-06-24
### Fixed
- Fixed issue with bar height introduced in 0.0.4 where bars were not centered when NOT using ElvUI.

## [0.0.5] - 2019-06-24
### Changed
- The default font is not Arial Narrow, and it is no longer initially incorrect because it's path was being stored instead of teh name of the font.
### Fixed
- Bars were not taking up the correct amount of the screen's width after 0.0.4 introduced a bug
- Details! is now a Required Dependency so new users are not greeted by a blank addon.
- Changed profile.addribute and profile.subattribute's default value to a number (in case the addon is ever initially loaded without Details!).

## [0.0.4] - 2019-06-24
### Fixed
- ElvUI changes the global UI scale in an invasive way to get pixel-perfect frames. Added code to prevent ElvUI from resizing the width of DetailsHorison's main background frame.
- Fix dependencies (Details is named "Details", not "Details! Damage Meter).

## [0.0.3] - 2019-06-23
### Added
- FiraCode-Medium font and license

### Fixed
- Font settings were being saved using a path to the font's location, they are now saved using the name of the font.

## [0.0.2] - 2019-06-23
### Added
- Option to show player's realms alongside their names in cross-realm groups.
- CHANGELOG.md Display changes.
- Optional Dependencies now include LibSharedMedia-3.0 and  Details!
### Changed
- By default, realm-names are hidden.

## [0.0.1] - 2019-06-22
### Added
- Added basic horizontal Details! display.
