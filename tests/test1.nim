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
  flag(short = "c", long = ["count", "countAlias"], desc = "some description", typ = int):
    config.countTotal += it # `it` is converted from input flag value to the provided `typ` (`int` in this case)
  flag(long = "color", desc = "some description", typ = ForegroundColor):
    case it
    of fgRed: discard
    else:
      config.color = it
      config.useColor = true
  flag(long = "help", desc = "shows help"):
    echo "Help"
  flag(long = "bleep1", desc = "do bleep1", action = echo "bleep1")
  flag(long = "bleep2", desc = "do bleep2", action = echo "bleep2")
