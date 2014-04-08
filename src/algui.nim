import
  math, os, strutils, tables, basic2d,
  al, 
  signals,
  fowltek/maybe_t, fowltek/boundingbox

proc find_file (f: string; dirs: varargs[string]): seq[string] = 
  newSeq result,0
  for d in dirs:
    for file in walkFiles(d/f):
      result.add file

template ff(f):expr=formatFloat(f,ffDecimal,1)
proc `$`* (x:TBB): string =
  "($1,$2, $3,$4)".format(
    ff(x[0]), ff(x[1]), ff(x[2]), ff(x[3]))

discard """ type
  TBB* = tuple[l,t,r,b:float]

proc expandToInclude* (bb:var TBB; bb2:TBB) =
  bb.l = min(bb.l, bb2.l)
  bb.t = min(bb.t, bb2.t)
  bb.r = max(bb.r, bb2.r)
  bb.b = max(bb.b, bb2.b)
proc contains* (bb:TBB; point:TPoint2d): bool=
  point.x >= bb.l and point.x <= bb.r and
    point.y>=bb.t and point.y <= bb.b

proc width*(BB:TBB):float{.inline.}=bb.r - bb.l
proc w* (BB:TBB):float {.inline.} = bb.r - bb.l
proc `w=`* (bb:var TBB; w:float) {.inline.}=
  bb.r = bb.l + w
proc height*(BB:TBB):float{.inline.}=bb.b- bb.t  
proc h* (BB:TBB):float {.inline.} = bb.b - bb.t
proc `h=`*(bb:var TBB; h:float) {.inline.}=
  bb.b = bb.t + h """
proc center*(BB:TBB): TPoint2d {.inline.} =
  point2d( bb.left + bb.width / 2.0 , bb.top + bb.height / 2.0 )

type RFont* = ref object
  f*: PFont
proc fontR* (f:PFont): RFont =
  new(result) do (R:RFont):
    r.f.destroy_font
  result.f = f

type
  TStyle* = object
    font*: RFont
    fontColor*: TColor
    paddingRight*,paddingBottom*:float

type
  TWidgetVT* = object
    draw*: proc(W:PWidget){.nimcall.}
    setPos*: proc(W:PWidget; pos:TPoint2d){.nimcall.}
    getBB*: proc(W:PWidget): TBB{.nimcall.}
    handleEvent*: proc(W:PWidget; event:var al.TEvent): bool{.nimcall.}
    eachWidget*:proc(W:PWidget; f:proc(W:PWidget)){.nimcall.}

  PWidget* = ref object of TObject
    cache: TBB
    style: TStyle
    parent: TMaybe[PWidget]
    name: TMaybe[string]
    onClick*: PSignal[void]
    vt: ptr TWidgetVT

#proc pos* (W:PWidget): TPoint2d{.inline.}= point2d(w.cache.left, w.cache.top)
proc pos_x*(W:PWidget):float{.inline.}= w.cache.left
proc pos_y*(W:PWidget):float{.inline.}=w.cache.top
proc `pos_x=`*(W:PWidget; x:float){.inline.}=
  w.cache.left = x
proc `pos_y=`*(W:PWidget; y:float){.inline.}=
  w.cache.top = y

proc draw* (W:PWidget) {.inline.} =
  if not w.vt.isNil: w.vt.draw w

  

proc setPos*(W:PWidget; pos:TPoint2d){.inline.} =
  if not w.vt.isNil: w.vt.setPos w,pos
proc getBB* (W:PWidget):TBB {.inline.}=
  result = w.vt.getBB(w)
proc handleEvent*(W:PWidget; event:var al.TEvent):bool{.inline.}=
  if not w.vt.isNil:
    result = w.vt.handleEvent(w, event)
proc eachWidget*(W:PWidget; f:proc(W:PWidget)) =
  w.vt.eachWidget(w, f)
proc drawbb* (W:PWidget) {.inline.} = 
  #proc draw_rectangle*(x1,y1,x2,y2:cfloat; color:TColor; thickness:cfloat)
  if w.isnil: return
  
  let bb = w.getBB
  draw_rectangle(
    bb.left,bb.top, bb.right,bb.bottom, mapRGBA(255,0,0, 100), 2.0
  )
proc init* (W:PWidget) =
  w.onClick.init
  

var defaultVT: TWidgetVT
defaultVT.draw = proc(W:PWidget) = 
  discard 
defaultVT.setPos = proc(W:PWidget; pos:Tpoint2d)=
  discard
defaultVT.getBB = proc(W:PWidget): TBB =
  return w.cache
defaultVT.handleEvent = proc(W:PWidget;event:var al.TEvent):bool=
  false
defaultVT.eachWidget = proc (W:PWidget; f:proc(W:PWidget)) =
  f(w)

type
  PContainer* = ref object of PWidget
    ws: seq[PWidget]

var containerVT* = defaultVT
containerVT.draw = proc(W:PWidget) =
  for w in w.PContainer.ws:
    draw w
containerVT.handleEvent = proc(W:PWidget; event:var al.TEvent): bool =
  for wid in w.PContainer.ws:
    if wid.handleEvent(event):
      return true
containerVT.eachWidget = proc(W:PWidget; f:proc(W:PWidget)) =
  f(w)
  for child in w.pcontainer.ws: f(child)

proc container* : PWidget =
  result = PContainer(
    ws: @[],
    vt: containerVT.addr
  )
  result.init

proc add* (C:PContainer; widgets:varargs[PWidget]) =
  for w in widgets:
    c.ws.add w
    w.parent = just(c)

type
  PVbox* = ref object of PContainer
var vboxVT* = containerVT
vboxVT.setPos= proc(W:PWidget; pos:TPoint2d) =
  var p = pos
  var bb:TBB = (p.x,p.y, 0.0,0.0)#p.x,p.y)
  for widget in w.PContainer.ws:
    widget.setPos point2d(bb.left, bb.bottom)
    let bb2 = widget.getBB
    bb.expandToInclude bb2
    bb.height += w.style.paddingBottom
  w.cache = bb

proc vbox* : PWidget =
  result = PVbox(ws: @[], vt: vboxVT.addr)
  result.init

type
  PHbox* = ref object of PContainer
  
var hboxvt* = containerVT
hboxvt.setPos = proc(W:PWidget; pos:TPoint2d) =
  let p = pos
  var bb:TBB = (p.x,p.y, 0.0,0.0)#p.x,p.y)
  let w = w.PContainer
  for widget in w.ws:
    widget.setPos point2d(bb.right, bb.top)
    let bb2 = widget.getBB
    bb.expandToInclude bb2
    bb.width += w.style.paddingRight
  w.cache = bb

proc hbox* : PWidget =
  result = PHbox(ws: @[], vt: hboxvt.addr)
  result.init


type
  PTextLabel* = ref object of PWidget
    text*: string
    textChanged*:bool
var textLabelVT* = defaultVT
textLabelVT.draw = proc(W:PWidget)=
  let W = W.PTextLabel
  if W.text.isNil: return
  draw_text(
    w.style.font.f, w.style.fontColor, w.pos_x, w.pos_y, 
    fontAlignLeft, w.text.cstring
  )
textLabelVT.getBB = proc(W:PWidget): TBB =
  let w = w.PTextLabel
  if w.textChanged:
    w.cache.width = w.style.font.f.get_text_width(w.text).float
    w.cache.height = w.style.font.f.get_font_lineheight().float
    w.textChanged = false
  result = w.cache
textLabelVT.setPos = proc(W:pwidget;pos:tpoint2d)=
  w.cache.left = pos.x
  w.cache.top = pos.y

proc setText* (W:PTextLabel; text:string) =
  W.text = text
  W.textChanged = true
proc getText* (W:PTextLabel): string = W.text

proc textLabel* (text:string): PWidget =
  let r = PTextLabel(vt:textLabelVT.addr)
  r.init
  r.setText text
  r

type
  PInputField* = ref object of PTextLabel
    cursor*: int
    textEntered*: PSignal[string]
    
var inpF_vt = textLabelVT
inpf_vt.draw = proc(W:PWidget) =
  textLabelVT.draw(w)
  let w = W.PInputField
  
  #proc draw_line* (x1,y1,x2,y2:cfloat; color:TColor; thickness:cfloat)
  let cursor_x = 
    w.cache.left + w.style.font.f.get_text_width(w.text[0 .. <w.cursor].cstring).float
  draw_line cursor_x, w.cache.top, 
    cursor_x, w.cache.top + w.style.font.f.get_font_line_height().float,
    w.style.fontColor, 1.0

inpf_vt.handleEvent = proc(W:PWidget; event:var al.TEvent): bool =
  if event.kind == eventKeyChar:
    if event.keyboard.unichar == '\b'.ord: return
  
    w.PInputfield.text.insert($(event.keyboard.unichar.char), w.PInputfield.cursor)
    w.PInputfield.cursor.inc 1
    result = true
    w.PTextlabel.textChanged = true
    
  elif event.kind == eventKeyDown:
    let w = W.PInputfield
    case event.keyboard.keycode
    
    of keyEnter:
      w.textEntered(w.text)
      
      w.cursor = 0
      w.setText ""
      
    of keyBackspace:
      if w.cursor > 0:
        if w.cursor > w.text.len: w.cursor = w.text.len
        let rem = w.text[w.cursor .. -1]
        w.text.setLen w.cursor-1
        echo repr(w.text)
        echo repr(rem)
        w.text.add rem
        w.textChanged = true
        w.cursor = max(0, w.cursor-1)
        
    else:
      return false
    return true


proc inputField* (text:string): PWidget =
  result = PInputField(text:text,cursor:0, vt: inpf_vt.addr, textChanged:true)
  result.init
  result.PInputfield.textEntered.init


type
  PWindow* = ref object of PWidget
    title*: PTextLabel
    child*: PWidget
var windowVT* = defaultVT
windowVT.setPos = proc(W:PWidget;pos:TPoint2d)=
  let w = algui.PWindow(w)
  w.cache = (pos.x, pos.y, 0.0,0.0)
  setPos w.title, pos
  w.cache.expandToInclude(w.title.getBB)

  w.child.setPos point2d( w.cache.left, w.cache.bottom )
  w.cache.expandToInclude w.child.getBB

windowVT.draw = proc(W:PWidget) =
  let w = algui.PWindow(w)
  discard """ draw_text(
    w.style.font, w.style.fontColor, w.pos_x, w.pos_y,
    fontAlignLeft, w.title.cstring
  ) """
  w.title.draw
  w.child.draw
windowVT.eachWidget = proc(W:PWidget; f:proc(W:PWidget)) =
  f(w)
  f(algui.PWindow(w).title)
  f(algui.PWindow(w).child)
  
proc setChild* (W:algui.PWindow; widget:PWidget) =
  w.child = widget
  widget.parent = just(w)

proc windowWidget* (title:string): PWidget =
  result = algui.PWindow(title: title.textLabel.PTextLabel, vt: windowVT.addr, child:nil)
  algui.PWindow(result).title.parent = just(result)
  result.init

type
  TChatMsg = tuple[text:string,color:TColor]
  PChatlog* = ref object of PWidget
    lines:int
    log: seq[TChatMsg]

var chatlogVT = defaultVT
chatlogvt.setPos = proc(W:PWidget;pos:tpoint2d) =
  w.cache.bottom = pos.y
  w.cache.left = pos.x
chatlogvt.getBB = proc(W:PWidget):TBB =
  w.cache
  
chatlogVT.draw = proc(W:PWidget) =
  let w = w.PChatlog
  let lineHeight = w.style.font.f.get_font_lineheight.float
  var p = point2d(w.cache.left , w.cache.bottom - lineHeight.float)
  for i in countdown(w.log.high, max(0, w.log.high-w.lines)):
    if p.y < -lineHeight: break
    
    draw_text w.style.font.f, w.style.fontColor, p.x,p.y,
      fontAlignLeft, w.log[i].text
    p.y -= lineHeight
  
proc add* (C:PChatlog; text:string; color:TColor) =
  c.log.add((text,color))
proc chatlog* (lines:int): PWidget =
  result = PChatlog(lines:lines, log: @[], vt: chatlogVT.addr)
  result.init


import json

type ImportState* = object
  named*: TTable[string,PWidget]
  defaultStyle*: TStyle

proc importGui* (J:PJsonNode; s:var importstate): PWidget 

proc importContainer (J:PJsonNode; s:var importstate): PWidget =
  #let
  result = container()
  if j.hasKey("widgets"):
    let ws = j["widgets"]
    assert ws.kind == jArray
    for it in ws.items:
      let w = it.importGUI(s)
      if not w.isNil:
        result.PContainer.add w

proc importWindow* (J:PJsonNode; s:var importstate): PWidget =
  let title = j["title"].str
  let r = algui.PWindow(windowWidget(title))
  r.title.style = s.defaultStyle
  
  if j.hasKey"child":
    r.setChild j["child"].importGUI(s)
  
  
  result = r
  
proc importTextLabel* (J:PJsonNode; s:var importstate): PWidget =
  let text = j["text"].str
  result = textLabel(text)

proc importVBox* (J:PJsonNode; s:var importstate): PWidget =
  result = vbox()
  if j.hasKey"widgets":
    for it in J["widgets"]:
      let w = it.importGUI(s)
      if not w.isNil:
        result.PContainer.add w
proc importHbox* (J:PJsonNode; s:var importstate): PWidget =
  result = hbox()
  if j.hasKey"widgets":
    for it in j["widgets"]:
      let w = it.importGUI(s)
      if not w.isNil:
        result.PContainer.add w

proc importcolor (J:PJsonNode): TColor =
  if j.kind == jString:
    return al.color_name(j.str)

proc importInputfield* (J:PJsonNode; s:var importstate):PWidget =
  var text: string
  if j.hasKey"text": text = j["text"].str
  else: text = ""
  result = inputField(text)
  

proc importChatlog* (J:PJsonNode; s:var importstate): PWidget =
  let lines = if j.hasKey("lines"): j["lines"].num.int else: 5
  result = chatlog(lines)

var
  jsonVT = initTable[string,type(importChatlog)](16)
  name2widget = initTable[string,proc(W:PWidget):bool](16)

template zz (kind:string; ty; importF): stmt =
  name2widget[kind] = proc(W:PWidget):bool = (w is ty)
  jsonVT[kind] = importF
zz "window", algui.PWindow, importWindow
zz "vbox", PVbox, importVBox
zz "hbox", PHbox, importHbox
zz "inputfield",PInputField, importInputfield
zz "chatlog", PChatlog, importChatlog
zz "container", PContainer, importContainer 
zz "textlabel", PTextlabel, importTextlabel
zz "button", PTextlabel, importTextlabel

proc importGui (J:PJsonNode; s:var importstate): PWidget =
  assert j.kind == jObject
  let kind = j["type"].str
  
  if jsonVT.hasKey(kind):
    result = jsonVT[kind](j, s)
  else:
    echo "Warning: widget type unknown: \"$#\"" % kind
  
  if not result.isNil:
    result.style = s.defaultStyle
  
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

type TGuiIndex * = tuple
  root: PWidget
  index: TTable[string,PWidget]

proc toFloat* (J:PJsonNode): TMaybe[float]=
  case j.kind
  of jFloat: return just(j.fnum.float)
  of jInt: return just(j.num.float)
  else: 
    discard

type StyleState = object
  fonts: TTable[string,RFont]
  

proc p* [T] (some:T):T{.inline.}=
  echo some
  some

proc update (W: PWidget; S:var TStyle; J:PJsonNode; ss:StyleState ) =
  if j.haskey"font":
    s.font = ss.fonts[j["font"].str]
  if j.haskey"fontcolor":
    s.fontColor = importColor(j["fontcolor"])
  if j.hasKey"padding-right":
    s.paddingRight = j["padding-right"].toFloat.val
  if j.hasKey"padding-bottom":
    s.paddingBottom = j["padding-bottom"].toFloat.val
  
  if j.hasKey"width":
    let width = j["width"].toFloat
    if width.has:
      w.cache.width = width.val
  
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
    case pos.str
    of "center":
      echo "Setting center on ", w.name
      assert w.parent.has #assert(not w.parent.isNil)
      
      let parents = w.parent.val.getBB
      echo "parents bb (", w.name, ")" , " (parent is ", w.parent.val.name, " ", parents, ")"
      let parent_center = parents.center
      echo " center = ", parent_center
      
      w.setPos point2d(0,0)
      let center = w.getBB.center
      
      let pos = point2d(parent_center.x - center.x, parent_center.y - center.y)
      w.setPos pos
    of "right-margin":
      let parentBB = w.parent.val.getBB
      let width = w.cache.width
      w.setPos point2d(parentBB.right - width, parentBB.top)
    
    of "bottom-margin":
      let parentBB = w.parent.val.getBB
      let hei = w.getBB.height
      w.setPos point2d(parentBB.left, parentBB.bottom - hei)
      
    else:
      echo "Unhanded \"position\" element: ",$pos

proc im_style* (J:PJsonNode; ss: StyleState) : TStyle=
  result.fontColor = mapRGB(255,255,255)
  update nil, result, j, ss


proc importGUI* (file:string; viewW, viewH: float): TGuiIndex = 
  let n = json.parseFile(file)
  var s: ImportState
  s.named = initTable[string,PWidget](32)
  
  var ss : StyleState
  ss.fonts =  initTable[string,RFont](32)
  var fontDirs = @[ expandFilename(".") ]
  fontDirs.add systemFontDirectories()
  
  for key,val in n["fonts"]:
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
      echo "Failed to load font ", key
    else:
      ss.fonts[key] = f.fontR
  
  var styles = n["style"]
  var skip: seq[int] = @[]
  block:
    for i in 0 .. < styles.len:
      if styles[i][0].kind == jString and styles[i][0].str == "default":
        s.defaultStyle = styles[i][1].im_style(ss)
        skip.add i
  
  echo repr(s.defaultStyle)
  
  result.root = n["root"].importGui(s)
  result.index = s.named
  
  result.root.cache.width = viewW
  result.root.cache.height = viewH
  
  # apply styles
  for idx in 0 .. < styles.len:
    if idx in skip: continue
    
    echo styles[idx]
    let s = styles[idx]
  
    let
      matcher = s[0]
      style = s[1]
    
    if matcher.kind == jString:
      # name lookup
      let w = result.index[matcher.str]
      w.update w.style, style, ss
      continue
    if matcher.kind == jObject:
      var match_funcs: seq[proc(W:PWidget):bool] = @[]
      
      if matcher.hasKey"type":
        let t = matcher["type"].str
        let f = name2widget[t]
        if f.isNil:
          echo "unk widget type ", t
          continue
        else:
          match_funcs.add f
      
      if match_funcs.len > 0:
        result.root.eachWidget do (W:PWidget):
          for f in match_funcs:
            if not f(w): 
              return
          w.update w.style, style, ss
    else:
      echo "what is this ", matcher
  