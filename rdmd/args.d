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

/**
Callback to use with `getopt` to handle output options (`-o...` flags)

Parsed values will be used to determine the `outputFile`, `outputDir`
and `preserveOutputPaths` fields of the struct instance.

Params:
    option = name of the option flag received by `getopt`
             (should always be `"o"`)
    value = value provided with the `-o` flag
*/
    private void parseOutputArg(string option, string value)
    {
        parseOutputArgImpl(this.outputFile, this.outputDir,
                           this.preserveOutputPaths,
                           option, value);
    }
}

// test parseOutputArg method
unittest
{
    // the bulk of testing is done in `parseOutputArgImpl`, so we
    // just validate correct setting of fields
    RDMDArgs args;

    // `-od` flag results in `outputDir` being set
    args.parseOutputArg("o", "doyoulikeme");
    assert(args.outputDir == "oyoulikeme");
    assert(args.outputFile is null); // not modified
    assert(!args.preserveOutputPaths); // not modified

    // `-of` flag results in `outputFile` being set; let's
    // use `-of=` just to be different...
    args.parseOutputArg("o", "f=reallyyoudo");
    assert(args.outputDir == "oyoulikeme"); // not modified
    assert(args.outputFile == "reallyyoudo");
    assert(!args.preserveOutputPaths); // not modified

    // `-op` flag results in `preserveOutputPaths being set
    args.parseOutputArg("o", "p");
    assert(args.outputDir == "oyoulikeme"); // not modified
    assert(args.outputFile == "reallyyoudo"); // not modified
    assert(args.preserveOutputPaths);
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
Parses output options (`-o` flags) received via `getopt`, and writes
results into the provided output variables

Params:
    outputFile = string into which to write the path provided
                 with the `-of` flag (`value == "f..."`)
    outputDir = string into which to write the path provided
                with the `-od` flag (`value == "d..."`)
    preserveOutputPaths = bool into which to write `true` if
                          an `-op` flag was provided
                          (`value == "p"`)
    option = name of the option flag received by `getopt`
             (should always be `"o"`)
    value = value provided with the `-o` flag: supported
            choices are `"f..."`, `"d..."` and "p"
*/
private void parseOutputArgImpl(ref string outputFile, ref string outputDir,
                                ref bool preserveOutputPaths,
                                string option, string value)
{
    import std.exception: enforce;
    enforce(option == "o", "Invalid output option: -" ~ option ~ value);
    enforce(value.length > 0, "No value provided for -o option!");

    import std.algorithm.searching : skipOver;

    if (value.skipOver('f'))
    {
        // -ofmyfile passed
        enforce(!outputFile.ptr, "Error: more than one -of provided!");
        value.skipOver('='); // support -of... and -of=...
        outputFile = value;
    }
    else if (value.skipOver('d'))
    {
        // -odmydir passed
        enforce(!outputDir.ptr, "Error: more than one -od provided!");
        value.skipOver('='); // support -od... and -od=...
        outputDir = value;
    }
    else if (value == "-")
    {
        // -o- passed
        enforce(false, "Option -o- currently not supported by rdmd");
    }
    else if (value == "p")
    {
        // -op passed
        preserveOutputPaths = true;
    }
    else
    {
        enforce(false, "Unrecognized option: " ~ option ~ value);
    }
}

unittest
{
    string of, od;
    bool p;

    import std.exception : assertThrown;

    // unknown values will result in an exception
    assertThrown(parseOutputArgImpl(of, od, p, "o", null));
    assertThrown(parseOutputArgImpl(of, od, p, "o", "my"));

    // so too will the unsupported `-o-` option
    assertThrown(parseOutputArgImpl(of, od, p, "o", "-"));

    // validate that -o- and -op options require exact match
    assertThrown(parseOutputArgImpl(of, od, p, "o", "-foo"));
    assertThrown(parseOutputArgImpl(of, od, p, "o", "pbar"));

    // settings should not have been changed so far
    assert(of is null);
    assert(od is null);
    assert(!p);

    // `-op` will set the `preserve` parameter
    parseOutputArgImpl(of, od, p, "o", "p");
    assert(of is null); // not modified
    assert(od is null); // not modified
    assert(p);

    // ... and we can support arbitrarily many
    parseOutputArgImpl(of, od, p, "o", "p");
    assert(of is null); // not modified
    assert(od is null); // not modified
    assert(p);

    // `-od` flag will set the `od` parameter
    p = false;
    assert(!od.ptr);
    parseOutputArgImpl(of, od, p, "o", "dfranklymydir");
    assert(of is null); // not modified
    assert(od == "franklymydir");
    assert(!p); // not modified

    // ... but another `-od` flag will result in an exception
    assertThrown(parseOutputArgImpl(of, od, p, "o", "dfranklyidontcare"));
    assert(of is null); // not modified
    assert(od == "franklymydir"); // not modified
    assert(!p); // not modified

    // `-of` flag will set the `of` parameter
    assert(!of.ptr);
    parseOutputArgImpl(of, od, p, "o", "formaybethis");
    assert(of == "ormaybethis");
    assert(od == "franklymydir"); // not modified
    assert(!p); // not modified

    // ... but another `-of` flag will result in an exception
    assertThrown(parseOutputArgImpl(of, od, p, "o", "fortheloveof"));
    assert(of == "ormaybethis"); // not modified
    assert(od == "franklymydir"); // not modified
    assert(!p); // not modified

    // verify that `-of=` and `od=` are also supported
    string ofe, ode;
    parseOutputArgImpl(ofe, ode, p, "o", "d=anotherchoice");
    assert(ofe is null); // not modified
    assert(ode == "anotherchoice");
    assert(!p); // not modified

    parseOutputArgImpl(ofe, ode, p, "o", "f=oryetanother");
    assert(ofe == "oryetanother");
    assert(ode == "anotherchoice"); // not modified
    assert(!p); // not modified
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
