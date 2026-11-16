# Copyright 2024 The Bazel Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Create toolchain alias targets."""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("//python:versions.bzl", "PLATFORMS")

def toolchain_aliases(
        *,
        name,
        platforms,
        platform_compatible_with = None,
        platform_target_settings = None,
        visibility = None,
        native = native):
    """Create toolchain aliases for the python toolchains.

    Args:
        name: {type}`str` The name of the current repository.
        platforms: {type}`platforms` The list of platforms that are supported
            for the current toolchain repository.
        visibility: {type}`list[Target] | None` The visibility of the aliases.
        platform_compatible_with: Platform-to-constraint mappings.
        platform_target_settings: Platform-to-config-setting mappings.
        native: The native struct used in the macro, useful for testing.
    """
    if platform_compatible_with == None:
        platform_compatible_with = {p: PLATFORMS[p].compatible_with for p in platforms}
    if platform_target_settings == None:
        platform_target_settings = {p: PLATFORMS[p].target_settings for p in platforms}

    custom_platforms = [p for p in platforms if p not in PLATFORMS]
    if custom_platforms:
        # A custom runtime can match the same OS and CPU as a built-in one.
        # Its additional target_settings do not make its config_setting_group
        # more specialized than the built-in group in Bazel's select().
        # Exclude built-ins while a custom platform is selected.
        selects.config_setting_group(
            name = "_custom_override_active",
            match_any = [":" + p for p in custom_platforms],
            visibility = ["//visibility:private"],
        )
        selects.config_setting_group(
            name = "_always_true",
            match_all = ["//conditions:default"],
            visibility = ["//visibility:private"],
        )
        native.config_setting(
            name = "_linux_only",
            constraint_values = ["@platforms//os:linux"],
            visibility = ["//visibility:private"],
        )
        native.config_setting(
            name = "_windows_only",
            constraint_values = ["@platforms//os:windows"],
            visibility = ["//visibility:private"],
        )
        selects.config_setting_group(
            name = "_always_false",
            match_all = [":_linux_only", ":_windows_only"],
            visibility = ["//visibility:private"],
        )
        native.alias(
            name = "_no_custom_override",
            actual = select({
                ":_custom_override_active": ":_always_false",
                "//conditions:default": ":_always_true",
            }),
            visibility = ["//visibility:private"],
        )

    for platform in platforms:
        if platform not in platform_compatible_with or platform not in platform_target_settings:
            fail("Missing configuration for Python alias platform {}".format(platform))

        _platform = "_" + platform
        native.config_setting(
            name = _platform,
            constraint_values = platform_compatible_with[platform],
            visibility = ["//visibility:private"],
        )
        selects.config_setting_group(
            name = platform,
            match_all = (
                ([":_no_custom_override"] if custom_platforms and platform in PLATFORMS else []) +
                platform_target_settings[platform] + [_platform]
            ),
            visibility = ["//visibility:private"],
        )

    prefix = name
    for name in [
        "files",
        "includes",
        "libpython",
        "py3_runtime",
        "python_headers",
        "python_runtimes",
    ]:
        native.alias(
            name = name,
            actual = select({
                ":" + platform: "@{}_{}//:{}".format(prefix, platform, name)
                for platform in platforms
            }),
            visibility = visibility,
        )

    native.alias(
        name = "python3",
        actual = select({
            ":" + platform: "@{}_{}//:{}".format(prefix, platform, "python.exe" if "windows" in platform else "bin/python3")
            for platform in platforms
        }),
        visibility = visibility,
    )
    native.alias(
        name = "pip",
        actual = select({
            ":" + platform: "@{}_{}//:python_runtimes".format(prefix, platform)
            for platform in platforms
            if "windows" not in platform
        }),
        visibility = visibility,
    )
