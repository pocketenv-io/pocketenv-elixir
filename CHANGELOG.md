# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.1.7] - 2026-04-02

### Fixed
- Use `blake2` dependency for BLAKE2b-24 nonce derivation instead of `:crypto.hash/2`, fixing compatibility with macOS (LibreSSL) and ensuring the output matches libsodium's `crypto_box_seal` nonce exactly

## [0.1.6] - 2026-04-02

### Changed
- Use BLAKE2b-24 for nonce derivation during client-side encryption
- Align test environment values with application config

## [0.1.5] - 2026-04-02

### Added
- Secrets management: `Pocketenv.list_secrets/2`, `add_secret/4`, `delete_secret/2` and pipe-friendly `Sandbox.list_secrets/2`, `set_secret/4`, `delete_secret/3`
- SSH key management: `Pocketenv.get_ssh_keys/2`, `put_ssh_keys/4` and `Sandbox.get_ssh_keys/2`, `set_ssh_keys/4`
- Tailscale auth key management: `Pocketenv.get_tailscale_auth_key/2`, `put_tailscale_auth_key/3` and `Sandbox.get_tailscale_auth_key/2`, `set_tailscale_auth_key/3`
- `Sandbox.Types.Secret`, `Sandbox.Types.SshKey`, `Sandbox.Types.TailscaleAuthKey` structs
- Client-side encryption via libsodium sealed boxes (`crypto_box_seal`) using the `kcl` dependency; private keys and auth keys are encrypted with the server's public key before transmission
- Redacted values stored alongside encrypted secrets (SSH private key body masked, Tailscale key middle masked)
- Default server public key bundled so no configuration is required for the production API

## [0.1.4] - 2026-04-02

### Changed
- `:provider` option in `create_sandbox/2` now accepts atoms (`:cloudflare`, `:daytona`, `:deno`, `:vercel`, `:sprites`) instead of strings

## [0.1.3] - 2026-04-02

### Changed
- Updated OTP application config key from `:pocketenv` to `:pocketenv_ex`

## [0.1.2] - 2026-04-02

### Changed
- Renamed Hex package from `pocketenv` to `pocketenv_ex`

## [0.1.1] - 2026-04-01

### Added
- `source_url` and `homepage_url` in `mix.exs` for HexDocs integration
- `docs` configuration with `README.md` and `CHANGELOG.md` as extras

## [0.1.0] - 2026-04-01

### Added
- Initial Pocketenv Elixir SDK
- MIT License
- Package description in `mix.exs`

[0.1.7]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.6...v0.1.7
[0.1.6]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.5...v0.1.6
[0.1.5]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.4...v0.1.5
[0.1.4]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.3...v0.1.4
[0.1.3]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.2...v0.1.3
[0.1.2]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.1...v0.1.2
[0.1.1]: https://github.com/pocketenv-io/pocketenv-elixir/compare/v0.1.0...v0.1.1
[0.1.0]: https://github.com/pocketenv-io/pocketenv-elixir/releases/tag/v0.1.0
