def _find_binary(ctx, binary_name):
    binary = ctx.which(binary_name)
    if binary == None:
        fail("Unable to find binary: {}".format(binary_name))
    return binary


def _ignore_opts(opts, ignore_opts):
    remain = []
    for opt in opts:
        if opt not in ignore_opts:
            remain.append(opt)
    return remain


def _symlinks(ctx, basename, srcpaths):
    result = []
    root = ctx.path("")
    base = root.get_child(basename)
    rootlen = len(str(base)) - len(basename)
    for i, src in enumerate([ctx.path(p) for p in srcpaths]):
        dest = base.get_child(str(i))

        ctx.symlink(src, dest)
        result.append(str(dest)[rootlen:])
    return result


def _extract_prefix(flags, prefix, strip = True):
    stripped, remain = [], []
    for arg in flags:
        if arg.startswith(prefix):
            if strip:
                stripped.append(arg[len(prefix):])
            else:
                stripped.append(arg)
        else:
            remain.append(arg)
    return stripped, remain


def _fmt_array(array):
    return ",".join(['"{}"'.format(a) for a in array])


def _fmt_glob(array):
    return _fmt_array(["{}/**/*.h".format(a) for a in array])


def _split(result, delimeter = " "):
    return [arg for arg in result.strip().split(delimeter) if arg]


def _execute(ctx, binary, args, environment = {}):
    result = ctx.execute([binary] + args, environment = environment)
    if result.return_code != 0:
        fail("Failed execute {} {} {} {}".format(binary, args, result.stderr, result.stdout))

    return result.stdout


def _pkg_config(ctx, pkg_config_path, pkg_name, args):
    pkg_config_binary_path = _find_binary(ctx, "pkg-config")
    environment = { "PKG_CONFIG_PATH": str(pkg_config_path) }
    return _execute(
        ctx,
        pkg_config_binary_path,
        [pkg_name] + args,
        environment = environment
    )


def _conan_execute(ctx, pkg_config_path, pkg_name, pkg_version, install_args):
    conan_binary_path = _find_binary(ctx, "conan")
    args = [ "install", "-g", "pkg_config", "-if", pkg_config_path, "{}/{}@".format(pkg_name, pkg_version) ]

    args += install_args

    _execute(
        ctx,
        conan_binary_path,
        args
    )


def _includes(ctx, pkg_config_path, pkg_name):
    includes = _split(_pkg_config(ctx, pkg_config_path, pkg_name, ["--cflags-only-I" ]))
    includes, _ = _extract_prefix(includes, "-I", strip = True)
    return includes


def _copts(ctx, pkg_config_path, pkg_name):
    return _split(_pkg_config(ctx, pkg_config_path, pkg_name, [ "--cflags-only-other", "--libs-only-L" ]))


def _linkopts(ctx, pkg_config_path, pkg_name):
    return _split(_pkg_config(ctx, pkg_config_path, pkg_name, [ "--libs-only-other" ]))


def _lib_dirs(ctx, pkg_config_path, pkg_name):
    deps = _split(_pkg_config(ctx, pkg_config_path, pkg_name, [ "--libs-only-L" ]))

    deps, _ = _extract_prefix(deps, "-L", strip = True)
    result = []

    for dep in {dep: True for dep in deps}.keys():
        base = "deps_" + dep.replace("/", "_").replace(".", "_")
        result += _symlinks(ctx, base, [dep])

    return result


def _conan_dep_impl(ctx):
    pkg_name = ctx.attr.name
    pkg_config_path = ctx.path(".")
    pkg_version = ctx.attr.version

    _conan_execute(ctx, pkg_config_path, pkg_name, pkg_version, ctx.attr.conan_install_args)

    # Make sure the package exist
    _pkg_config(ctx, pkg_config_path, pkg_name, ["--exists"])

    # Make sure we got the version required
    _pkg_config(ctx, pkg_config_path, pkg_name, ["--exact-version", pkg_version])

    ignore_opts = ctx.attr.ignore_opts

    copts = _copts(ctx, pkg_config_path, pkg_name)
    copts = _ignore_opts(copts, ignore_opts)

    linkopts = _linkopts(ctx, pkg_config_path, pkg_name)
    linkopts = _ignore_opts(linkopts, ignore_opts)

    includes = _includes(ctx, pkg_config_path, pkg_name)
    includes = _symlinks(ctx, "includes", includes)

    lib_dirs = _lib_dirs(ctx, pkg_config_path, pkg_name)

    ctx.template(
        "BUILD",
        Label("//:BUILD.tmpl"),
        substitutions = {
            "%{name}": ctx.attr.name,

            "%{pkg_name}": ctx.attr.name,

            "%{hdrs_glob}": _fmt_glob(includes),
            "%{includes}": _fmt_array(includes),

            "%{copts}": _fmt_array(copts),
            "%{linkopts}": _fmt_array(linkopts),
            "%{lib_dirs}": _fmt_array(lib_dirs),
        },
        executable = False
    )


conan_dep = repository_rule(
    attrs = {
        "conan_install_args": attr.string_list(default = [ "--build=missing" ], doc = "Arguments to append to the invocation to 'conan install'"),
        "version": attr.string(mandatory = True, doc = "Version number"),
        "ignore_opts": attr.string_list(doc = "Ignore listed opts in copts or linkopts."),
    },

    local = True,
    implementation = _conan_dep_impl,
)
