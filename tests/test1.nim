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

writeFile("index.html", FancyProgramDoc.toHtml) # Outputs the Doc as a HTML file

FancyProgramFlags.hasThen(Help, fkNone): # We only expect an empty value for help
  FancyProgramDoc.print() # Prints the CLI documentation

let
  hasColor = block:
    FancyProgramFlags.hasThenElse(EnableColor, fkNone):
      true  # Flag was included so must be true!
    do:
      false # Flag was missing so must be false!
  message =
    if hasColor:
      ansiForegroundColorCode(fgRed) & "Hello World" & ansiResetCode
    else:
      "Hello World"
  messageCount = block:
    FancyProgramFlags.hasThenElse(Count, fkInt):
      it    # It is injected by getting the value
    do:
      3
for x in 0..messageCount:
  echo message
