import std/[macros, strutils, htmlgen, parseopt, tables, terminal, strformat, sequtils]
export parseopt, strutils

type
  DocEntry = object
    description: string
    hasValue: bool
    case isArgument: bool
    of true:
      argument: string
    else:
      shortFlags, longFlags: seq[string]


  DocSection = object
    name, header, footer: string # Appended before and after documentation
    entries: seq[DocEntry]

  Commander* = object
    name, header, footer, currentSection: string
    sections: OrderedTable[string, DocSection]
    argumentPos: int

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
  result.currentSection = "Main"
  result.sections[result.currentSection] = DocSection()

template flag*(cmd: Commander, short, long: openArray[string] = [], desc: string = "",
    typ: type = void, action: untyped) =
  let
    isLong = long.len > 0
    isShort = short.len > 0
    hasValue = typ isnot void
  cmd.sections[cmd.currentSection].entries.add DocEntry(description: desc,
      shortFlags: toSeq(short), longFlags: toSeq(long), hasValue: hasValue, isArgument: false)
  for flag in short:
    if parseTable.hasKey(flag):
      let param = parseTable[flag]
      if param.kind == cmdShortOption and isShort:
        when typ isnot void and typ isnot string:
          let it{.inject.} = parse(param.val, typ)
        elif typ is string:
          let it{.inject.} = param.val
        action
  for flag in long:
    if parseTable.hasKey(flag):
      let param = parseTable[flag]
      if param.kind == cmdLongOption and isLong:
        when typ isnot void and typ isnot string:
          let it{.inject.} = parse(param.val, typ)
        elif typ is string:
          let it{.inject.} = param.val
        action

template arg*(cmd: Commander, name: string, desc: string = "", pos: int, typ = void, onGet: untyped) =
  cmd.sections[cmd.currentSection].entries.add(DocEntry(description: desc, isArgument: true, argument: name))
  block search:
    var found = 0
    for x, y in parsetable.pairs:
      if y.kind == cmdArgument:
        if found == pos:
          when typ isnot void and typ isnot string:
            let it{.inject.} = parse(y.key, typ)
          elif typ is string:
            let it{.inject.} = y.key
          `onGet`
        inc found



proc header*(cmd: var Commander, desc: string) {.inline.} = cmd.header = desc

proc footer*(cmd: var Commander, desc: string) {.inline.} = cmd.footer = desc
proc name*(cmd: var Commander, name: string) {.inline.} = cmd.name = name


proc header*(cmd: var Commander, section, desc: string) {.inline.} =
  if cmd.sections.hasKey(section):
    cmd.sections[section].header = desc

proc footer*(cmd: var Commander, section, desc: string) {.inline.} =
  if cmd.sections.hasKey(section):
    cmd.sections[section].footer = desc

proc section*(cmd: var Commander, newSect, header, footer: string = "") =
  ## When `newSect` is empty returns to "Main"
  cmd.currentSection =
    if newSect.len == 0:
      "Main"
    else:
      discard cmd.sections.hasKeyorPut(newSect, DocSection(name: newSect))
      if header.len > 0: cmd.sections[newSect].header = header
      if footer.len > 0: cmd.sections[newSect].footer = footer
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
  let cmd = ident($cmdr)
  for call in result:
    case $call[0]:
    of "flag":
      call.expandFlag
      call.addCommander(cmd)
    of "section", "header", "footer", "name", "arg":
      call.addCommander(cmd)
  let pTable = ident"parseTable"
  result.insert 0, quote do:
    var
      `cmd` = `cmdr`
      `pTable`: Table[string, Param]
      parser = initOptParser()
    for kind, key, val in parser.getOpt():
      `pTable`[key] = Param(kind: kind, key: key, val: val)
  result.add quote do:
    `cmdr`.unsafeAddr[] = `cmd`
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
  if docSect.name != "Main":
    result.add docSect.name.newLined
  if docSect.header.len > 0:
    result.add docSect.header.newLined
  var
    longest = 0
    messages: seq[string]
  for ent in docSect.entries:
    var message = ""
    for flag in ent.shortFlags:
      if ent.hasValue:
        message.add flag.toValue valSep
      else:
        message.add flag.toFlag
    for flag in ent.longFlags:
      if ent.hasValue:
        message.add flag.toValue valSep
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
  if cmdr.sections.hasKey("Main"):
    result.add cmdr.sections["Main"].toCli(valSep).newLined
  for key in cmdr.sections.keys:
    if key != "Main":
      result.add cmdr.sections[key].toCli(valSep).newLined
  result.add cmdr.footer.newLined


proc toHtml(entry: DocEntry, valSep = '='): string =
  var message = ""
  for flag in entry.shortFlags:
    if entry.hasValue:
      message.add flag.toValue valSep
    else:
      message.add flag.toFlag
  for flag in entry.longFlags:
    if entry.hasValue:
      message.add flag.toValue valSep
    else:
      message.add flag.toFlag
  let tag = fmt"#{entry.longFlags.join}{entry.shortFlags.join}"
  result.add tr(td(a(href = tag, message)), td(entry.description))


proc toHtml(sect: DocSection, valSep = '='): string =
  result.add h2(a(href = "#" & sect.name, sect.name))
  result.add p(sect.header)
  var tableVals = ""
  for ent in sect.entries:
    tableVals.add ent.toHtml valSep
  result.add table(tableVals)
  result.add p(sect.footer)


proc toHtml*(cmdr: Commander, valSep = '='): string =
  result.add h1(cmdr.name)
  result.add p(cmdr.header)
  if cmdr.sections.hasKey("Main"):
    result.add cmdr.sections["Main"].toHtml(valSep)
  for key in cmdr.sections.keys:
    if key != "Main":
      result.add cmdr.sections[key].toHtml(valSep)
  result.add p(cmdr.footer)

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
  writeFile("index.html", cmd.toHtml)
