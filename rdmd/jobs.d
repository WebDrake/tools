/**
Functionality responsible for determining the parameters
of an rdmd build job
*/
module rdmd.jobs;

import rdmd.args;

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
