# bazel_conan_pkg_config

Bazel [**repository rule**](https://bazel.build/rules/repository_rules) for importing dependencies via conan with its pkg-config generator.

You must have [`conan`](https://conan.io) and [`pkg-config`](https://en.wikipedia.org/wiki/Pkg-config) installed on your host.

- [Installing conan](https://docs.conan.io/en/latest/installation.html)
- `pkg-config` can easily be installed with your system package manager

## Usage

Add the following in your `WORKSPACE`:

```bzl
http_archive(
    name = "bazel_conan_pkg_config",
    strip_prefix = "bazel_conan_pkg_config-main",
    urls = ["https://github.com/0x2Adr1/bazel_conan_pkg_config/archive/main.zip"],
)

load("@bazel_conan_pkg_config//:conan.bzl", "conan_dep")

# Declare your dependency with the conan_dep() rule
# e.g: Say you want to use openssl 3.0.3 in your project
conan_dep(
    name = "openssl",
    version = "3.0.3",


    # The default is to build from source for conan packages not available in
    # a binary form for your platform, i.e: conan install --build=missing

    # Note: Building a package relies on your host tools, so you will need
    # for instance to have cmake installed if a package is using cmake as
    # its build system and you build it from source

    # You can change this policy if needed with the option below, for example,
    # say you NEVER want to build a dependency from source:
    conan_install_args = [ "--build=never" ],
)
```

In your `BUILD` file:

```bzl
cc_binary(
    name = "my_exe",
    deps = [
        "@openssl//:lib",
    ],
)
```

## Credits

The pkg-config part was made possible thanks to:

- original pkg-config rule: https://github.com/cherrry/bazel_pkg_config
- PKG_CONFIG_PATH addition: https://github.com/nullpo-head/bazel_pkg_config
