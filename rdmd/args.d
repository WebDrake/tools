/**
Provides functionality for parsing command-line arguments and data
structures for storing the results
*/
module rdmd.args;

import rdmd.config : RDMDConfig;

/**
'Namespace' struct to encapsulate all global settings derived
from command-line arguments to `rdmd`
*/
struct RDMDGlobalArgs
{
  static:
    bool chatty;  /// verbose output
    bool buildOnly;  /// only build programs, do not run
    bool dryRun; /// do not compile, just show what commands would run
    bool force; /// force a rebuild even if not necessary
    bool preserveOutputPaths; /// preserve source path for output files

    string exe; /// output path for generated executable
    string userTempDir; /// temporary directory to use instead of default

    string[] exclusions = RDMDConfig.defaultExclusions; /// packages that are to be excluded
    string[] extraFiles = []; /// paths to extra source or object files to include

    string compiler = RDMDConfig.defaultCompiler; /// D compiler to use
}


/**
Strip the --shebang flag from command line arguments

Params:
    cliArgs = raw command-line arguments received by
              `main` function

Returns:
    `cliArgs` unchanged if no `--shebang` flag is present
    in index 1; otherwise, strips the `--shebang` flag
    itself and expands its arguments
*/
string[] stripShebang(string[] cliArgs)
{
    import std.algorithm.searching : startsWith;
    if (cliArgs.length > 1 && cliArgs[1].startsWith("--shebang ", "--shebang="))
    {
        // multiple options wrapped in one, we need to expand
        auto a = cliArgs[1]["--shebang ".length .. $];
        import std.array : split;
        return cliArgs[0 .. 1] ~ split(a) ~ cliArgs[2 .. $];
    }
    else
    {
        return cliArgs;
    }
}

unittest
{
    auto cliArgs = ["whatever", "you", "like", "it", "doesn't", "matter", "if",
                    "there", "is", "no", "shebang", "in", "index", "1"];

    assert(stripShebang(cliArgs.dup) == cliArgs); // dup just to be safe

    cliArgs = ["some-program", "--shebang followed by others", "and", "the", "rest"];
    auto expected = ["some-program", "followed", "by", "others", "and", "the", "rest"];

    // with --shebang in index 1 it will be stripped out
    assert(stripShebang(cliArgs.dup) == expected);
    // ... but not if it's in index 0
    assert(stripShebang(cliArgs[1 .. $].dup) == cliArgs[1 .. $]);

    // repeat with --shebang= to check that this works too
    cliArgs = ["some-program", "--shebang=followed by others", "and", "the", "rest"];
    assert(stripShebang(cliArgs.dup) == expected);
    assert(stripShebang(cliArgs[1 .. $].dup) == cliArgs[1 .. $]);
}
