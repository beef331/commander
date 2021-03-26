import std/[macros, strutils, htmlgen, parseopt, tables, terminal, strformat, sequtils]
export parseopt, strutils

type
  DocEntry = object
    description: string
    hasValue: bool
    shortFlags, longFlags: seq[string]

  DocSection = object
    header, footer: string # Appended before and after documentation
    entries: seq[DocEntry]

  Commander = object
    name, header, footer, currentSection: string
    sections: OrderedTable[string, DocSection]

  Param = object
    kind: CmdlineKind
    key, val: string


proc parse(str: string, T: typedesc): T =
  when T is SomeInteger:
    parseInt(str).T
  elif T is SomeFloat:
    parseFloat(str).T
  elif T is enum:
    parseEnum[T](str)

proc initCommander*(): Commander =
  result.currentSection = "main"
  result.sections[result.currentSection] = DocSection()

template flag*(cmd: Commander, short, long: openArray[string] = [], desc: string = "",
    typ: type = void, action: untyped) =
  let
    isLong = long.len > 0
    isShort = short.len > 0
    hasValue = typ isnot void
  cmd.unsafeAddr[].sections[cmd.currentSection].entries.add DocEntry(description: desc,
      shortFlags: toSeq(short), longFlags: toSeq(long), hasValue: hasValue)
  for flag in short:
    if parseTable.hasKey(flag):
      let param = parseTable[flag]
      if param.kind == cmdShortOption and isShort:
        when typ isnot void and typ isnot string:
          let it{.inject.} = parse(param.val, typ)
        elif typ is string:
          let it{.inject.} = val
        action
  for flag in long:
    if parseTable.hasKey(flag):
      let param = parseTable[flag]
      if param.kind == cmdLongOption and isLong:
        when typ isnot void and typ isnot string:
          let it{.inject.} = parse(param.val, typ)
        elif typ is string:
          let it{.inject.} = val
        action


proc header*(cmd: Commander, desc: string) {.inline.} = cmd.unsafeAddr[].header = desc

proc footer*(cmd: Commander, desc: string) {.inline.} = cmd.unsafeAddr[].footer = desc


proc header*(cmd: Commander, section, desc: string) {.inline.} =
  if cmd.sections.hasKey(section):
    cmd.unsafeAddr[].sections[section].header = desc

proc footer*(cmd: Commander, section, desc: string) {.inline.} =
  if cmd.sections.hasKey(section):
    cmd.unsafeAddr[].sections[section].footer = desc

proc section*(cmd: Commander, newSect, header, footer: string = "") =
  # When empty returns to "main"
  cmd.unsafeAddr[].currentSection =
    if newSect.len == 0:
      "main"
    else:
      discard cmd.unsafeaddr[].sections.hasKeyorPut(newSect, DocSection())
      cmd.unsafeaddr[].sections[newSect].header = header
      cmd.unsafeaddr[].sections[newSect].footer = footer
      newSect

proc addCommander(node, cmderIdent: Nimnode) =
  node.insert 1, nnkExprEqExpr.newTree(ident("cmd"), cmderIdent)

proc expandFlag(node: NimNode) =
  var foundOptSymbols = {"short": false, "long": false, "desc": false, "typ": false}.toTable
  for expr in node:
    if expr.kind == nnkExprEqExpr:
      foundOptSymbols[($expr[0]).nimIdentNormalize] = true
      if expr[1].kind == nnkStrLit and (expr[0].eqIdent("short") or expr[0].eqIdent("long")):
        expr[1] = nnkBracket.newNimNode.add(expr[1])
  for (key, value) in foundOptSymbols.pairs:
    if not value:
      let lit =
        case key:
        of "typ":
          quote do:
            typedesc[void]
        of "desc":
          newLit("")
        else:
          newLit(newSeq[string](0))
      node.insert 1, nnkExprEqExpr.newTree(ident(key), lit)

macro genCommand*(cmdr: Commander, body: untyped): untyped =
  result = body
  for call in result:
    case $call[0]:
    of "flag":
      call.expandFlag
      call.addCommander(cmdr)
    of "section", "header", "footer":
      call.addCommander(cmdr)
  let pTable = ident"parseTable"
  result.insert 0, quote do:
    var
      `pTable`: Table[string, Param]
      parser = initOptParser()
    for kind, key, val in parser.getOpt():
      `pTable`[key] = Param(kind: kind, key: key, val: val)
  result = newBlockStmt(result)

proc newLined(s: string): string {.inline.} = s & "\n"

proc toFlag(s: string): string {.inline.} =
  if s.len == 1:
    fmt"-{s} "
  else:
    fmt"--{s} "

proc toValue(s: string, valSep = '='): string {.inline.} =
  if s.len == 1:
    fmt"-{s}{valSep}{s.toUpperAscii} "
  else:
    fmt"--{s}{valSep}{s.toUpperAscii} "

proc toCli*(docSect: DocSection, valsep = '='): string =
  if docSect.header.len > 0:
    result.add docSect.header.newLined
  var
    longest = 0
    messages: seq[string]
  for ent in docSect.entries:
    var message = ""
    for flag in ent.shortFlags:
      if ent.hasValue:
        message.add flag.toValue
      else:
        message.add flag.toFlag
    for flag in ent.longFlags:
      if ent.hasValue:
        message.add flag.toValue
      else:
        message.add flag.toFlag
    longest = max(longest, message.len + 1)
    messages.add message
  for i, msg in messages:
    result.add msg.alignLeft(longest) & docSect.entries[i].description.newLined

  if docSect.footer.len > 0:
    result.add docSect.footer.newLined

proc toCli*(cmdr: Commander, valSep = '='): string =
  result.add cmdr.name.newLined
  result.add cmdr.header.newLined
  if cmdr.sections.hasKey("main"):
    result.add cmdr.sections["main"].toCli(valSep)
  for key in cmdr.sections.keys:
    if key != "main":
      result.add cmdr.sections[key].toCli(valSep)
  result.add cmdr.footer.newLined

when isMainModule:
  import std/terminal
  type Config = ref object
    useColor: bool
    color: ForegroundColor
    countTotal: int


  let
    config = Config()
    cmd = initCommander()

  genCommand(cmd):
    header("This is a great little program, that stands for great things")
    section("Otherly", "This part does some cooool stuff", "That was all the cool stuff it did")
    flag(short = "c", long = ["count", "countAlias"], desc = "Super fancy int math, totally rad.", typ = int):
      config.countTotal += it # `it` is converted from input flag value to the provided `typ` (`int` in this case)
    flag(long = "color", desc = "Chooses the colour to output in the terminal.",
        typ = ForegroundColor):
      case it
      of fgRed: discard
      else:
        config.color = it
        config.useColor = true
    flag(long = "help", desc = "Shows this message."):
      let message =
        if config.useColor:
          ansiForegroundColorCode(config.color) & cmd.toCli & ansiResetCode
        else:
          cmd.toCli
      echo message
    flag(long = "bleep1", desc = "do bleep1", action = echo "bleep1")
    flag(long = "bleep2", desc = "do bleep2", action = echo "bleep2")
    footer("That's all")
