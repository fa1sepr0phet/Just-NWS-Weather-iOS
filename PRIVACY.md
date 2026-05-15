# Privacy Policy for Just NWS Weather

_Last updated: May 15, 2026_

Just NWS Weather is designed to provide weather forecasts and alerts using United States National Weather Service data while collecting as little user information as possible.

## Summary

Just NWS Weather does not require an account, does not sell user data, does not show advertising, and does not include third-party analytics or tracking SDKs.

The app uses location or search information only to retrieve weather forecast and alert data.

## Information the App Uses

### Location

If you choose to use the current-location feature, the app asks iOS for permission to access your location while the app is in use.

The app uses your approximate device location to request weather data for your area. The app is configured to use reduced precision suitable for weather lookup rather than exact tracking.

You can deny location permission and still use the app by searching for a city or address.

You can change or revoke location permission at any time in iOS Settings.

### City or Address Searches

If you search for a city or address, the app uses that search to determine coordinates for weather lookup.

Address searches may be processed using Apple’s built-in MapKit geocoding services. City suggestions are generated from a local city list included with the app.

### Saved Locations

If you save a location, the app stores that saved location on your device. Saved location data may include:

- The label you entered
- The city or address display text
- Latitude and longitude
- City and state, when available

Saved locations are stored locally on your device using Apple’s local app storage system.

### Weather Data

The app retrieves forecast and alert data from the National Weather Service at:

- `https://api.weather.gov`

To retrieve weather data, the app sends coordinates to the National Weather Service API. These coordinates are used to determine the correct forecast office, grid point, forecast, and active weather alerts.

The National Weather Service may receive standard network information as part of normal internet traffic, such as your IP address and request details.

## Information Stored on Your Device

The app may store the following locally on your device:

- Saved locations
- Cached National Weather Service point metadata
- The most recent weather snapshot, including location name, coordinates, temperature, forecast summary, wind information, and update time

This local storage is used to improve the app experience and avoid unnecessary repeated lookups.

## Information Not Collected by the App Developer

Just NWS Weather does not collect, transmit to the developer, sell, rent, or share:

- Your name
- Your email address
- Your phone number
- Your contacts
- Your photos
- Your precise movement history
- Advertising identifiers
- Analytics events
- Crash analytics through a third-party SDK
- Payment information
- Account credentials

The app does not require user accounts.

## Third-Party Services

The app relies on the following external services:

### National Weather Service

The app uses the National Weather Service API to retrieve weather forecasts and alerts. Requests to the National Weather Service may include latitude and longitude for the selected location.

National Weather Service API:
`https://api.weather.gov`

### Apple Services

The app may use Apple system services, including Core Location and MapKit, for location permission, current-location lookup, and address geocoding.

Apple’s handling of data is governed by Apple’s privacy policies and system settings.

## Data Sharing

The app developer does not receive or share your personal data.

Weather and geocoding requests are sent directly from your device to the relevant service needed to provide the app’s functionality.

## Data Retention

Saved locations and cached weather-related data remain on your device unless you delete them in the app or remove the app from your device.

Deleting the app removes the app’s locally stored data from the device.

## Children’s Privacy

Just NWS Weather does not knowingly collect personal information from children. The app does not require accounts, advertising identifiers, or personal profiles.

## Open Source

Just NWS Weather is open source. Users and reviewers may inspect the source code to verify how the app works.

Repository:
`https://github.com/fa1sepr0phet/Just-NWS-Weather-iOS`

## Changes to This Policy

This privacy policy may be updated as the app changes. Material changes should be reflected in this file with an updated date.

## Contact

For questions or concerns, please use the GitHub repository issue tracker:

`https://github.com/fa1sepr0phet/Just-NWS-Weather-iOS/issues`
