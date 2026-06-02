# OpenModScan Mobile

Mobile version of the OpenModScan Modbus master/client utility.

## Features

- Save Modbus devices and register lists.
- Connect to Modbus TCP and Modbus RTU/IP devices.
- Read holding registers, input registers, coils, and discrete inputs.
- Write holding registers and coils when writes are enabled.
- Discover Modbus TCP and Modbus RTU/IP devices on the local network.
- Inspect captured Modbus traffic with decoded frame details.
- Export and import app settings and saved devices as a JSON backup.
- Support English and Russian UI localization.

## Protocol Support

- Supported: Modbus TCP, Modbus RTU/IP

## Getting Started

Install Flutter, then fetch dependencies:

```sh
flutter pub get
```

Run the app:

```sh
flutter run
```

Build release artifacts:

```sh
flutter build apk
flutter build ios
```

The iOS build requires Xcode and a configured Apple signing environment.

## Quality Checks

Run static analysis:

```sh
flutter analyze
```

Run tests:

```sh
flutter test
```

Run tests with coverage:

```sh
flutter test --coverage
```

The CI workflow enforces at least 80% line coverage from `coverage/lcov.info`.
Coverage output is a local artifact and is ignored by git.

## Notes

- Writes can be disabled in Settings.
- Multiple-register writes fall back to sequential single-register writes when
  a device rejects function code 16 with an illegal-function exception.
- Traffic file logging writes `modbus-traffic.log` in the app documents
  directory when enabled.
