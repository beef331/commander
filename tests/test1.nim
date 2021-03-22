import unittest

import commander
document(Commander):
  header: """
This is a test program, to showcase the usage of commander.
It allows quick generated documentation for CLI applications!"""
  footer: """
Code owned by Jason Beetham distributed under the MIT license,
and really sweet code."""
  section Main:
    header: "Some software made by Me!"
    Printer: 
      desc: "Amount of times to print a message."
      flags: 
        C: int
        count: int
    Help:
      desc: "Prints this message."
      flags:
        help
        h
    PretendGC:
      desc: "Chooses the GC read the docs for more."
      flags:
        gc: string
    footer:
      "This really is some silly stuff"
writeFile("index.html", CommanderDoc.toHtml)