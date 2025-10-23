# Version Information

## Current Versions

- **Zig Version**: 0.15.1+ (tested with 0.15.1 and 0.15.2)
- **PostgreSQL**: 18
- **Redis**: 8

## Zig Compatibility

This project is compatible with Zig 0.15.1 and later patch versions (0.15.2, etc.).

### Tested Zig Versions

| Version | Status | Notes |
|---------|--------|-------|
| 0.15.2  | ✅ Supported | Latest stable release |
| 0.15.1  | ✅ Supported | Current development version |
| 0.15.0  | ✅ Supported | Initial 0.15 release |
| 0.14.x  | ❌ Not supported | Breaking API changes |
| 0.13.x  | ❌ Not supported | Breaking API changes |

### Key Dependencies

The project uses native Zig packages with no C dependencies:

#### PostgreSQL Driver
- **Package**: [pg.zig](https://github.com/karlseguin/pg.zig)
- **Commit**: `c89b1c93307024f636b3c529ea2b10925683b8c6`
- **Features**: Native connection pooling, type-safe queries, automatic reconnection

#### Redis Client
- **Package**: [zig-okredis](https://github.com/kristoff-it/zig-okredis)
- **Commit**: `f53ad9f03a57d41d89b3ee779aaca608e1e4767f`
- **Features**: Zero-allocation design, type-safe commands, pure Zig implementation

## Breaking Changes from 0.13.x to 0.15.x

If you're migrating from Zig 0.13.x, see [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md) for detailed instructions.

### Major API Changes

1. **ArrayList** - Now unmanaged by default
   - Before: `var list = std.ArrayList(T).init(allocator);`
   - After: `var list: std.ArrayList(T) = .empty;` + pass allocator to methods

2. **String Splitting**
   - Before: `std.mem.split(u8, text, delimiter)`
   - After: `std.mem.splitSequence(u8, text, delimiter)`

3. **JSON Parsing**
   - Before: `std.json.Parser.init(allocator, .alloc_always)`
   - After: `std.json.parseFromSlice(std.json.Value, allocator, json_str, .{})`

4. **C Dependencies Removed**
   - Before: Required libpq and hiredis system libraries
   - After: Pure Zig implementation with pg.zig and zig-okredis

## Updating Zig

### macOS

```bash
# Using Homebrew (easiest)
brew upgrade zig

# Or download directly
curl -L https://ziglang.org/download/0.15.2/zig-macos-aarch64-0.15.2.tar.xz | tar -xJ
```

### Linux

```bash
# Download and extract
curl -L https://ziglang.org/download/0.15.2/zig-linux-x86_64-0.15.2.tar.xz | tar -xJ

# Move to system path
sudo mv zig-linux-x86_64-0.15.2 /usr/local/zig
sudo ln -sf /usr/local/zig/zig /usr/local/bin/zig
```

### Verify Installation

```bash
zig version
# Should output: 0.15.1 or 0.15.2
```

## Updating Dependencies

To update to the latest versions of pg.zig and zig-okredis:

```bash
# Update pg.zig
zig fetch --save git+https://github.com/karlseguin/pg.zig#master

# Update zig-okredis
zig fetch --save git+https://github.com/kristoff-it/zig-okredis#master

# Rebuild
zig build
```

## Compatibility Matrix

| Component | Minimum Version | Recommended Version | Notes |
|-----------|----------------|---------------------|-------|
| Zig | 0.15.0 | 0.15.2 | Use latest patch version |
| PostgreSQL | 12 | 18 | Tested with 18 |
| Redis | 6 | 8 | Tested with 8 |
| Docker | 20.10 | Latest | For containerized deployment |

## Known Issues

### Zig 0.15.1 Specific

- None currently known

### Zig 0.15.0 Specific

- Some minor JSON parsing edge cases (fixed in 0.15.1)

## Future Plans

- Monitor Zig 0.16.0 development for upcoming changes
- Update dependencies as new versions are released
- Maintain compatibility with latest stable Zig release

## Support

For version-specific issues:

1. Check [MIGRATION_GUIDE.md](MIGRATION_GUIDE.md)
2. Review [DEVELOPMENT.md](DEVELOPMENT.md)
3. Open an issue on GitHub

## Changelog

### 2025-01 - Current Release

- Updated to Zig 0.15.1+
- Migrated from libpq to pg.zig
- Migrated from hiredis to zig-okredis
- Removed all C dependencies
- Added comprehensive migration guide

---

**Last Updated**: January 2025
**Tested Zig Version**: 0.15.1
**Compatible Zig Versions**: 0.15.1, 0.15.2