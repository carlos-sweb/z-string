const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Get zregexp dependency
    const zregexp = b.dependency("zregexp", .{
        .target = target,
        .optimize = optimize,
    });
    const zregexp_module = zregexp.module("zregexp");

    // Create the zstring module with zregexp dependency
    const zstring_module = b.addModule("zstring", .{
        .root_source_file = b.path("src/zstring.zig"),
        .imports = &.{
            .{ .name = "zregexp", .module = zregexp_module },
        },
    });

    // Unit tests
    const lib_unit_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/zstring.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zregexp", .module = zregexp_module },
            },
        }),
    });

    const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // Spec compliance tests
    const spec_tests = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/spec/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_spec_tests = b.addRunArtifact(spec_tests);

    // Test step
    const test_step = b.step("test", "Run all tests");
    test_step.dependOn(&run_lib_unit_tests.step);
    test_step.dependOn(&run_spec_tests.step);

    // Benchmarks
    const bench = b.addExecutable(.{
        .name = "bench",
        .root_module = b.createModule(.{
            .root_source_file = b.path("tests/benchmarks/main.zig"),
            .target = target,
            .optimize = .ReleaseFast,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_bench = b.addRunArtifact(bench);
    const bench_step = b.step("bench", "Run benchmarks");
    bench_step.dependOn(&run_bench.step);

    // Examples
    const example_char_access = b.addExecutable(.{
        .name = "character_access",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/character_access.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_example = b.addRunArtifact(example_char_access);
    const example_step = b.step("example", "Run character access example");
    example_step.dependOn(&run_example.step);

    // Search methods example
    const example_search = b.addExecutable(.{
        .name = "search_methods",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/search_methods.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_search_example = b.addRunArtifact(example_search);
    const search_example_step = b.step("example-search", "Run search methods example");
    search_example_step.dependOn(&run_search_example.step);

    // Transform methods example
    const example_transform = b.addExecutable(.{
        .name = "transform_methods",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/transform_methods.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_transform_example = b.addRunArtifact(example_transform);
    const transform_example_step = b.step("example-transform", "Run transform methods example");
    transform_example_step.dependOn(&run_transform_example.step);

    // Padding & Trimming methods example
    const example_padding_trimming = b.addExecutable(.{
        .name = "padding_trimming_methods",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/padding_trimming_methods.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_padding_trimming_example = b.addRunArtifact(example_padding_trimming);
    const padding_trimming_example_step = b.step("example-padding-trimming", "Run padding and trimming methods example");
    padding_trimming_example_step.dependOn(&run_padding_trimming_example.step);

    // Split method example
    const example_split = b.addExecutable(.{
        .name = "split_method",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/split_method.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_split_example = b.addRunArtifact(example_split);
    const split_example_step = b.step("example-split", "Run split method example");
    split_example_step.dependOn(&run_split_example.step);

    // Error handling example
    const example_error_handling = b.addExecutable(.{
        .name = "error_handling",
        .root_module = b.createModule(.{
            .root_source_file = b.path("examples/error_handling.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "zstring", .module = zstring_module },
            },
        }),
    });

    const run_error_handling_example = b.addRunArtifact(example_error_handling);
    const error_handling_example_step = b.step("example-errors", "Run error handling example");
    error_handling_example_step.dependOn(&run_error_handling_example.step);
}
