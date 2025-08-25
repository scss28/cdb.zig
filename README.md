## Usage
Fetch with `zig fetch --save https://github.com/scss28/cdb.zig/archive/refs/tags/<version>.zig`.
```Rust
pub fn build(b: *std.Build) void {
    defer _ = @import("cdb").addStep(b, "cdb");

    // Rest of the build script...
}
```
Then run `zig build` and afterwards `zig build cdb`. The cdb step only combines produced cdb fragments into `compile_commands.json`.
