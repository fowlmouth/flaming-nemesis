import 
  backend, 
  fowltek/maybe_t, fowltek/boundingbox,
  signals, 
  tables, strutils, json, unsigned, basic2d,
  os
import_backends

discard """
functions for loading the gui from json

"""

proc p* [T] (some:T):T{.inline.}=
  echo some
  some

type 
  TValidator = object
    typeChecker:proc(W:PWidget):bool
    importer:proc(J:PJsonNode;S:ImportState):PWidget
  
  TWidgetControllers* = object
    # TODO make these take w:PWidget and be bound to the corresponding signal
    onClick*: TTable[string,proc(){.closure.}]
    textEntered*: TTable[string,proc(text:string){.closure.}]
    lostFocus*: TTable[string,proc(){.closure.}]
    gainedFocus*: TTable[string,proc(){.closure.}]
  ImportState* = ref object
    named*: TTable[string,PWidget]
    defaultStyle*: TStyle
    ctrls*: TWidgetControllers
    env*: TTable[string,TValidator]

proc widgetControllers* (
    onClick: openarray[tuple[key:string, val:proc()]],
    textEntered: openarray[tuple[key:string, val:proc(text:string)]] ): TWidgetControllers =
  result.onClick = onClick.toTable
  result.textEntered = textEntered.toTable

let defaultController* = widgetControllers([],[]) 

proc importGui* (J:PJsonNode; s: importstate): PWidget 

proc importContainer (J:PJsonNode; s: importstate): PWidget =
  #let
  result = container()
  if j.hasKey("widgets"):
    let ws = j["widgets"]
    assert ws.kind == jArray
    for it in ws.items:
      let w = it.importGUI(s)
      if not w.isNil:
        result.PContainer.add w

proc importWindow* (J:PJsonNode; s:importstate): PWidget =
  let title = j["title"].str
  let r = algui.PWindow(windowWidget(title))
  r.title.style = s.defaultStyle
  
  if j.hasKey"child":
    r.setChild j["child"].importGUI(s)
  
  
  result = r

proc findOnclick (s: importState; cnt:PJsonNode): TMaybe[proc()] =
  if cnt.kind == jString:
    let name = cnt.str
    result = maybe(s.ctrls.onClick[name])
    if not result.has:
      echo "not find controller: ", name

proc findTextEntered (s:importState; cnt:PJsonNode): TMaybe[proc(text:string)] =
  if cnt.kind == jString:
    let name = cnt.str
    result = maybe(s.ctrls.textEntered[name])
    if not result.has:
      echo "Could not find controller: ", name

proc importTextLabel* (J:PJsonNode; s:importstate): PWidget =
  let text = j["text"].str
  result = textLabel(text)
  
  var onClick: PJsonNode
  if j.hasKey"controller":
    onClick = j["controller"]
  elif j.hasKey"on-click":
    onClick = j["on-click"]
  else:
    return
  
  if (let (has,c) = s.findOnclick(onClick); has):
    result.onClick.connect c
  else:
    echo "no find controller ", onClick

proc importVBox* (J:PJsonNode; s:importstate): PWidget =
  result = vbox()
  if j.hasKey"widgets":
    for it in J["widgets"]:
      let w = it.importGUI(s)
      if not w.isNil:
        result.PContainer.add w
proc importHbox* (J:PJsonNode; s:importstate): PWidget =
  result = hbox()
  if j.hasKey"widgets":
    for it in j["widgets"]:
      let w = it.importGUI(s)
      if not w.isNil:
        result.PContainer.add w

proc importcolor (J:PJsonNode): TColor =
  if j.kind == jString:
    return al.color_name(j.str)

proc importInputfield* (J:PJsonNode; s:importstate):PWidget =
  var text: string
  if j.hasKey"text": text = j["text"].str
  else: text = ""
  result = inputField(text)
  

proc importChatlog* (J:PJsonNode; s:importstate): PWidget =
  let lines = if j.hasKey("lines"): j["lines"].num.int else: 5
  result = chatlog(lines)

template zz (ty; importF): expr =
  TValidator(
    typeChecker: (proc(W:PWidget):bool= w of ty),
    importer: importF
  )

var
  baseGUIenv* = {
    "window": zz(algui.PWindow, importWindow),
    "vbox":zz(PVbox, importVBox),
    "hbox":zz(PHbox, importHbox),
    "inputfield":zz(PInputField, importInputfield),
    "chatlog":zz( PChatlog, importChatlog),
    "container":zz( PContainer, importContainer), 
    "textlabel":zz(PTextlabel, importTextlabel),
    "button":zz(PTextlabel, importTextlabel)
  }.toTable

proc importGui (J:PJsonNode; s:importstate): PWidget =
  assert j.kind == jObject
  let kind = j["type"].str
  
  let validator = s.env[kind]
  if validator.importer.isNil:
    echo "Warning: widget type unknown: \"$#\"" % kind
    return
  else:
    result = validator.importer(j, s)
  
  if not result.isNil:
    result.style = s.defaultStyle
  
    if j.hasKey"class":
      result.class = j["class"].str
  
  if j.hasKey("name"):
    let n = j["name"].str
    
    if result.isNil:
      echo "Named widget not created: ", n
    else: 
      assert(not s.named.hasKey(n))
      s.named[n] = result
      result.name = just(n)
      when defined(debug):
        echo "Named widget created: $#" % n

type 
  TGuiIndex * = object
    root*: PWidget
    index*: TTable[string,PWidget]
    fonts*: TTable[string,RFont]
    focused*: TMaybe[PWidget]

proc setFocus (gui:var TGuiIndex; widget: PWidget) =
  if widget.isNil: 
    echo "Warning: setFocus() called to nil widget"
    return
  
  if gui.focused.has:
    gui.focused.val.lostFocus()
  gui.focused = just(widget)
  gui.focused.val.gainedFocus()


proc dispatch* (gui:var TGuiIndex; event: backend.PEvent): bool {.inline.} =
  case event.kind
  of eventMouseButtonDown:
    if event.mouse.button == 1:
      # left click
      # find if it intersects anything
      let p = point2d(event.mouse.x.float, event.mouse.y.float)
      let collides = gui.root.findCollisions(p)
      debugcode collides.len
      if collides.len == 1:
        let w = collides[0]
        when defined(debug):
          echo w
        w.onClick.emit
        gui.setFocus w
        result = true
        return
      elif collides.len == 0:
        if gui.focused.has:
          # lose focus
          gui.focused.val.lostFocus()
          gui.focused = nothing[pwidget]()
      
      elif collides.len > 1:
        # wat to do here?
        
  of eventKeyChar,eventKeyDown:
    # forward to focused widget only
    if gui.focused.has:
      result = gui.focused.val.handleEvent(event)
      if result: return
    
  else:
    discard
  



proc toFloat* (J:PJsonNode): TMaybe[float]=
  case j.kind
  of jFloat: return just(j.fnum.float)
  of jInt: return just(j.num.float)
  else: 
    discard

type StyleState = object
  fonts: TTable[string,RFont]
  
import sequtils

proc update (W: PWidget; S:var TStyle; J:PJsonNode; ss:StyleState ) =
  if j.haskey"font":
    s.font = ss.fonts[j["font"].str]
    if s.font.isNil:
      raise newException(EIO, "Unable to find font "& j["font"].str & " (available: $#)" % toSeq(ss.fonts.keys).join(", "))
  if j.haskey"fontcolor":
    s.fontColor = importColor(j["fontcolor"])
  if j.hasKey"padding-right":
    s.paddingRight = j["padding-right"].toFloat.val
  if j.hasKey"padding-bottom":
    s.paddingBottom = j["padding-bottom"].toFloat.val
  if j.haskey"padding-left":
    s.paddingLeft = j["padding-left"].toFloat.val
    
  if j.hasKey"width":
    let width = j["width"].toFloat
    if width.has:
      w.cache.width = width.val
  if j.haskey"minimum-width":
    s.minimumWidth = j["minimum-width"].toFloat.val
  
  if j.hasKey"height":
    let height = j["height"]
    if height.kind == jstring:
      if height.str[height.str.len-1] == '%':
        var pct = height.str[0 .. height.str.len-2].parseFloat.float / 100.0 
        w.cache.height = w.parent.val.cache.height * pct
      else:
        let h = j["height"].toFloat
        if h.has:
          w.cache.height = h.val

  if j.hasKey"position":
    let pos = j["position"]
    case pos.kind
    of jArray:
      if pos.len == 2:
        let 
          x = pos[0].toFloat
          y = pos[1].toFloat
        if x and y:
          let p = point2d(x.val, y.val)
          echo "Setting ", w, " pos to ", p
          w.setPos p
          
    
    of jString:
      case pos.str
      of "center":
        assert w.parent.has #assert(not w.parent.isNil)
        
        let parents = w.parent.val.getBB
        let parent_center = parents.center
        
        w.setPos point2d(0,0)
        let center = w.getBB.center
        
        let pos = point2d(parent_center.x - center.x, parent_center.y - center.y)
        w.setPos pos
      of "right-margin":
        let parentBB = w.parent.val.getBB
        let width = w.cache.width
        w.setPos point2d(parentBB.right - width, parentBB.top)
      of "left-margin":
        let parentBB = w.parent.val.getBB
        w.setPos point2d(parentBB.left, parentBB.top)
      of "bottom-margin":
        let parentBB = w.parent.val.getBB
        let hei = w.getBB.height
        w.setPos point2d(parentBB.left, parentBB.bottom - hei)
        
      else:
        echo "Unhanded \"position\" element: ",$pos
        
    else:
      discard
proc im_style* (J:PJsonNode; ss: StyleState) : TStyle=
  result.fontColor = mapRGB(255,255,255)
  update nil, result, j, ss


proc postStyles* (gui:TGuiIndex) =
  gui.root.eachWidget do (w:PWidget):
    if w.parent.has and w.style.font.isNil:
      w.style.font = w.parent.val.style.font
      
proc applyStyles* (gui:TGuiIndex; styles: seq[PJsonNode]; ss:stylestate; validators: type(baseGUIenv)) =

  for s in styles:
  
    let
      matcher = s[0]
      style = s[1]
    
    if matcher.kind == jString:
      # name lookup
      let w = gui.index[matcher.str]
      w.update w.style, style, ss
      continue
    
    if matcher.kind == jObject:
      echo "----------------\LMatching ", matcher
      
      var match_funcs: seq[proc(W:PWidget):bool] = @[]
      
      if matcher.hasKey"type":
        let t = matcher["type"].str
        let validator = validators[t]
        if not validator.typeChecker.isNil:
          match_funcs.add validator.typeChecker
        else:
          echo "  unknown widget type ", t
          quit 1
          continue
      
      if matcher.hasKey"class":
        let class = matcher["class"].str
        match_funcs.add(proc(W:PWidget): bool =
          w.class == class
        )
      
      if match_funcs.len > 0:
        gui.root.eachWidget do (W:PWidget):
          for f in match_funcs:
            if not f(w):
              return
          w.update w.style, style, ss
    else:
      echo "what is this ", matcher

proc importGUI* (
    J:PJsonNode; viewW, viewH: float;
    controllers = defaultController;
    env = baseGUIenv;
    preStyle: proc() = nil  ): TGUIindex =
  
  var s: ImportState
  new s
  s.env = env
  s.ctrls = controllers
  s.named = initTable[string,PWidget](32)
  
  var ss : StyleState
  ss.fonts =  initTable[string,RFont](32)
  var fontDirs = @[ expandFilename("."/"assets") ]
  fontDirs.add systemFontDirectories()
  
  var jfonts: PJsonNode
  if j.hasKey"fonts": jFonts = j["fonts"]
  elif j.hasKey"font": jFonts = j["font"]
  
  if not jFonts.isNil:
    for key,val in jFonts.pairs:
      let files = find_file(val["file"].str, fontDirs)
      if files.len == 0:
        echo "Could not find font ", key, " (", val["file"].str, ")"
        continue
      
      let size = val["size"].num.cint
      
      var f: PFont
      for file in files:
        f = al.loadFont(file, size, 0)
        if not f.isNil: break
      
      if f.isNil:
        raise newException(EIO, "Failed to load font "& key)
      else:
        ss.fonts[key] = f.fontR
  
  var styles : seq[PJsonNode] = @[]
  if j.hasKey"style":
    for i in 0 .. < j["style"].len:
      let this_style = j["style"][i]
      if this_style[0].kind == jString and this_style[0].str == "default":
        s.defaultStyle = this_style[1].im_style(ss)
      else:
        styles.add this_style
  
  result.root = j["root"].importGui(s)
  result.index = s.named
  result.fonts = ss.fonts
  
  result.root.cache.width = viewW
  result.root.cache.height = viewH
  
  if not preStyle.isNil: 
    preStyle()
  
  # apply styles
  result.applyStyles styles, ss, s.env
  result.postStyles


proc importGUI* (
    file:string; viewW, viewH: float; 
    controllers = defaultController;
    env = baseGuiEnv,
    preStyle: proc() = nil    ): TGuiIndex = 
  importGUI(json.parseFile(file), viewW,viewH, controllers,env,preStyle)
