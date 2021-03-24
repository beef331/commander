# Commander
Commander is a easy to use CLI documenter and parser.

## How to use
```nim
import commander
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
      c: int # Can use `float`, `int` or `string`
      count: int

writeFile("index.html", FancyProgram) # Outputs the Doc as a HTML file

if FancyProgramFlags[Help].isSome: # If the value was parsed it's `some`
  FancyProgram.print() # Prints the CLI documentation

if FancyProgramFlags[Count].isSome:
  if FancyProgramFlags[Count].get.kind == fkInt:
    for x in 0..<FancyProgramFlags[Count].get.intVal:
      echo "Hello World"
  else:
    for x in 0..<3: # Default value sorta.
      echo "Hello World"
```
The example's [html](https://www.jasonbeetham.com/commander/index.html)