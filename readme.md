# Commander
Commander is a easy to use CLI documenter and parser.

## How to use
```nim
import commander
import std/terminal
type Config = ref object
  useColor: bool
  color: ForegroundColor
  countTotal: int


let
  config = Config()
  cmd = initCommander()

genCommand(cmd):
  name("Super Cool CLI") # Gives a name to `cmd`
  header("This is a great little program, that stands for great things") # Gives the cmd a header
  section("Otherly", "This part does some cooool stuff", "That was all the cool stuff it did") # Makes a new section, with header, footer
  flag(short = "c", long = ["count", "countAlias"], desc = "Super fancy int math, totally rad.", typ = int): # Creates a new flag, short emits: `-c:C` long  emits: `--count:COUNT`
    config.countTotal += it # This is emited and is parsed from `typ`
  flag(long = "color", desc = "Chooses the colour to output in the terminal.",
      typ = ForegroundColor):
    case it  # This is emited and is parsed from `typ`
    of fgRed: discard
    else:
      config.color = it
      config.useColor = true
  flag(long = "help", desc = "Shows the help message."): # With no `typ` it's `-h` or `--help`
    let message =
      if config.useColor:
        ansiForegroundColorCode(config.color) & cmd.toCli & ansiResetCode
      else:
        cmd.toCli # Converts the doc to a cli help menu
    echo message
  flag(long = "bleep1", desc = "do bleep1", action = echo "bleep1") # Action can be same lined!
  flag(long = "bleep2", desc = "do bleep2", action = echo "bleep2") # Action can be same lined!
  footer("That's all") # Set's the cmd footer
writeFile("index.html", cmd) # Outputs the cli as html
```
The example's [html](https://www.jasonbeetham.com/commander/index.html)