import unittest

import commander
import std/terminal
document(FancyProgram):
  header: "This program does some fancy thing." # At start of documentation
  footer: "Released under MIT license." # At end of documentation
  section Main:
    header: "Main Section:" # At start of section
    footer: "Cool stuff!" # At end of section
    Help: # This emits an enum value apart of `FancyProgramEnum.Help`
      flags:
        h
        help
      desc: "Prints this message"
    Count:
      desc: "Prints hellow world COUNT times."
      flags:
        c: int # Can use `float`, `int` or `string`
        count: int
    EnableColor:
      desc: "Enables terminal colour which makes the messages red."
      flags:
        color
        cc
