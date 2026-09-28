# Lightweight Launch Argument Parser for Lua (lwlap.lua)

A small Lua library to parse command line arguments with minimal features. No type conversions, no boundary checks, no auto-generated help message. Only argument parsing into a nice table with some essential argument count check.

Minifiered with https://mothereff.in/lua-minifier

## Quick Start Guide

1. Copy the minifiered version of the library (`lwlap.min.lua`) into your project directory and rename it to `lwlap.lua`.

2. Import the library into your project and create a parser object:
```lua
lwlap = require("lwlap.min")
parser = lwlap.parser()
```
3. Set up the options and the positional arguments
```lua
-- Request an arbitrary number of positional arguments,
-- could be also set in the arguments for lwlap.parser()
parser:setnpos(0, math.huge)

-- Add the option --foo/-f with exactly one value
parser:option('foo', 'f', 1)
```

4. Parse the command line arguments from the global variable `arg`
```lua
-- The method parser:parse() returns two values. The first is a boolean flag that indicates
-- if parsing was successful, and the second is the parsed argument table or an error string.
local ok, arg_parsed = parser:parse(arg)
-- Check out the results with the debug function lwlap.print()
lwlap.print(ok, arg_parsed)
```

5. Wrap it with your own checks if it's neccessary
```lua
-- Throw a custom error on a non-number value of the '--foo' option
if ok and tonumber(arg_parsed.foo) == nil then
  ok, arg_parsed = false, "foo must be a number"
end
```

## Setting up options and positional arguments

By default, no positional arguments are taken, so you should call `parser:setnpos(min, max)` whenever
you need to take some. It checks that the number of arguments is not less than `min` nor greater than `max`. The upper limit is optional and equals to `min`, if you omit it.
The parsed positional arguments are stored in the result table under numerical indices, so you can 
treat it as a normal array. If you need a reliable way to access the number of positional arguments
 besides `#arg_parsed`, you can take it from `arg_parsed.n`.

Options can be set up using the `parser:option(long_key, short_key, min, max)` method.
It takes `long_key` as the root for the option's long key (which has the prefix `--`)
and `short_key` as the character for a shorter key. The latter is optional, as not every option
requires a short key. The option values can be accessed with the index of `long-key` after parsing.
The argument count boundaries are set much like as for the positional arguments. The value of `max`
determines the type of value stored in the option table:
```lua
parser:option('foo', nil, 0) -- arg_parsed.foo is filled with true on key presence (flag mode)
parser:option('bar', nil, 1) -- arg_parsed.bar is filled with a single string
parser:option('egg', nil, 2, 5) -- arg_parsed.egg is filled with a table (array) of 2 to 5 strings
```

## FAQ


### Where can I use this library?

Wherever you need a lightweight command-line argument parser *just* to correctly process them
in the way you like. It was made primary for small scripts and "fantasy" platforms like
[CraftOS-PC](https://www.craftos-pc.cc/), but I think it might be useful in more complex programs
and platforms.

### Can I use it in my commercial/closed-source project?

Yes, you can! The library is licensed under the MIT license, so its usage is basically unlimited.
Just remember to include the license text in your software. It also doesn't provide any kind
of warranty, so use it in critical workflows with a caution.

### How can I report a bug or contribute the project
You can use this repository to open an issue or send a pull request. We are welcome to new
contributors and ideas as long as they doesn't turn this library into a bloatware.
You are also free to fork it for your purposes or translate it into another programming language.

### Does it generate a help hint from the provided list of options?

No, this library does not provide this feature like Python's `argparse` or Rust's `clap` do.
If you need a help hint for your program, you can implement it yourself by adding the respective
option to the parser.

```lua
parser:option('help', 'h', 0)
ok, parsed_arg = parser:parse(arg)
if parsed_arg.help then
  -- Print help and exit
  print([[Here goes your help text]])
else
  -- Do the other stuff
end
```

### Can I define subcommands like in `clap`?

Officially, no. Subcommand argument style are currently unavailable in this library, but you can
try to implement it by analyzing the positional arguments. The problem is that some subcommands
may require defining and parsing exclusive command line options that are not available for
the other subcommands. This feature is hard to implement in the library's current workflow, as you
define the arguments *before* you parse them, and the parser cannot just skip the unrecognized keys
in hope it will get more information about them in the future.

Basicially, it is possible, but it requires *too many* workarounds to work in a reliable way. So, just look for a more advanced solution.

### Is it available in LuaRocks or any other package manager?

Currently, no. We will update this section if we have any news about it.
