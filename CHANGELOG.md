# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.0](https://github.com/zeeetech/ekko/compare/v0.1.0...v0.1.0) (2026-04-13)


### tests

* documentation, guides and property tests ([5dc7ef8](https://github.com/zeeetech/ekko/commit/5dc7ef80ce565ff7d251954699ea1c24feb009e4))


### Features

* audio player support ([b8ffcaa](https://github.com/zeeetech/ekko/commit/b8ffcaaac2fc705ae0cb5e40eaf7f4abdef23e1c))
* cert validators and plug implementation ([10073fb](https://github.com/zeeetech/ekko/commit/10073fbc149b661316bd03f91d6958ad1bcccc50))
* skill definition ([74dcc4a](https://github.com/zeeetech/ekko/commit/74dcc4a244533e889400388eab57e5f76aeec924))


### Continuous Integration

* config ([d8b17cf](https://github.com/zeeetech/ekko/commit/d8b17cfe4b1e5a1cad22b742295e7662de95d0a7))

## [0.1.0] - 2026-04-10

### Added

- `Ekko` — request context and response builder (speech, cards, directives, session control)
- `Ekko.Skill` — behaviour with `handle_request/2`, `before_request/1`, `after_request/2`, `handle_error/3` lifecycle
- `Ekko.Request` — parser for all Alexa request types:
  - `LaunchRequest`, `IntentRequest`, `SessionEndedRequest`
  - `AudioPlayer.PlaybackStarted/Finished/Stopped/NearlyFinished/Failed`
  - `PlaybackController.Play/Pause/Next/Previous/ResumeCommandIssued`
  - `System.ExceptionEncountered`
- `Ekko.Plug` — mountable Plug adapter with automatic request verification
- `Ekko.Verifier` — behaviour with `Default` (5-step Amazon verification pipeline) and `NoOp` implementations
- `Ekko.Crypto.CertCache` — ETS-backed certificate chain cache with configurable TTL
- `Ekko.Crypto.CertValidator` — URL structure and X.509 chain validation
- `Ekko.Crypto.SignatureVerifier` — RSA-SHA256 body signature verification
- `Ekko.AudioPlayer` — high-level helpers for building AudioPlayer responses from playlists
- `Ekko.AudioPlayer.Playlist` — pure-data playlist with cursor, shuffle, and loop support
- `Ekko.AudioPlayer.PlaylistStore` — behaviour for playlist persistence with default ETS adapter
- Response constraint enforcement — `AudioPlayer.*` and `PlaybackController.*` handlers cannot return `outputSpeech`, `card`, or `reprompt`
- `Ekko.Test.RequestFixtures` — decoded-JSON request fixtures for SDK consumers
