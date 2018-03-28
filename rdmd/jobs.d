/**
Functionality responsible for determining the parameters
of an rdmd build job
*/
module rdmd.jobs;

import rdmd.args;

/**
Calculate the D compiler to be used for an rdmd build job

Params:
    args = parsed arguments settings

Returns:
    path to or name of the D compiler rdmd should invoke
*/
string rdmdCompiler(in RDMDArgs args)
{
    if (args.compiler.length > 0)
        return args.compiler;

    import rdmd.config : RDMDConfig;
    import std.file : exists, isFile, thisExePath;
    import std.path : buildPath, dirName;
    auto compilerPath =
        thisExePath().dirName.buildPath(RDMDConfig.defaultCompiler);

    import rdmd.filesystem : Filesystem;
    if (Filesystem.existsAsFile(compilerPath))
        return compilerPath;

    return RDMDConfig.defaultCompiler;
}

unittest
{
    RDMDArgs args;

    // if no compiler is set in `args`, the result is
    // context-dependent, but we can be sure that the
    // result ends with the default compiler name
    import std.algorithm.searching : endsWith;
    assert(args.rdmdCompiler.endsWith(RDMDConfig.defaultCompiler));

    // otherwise, we just get what is set in `args`
    args.compiler = "sdc";
    assert(args.rdmdCompiler == "sdc");
}


/**
Calculate the path to the temporary directory for an
rdmd build job

Params:
    args = parsed arguments settings

Returns:
    path to the temporary directory rdmd should use
*/
string rdmdTempDir(in RDMDArgs args)
out (result)
{
    import std.path : isValidPath;
    assert(result.isValidPath);
}
body
{
    import std.file : tempDir;
    import std.format : format;
    import std.path : buildPath;

    if (args.userTempDir.length > 0)
    {
        import std.exception : enforce;
        import std.path : isValidPath;
        enforce(args.userTempDir.isValidPath,
            "Specified tempdir is not a valid path: '%s'"
                .format(args.userTempDir));

        return args.userTempDir;
    }

    version (Posix)
    {
        import core.sys.posix.unistd : getuid;
        return buildPath(tempDir(), ".rdmd-%d".format(getuid()));
    }
    else
    {
        import std.array : replace;
        import std.path : dirSeparator;
        return tempDir().replace("/", dirSeparator).buildPath(".rdmd");
    }
}

unittest
{
    RDMDArgs args;

    // result is non-pure and context-dependent so we just
    // validate the basic logic: if args.userTempDir is set,
    // we get it back, otherwise we get back a different
    // but still valid directory
    assert(args.rdmdTempDir().isValidPath);

    args.userTempDir = "";
    assert(args.rdmdTempDir().isValidPath);

    args.userTempDir = " ";  // not a valid path
    import std.exception : assertThrown;
    assertThrown(args.rdmdTempDir());

    args.userTempDir = "mytmp";
    assert(args.rdmdTempDir() == "mytmp");
}
