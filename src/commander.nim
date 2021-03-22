import std/[macros, strutils, htmlgen, parseopt, options]
export parseopt, strutils, options

type
  DocEntry* = object
    name*, description*: string
    flags*: seq[string]
  DocSection* = object
    name*, header*, footer*: string # Appended before and after documentation
    entries*: seq[DocEntry]
  CommandDoc* = object
    name*, header*, footer*: string
    sections*: seq[DocSection]
  FlagKind* = enum
    fkNone, fkString, fkFloat, fkInt

  FlagValue* = object
    case kind*: FlagKind
    of fkString:
      strVal*: string
    of fkFloat:
      floatVal*: float
    of fkInt:
      intVal*: int
    else: discard

proc print*(doc: DocSection) = 
  echo doc.header
  var largestWidth = 0
  for entry in doc.entries: # Calculates the largest width for aligning
    var width = 0
    for flag in entry.flags:
      width += flag.len + 1
    largestWidth = max(largestWidth, width + 1)
  
  for entry in doc.entries:
    var msg = ""
    for flag in entry.flags:
      msg.add flag & " "
    stdout.write msg.alignLeft(largestWidth)
    echo entry.description
  echo doc.footer

proc print*(doc: CommandDoc) = 
  echo doc.name
  echo doc.header
  for section in doc.sections:
    section.print()
  echo doc.footer

func toHtml*(sect: DocSection): string =
  result.add h1(a(href = ("#" & sect.name), sect.name))
  result.add p(sect.header)
  var trs: string
  for entry in sect.entries:
    let 
      flags = entry.flags.join(" ")
      linkName = "#" & sect.name & entry.name
    trs.add tr(td(a(href = linkName, flags)), td(entry.description))
  result.add table(trs)
  result.add p(sect.footer)

func toHtml*(doc: CommandDoc): string =
  result.add h1(doc.name)
  result.add p(doc.header)
  for sect in doc.sections:
    result.add sect.toHtml
  result.add p(doc.footer)

func `[]`(doc: CommandDoc, str: string): DocSection = 
  for sect in doc.sections:
    if sect.name == str:
      return sect
  raise newException(KeyError, "Key not found.")

proc getKindParser(i: NimNode): (FlagKind, NimNode) = 
  if i.eqIdent("string"):
    (fkString, newEmptyNode())
  elif i.eqIdent("int"):
    (fkInt, ident("parseInt"))
  elif i.eqIdent("float"):
    (fkFloat, ident("parseFloat"))
  else:
    error("This DSL only accepts `int`, `float` or `strings`.")
    (fkNone, newEmptyNode())

proc toFlag(s: string): string = 
  result = 
    if s.len == 1: 
      "-" 
    else: "--"
  result.add s


macro document*(constName: untyped, body: untyped): untyped =
  var 
    doc = CommandDoc(name: $constName)
    enumNames: seq[NimNode]
    searchBody = newStmtList()
  let
    pIdent = ident("p")
    resIdent = ident("res")
    enumName = ident($constName & "Enum")
  for section in body:
    if section[0].eqIdent("header"): # Found the doc header
        doc.header = $section[1][0]
        continue
    elif section[0].eqIdent("footer"): # Found the doc footer
        doc.footer = $section[1][0]
        continue
    var docSect: DocSection
    docSect.name = $section[1] # The enum is the section name
    for entry in section[2]:
      if entry[0].eqIdent("header"): # Found the section header
        docSect.header = $entry[1][0]
      elif entry[0].eqIdent("footer"): # Found the section footer
        docSect.footer = $entry[1][0]
      else:
        let name = entry[0]
        enumNames.add name
        var
          flags: seq[string]
          desc: string
        assert entry[1].len == 2
        for field in entry[1]:
          if field[0].eqIdent("flags"):
            for flag in field[1]: # Gets all flags and adds logic to search/parse them to the array
              if flag.len > 0:
                let
                  flagName = $flag[0]
                  (flagType, flagParser) = getKindParser(flag[1][0])
                  flagTypeLit = flagType.newLit
                flags.add flagName.toFlag & "=" & (flagName).toUpperAscii
                case flagType:
                of fkString:
                  searchBody.add quote do:
                    if `pIdent`.key.nimIdentNormalize == `flagName`.nimIdentNormalize:
                      if `pident`.val.len > 0:
                          let strVal = `pident`.val
                          `resIdent`[`name`] = FlagValue(kind: `flagTypeLit`, strVal: strVal).some
                of fkInt:
                  searchBody.add quote do:
                    if `pIdent`.key.nimIdentNormalize == `flagName`.nimIdentNormalize:
                      if `pident`.val.len > 0:
                        try:
                          let intVal = `pIdent`.val.`flagParser`
                          `resIdent`[`name`] = FlagValue(kind: `flagTypeLit`, intVal: intVal).some
                        except: discard
                of fkFloat:
                  searchBody.add quote do:
                    if `pIdent`.key.nimIdentNormalize == `flagName`.nimIdentNormalize:
                        try:
                          let floatVal = `pIdent`.val.`flagParser`
                          `resIdent`[`name`] = FlagValue(kind: `flagTypeLit`, floatVal: floatVal).some
                        except: discard
                else: discard
              else:
                let 
                  flagName = $flag
                flags.add flagName.toFlag
                searchbody.add quote do:
                  if `pident`.key.nimIdentNormalize == `flagName`.nimIdentNormalize:
                    `resIdent`[`name`] = FlagValue(kind: fkNone).some

          if field[0].eqIdent("desc"): # Found the section description
            desc = $field[1][0]
        assert flags.len != 0 and desc.len != 0
        docSect.entries.add DocEntry(name: $name, flags: flags, description: desc)
    doc.sections.add(docSect)
  let 
    theConst = doc.newLit
    flags = ident($constName & "Flags")
    constName = ident($constName & "Doc")
  result = nnkStmtList.newTree newEnum(enumName, enumNames, true, true)
  result.add quote do:
    const `constName`* = `theConst`
    let `flags` = block:
      var
        `resIdent`: array[`enumName`, Option[FlagValue]]
        `pIdent` = initOptParser()
      while true:
        `pIdent`.next
        `searchBody`
        if `pIdent`.kind == cmdEnd:
          break
      `resIdent`