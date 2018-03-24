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
Struct to hold parsed values from command-line arguments
*/
struct RDMDArgs
{
    bool buildOnly; /// --dry-run: only build programs, do not run
    bool chatty; /// --chatty: verbose output
    string compiler; /// --compiler: user-specified compiler to use
    string[] compilerFlags; /// flags to pass on directly to the D compiler
    bool dryRun; /// --dry-run: do not compile, just show what commands would run
    string[] eval; /// --eval: evaluate provided code as in `perl -e`
    string[] exclusions; /// --exclude: packages to exclude from the build
    string[] extraFiles; /// --extra-file: extra files to include in compilation
    bool force; /// --force: force a rebuild even if not necessary
    bool help; /// --help: output help text and exit
    string[] inclusions; /// --include: packages for which to override --exclude options
    string[] loop; /// --loop: evaluate provided code inside loop over stdin lines
    bool addStubMain; /// --main:
    bool makeDepend; /// --makedepend:
    string makeDepFile; /// --makedepfile:
    bool man; /// --man
    string outputFile; /// -of...: path of output file for the D compiler to write to
    string outputDir; /// -od...: path of output dir for the D compiler to write to
    string userTempDir; /// temporary directory to use instead of default
    bool preserveOutputPaths; /// -op: preserve source path for output files
    string program; /// path to source file of program rdmd is to build
    string[] programArgs; /// arguments to be passed to the program rdmd is building
}


/**
Find the index in an array of command-line arguments where
the program to compile is specified

Params:
    cliArgs = array of command-line arguments, stripped
              of any --shebang

Returns:
    index in `cliArgs` where the program to compile is
    specified, or `cliArgs.length` if none is present
*/
size_t indexOfProgram(string[] cliArgs)
{
    import std.exception : enforce;
    enforce(cliArgs.length > 0, "Command-line arguments are empty!");

    foreach(i; 1 .. cliArgs.length)
    {
        auto arg = cliArgs[i];
        assert(arg.length > 0);
        import std.algorithm.searching : endsWith, startsWith;
        if (!arg.startsWith('-', '@') &&
            !arg.endsWith(".obj", ".o", ".lib", ".a", ".def", ".map", ".res") &&
            cliArgs[i - 1] != "--eval")
        {
            return i;
        }
    }

    return cliArgs.length;
}

unittest
{
    import std.exception: assertThrown;
    assertThrown(indexOfProgram([]));

    string[] args = ["blah"];
    assert(indexOfProgram(args) == args.length);

    args = ["blah", "-who", "@what", "where.obj", "why.o",
            "are.a", "you.def", "sure.map", "about.res",
            "--this", "--eval", "something"];
    assert(indexOfProgram(args) == args.length);

    args ~= "thisProgram";
    assert(indexOfProgram(args) == args.length - 1);

    args ~= "--another-arg";
    assert(indexOfProgram(args) == args.length - 2);

    args ~= "anotherProgram";
    assert(indexOfProgram(args) == args.length - 3);
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
