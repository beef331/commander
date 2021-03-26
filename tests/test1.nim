import unittest
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
    name("Super Cool CLI")
    header("This is a great little program, that stands for great things")
    section("Otherly", "This part does some cooool stuff", "That was all the cool stuff it did")
    flag(short = "c", long = ["count", "countAlias"], desc = "Super fancy int math, totally rad.", typ = int):
      config.countTotal += it
    flag(long = "color", desc = "Chooses the colour to output in the terminal.",
        typ = ForegroundColor):
      case it
      of fgRed: discard
      else:
        config.color = it
        config.useColor = true
    flag(long = "help", desc = "Shows the help message."):
      let message =
        if config.useColor:
          ansiForegroundColorCode(config.color) & cmd.toCli & ansiResetCode
        else:
          cmd.toCli
      echo message
    flag(long = "bleep1", desc = "do bleep1", action = echo "bleep1")
    flag(long = "bleep2", desc = "do bleep2", action = echo "bleep2")
    footer("That's all")