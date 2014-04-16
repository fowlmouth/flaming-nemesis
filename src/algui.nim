import
  math, os, strutils, tables, basic2d, unsigned,
  backend,
  signals,
  fowltek/maybe_t, fowltek/boundingbox
import_backends

proc find_file* (f: string; dirs: varargs[string]): seq[string] = 
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
proc contains* (bb:TBB; point:TPoint2d): bool=
  point.x >= bb.left and point.x <= bb.right and
    point.y>=bb.top and point.y <= bb.bottom
    
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
    paddingLeft*,paddingRight*,paddingBottom*:float
    minimumWidth*:float

type
  TWidgetVT* = object
    draw*: proc(W:PWidget){.nimcall.}
    getPos*: proc(W:PWidget): TPoint2d{.nimcall.}
    setPos*: proc(W:PWidget; pos:TPoint2d){.nimcall.}
    getBB*: proc(W:PWidget): TBB{.nimcall.}
    handleEvent*: proc(W:PWidget; event:backend.PEvent): bool{.nimcall.}
    detectCollisions*: proc(W:PWidget; pos:TPoint2d; result:var seq[PWidget]) {.nimcall.}
    eachWidget*:proc(W:PWidget; f:proc(W:PWidget)){.nimcall.}
    eachChild*:proc(W:PWidget; f:proc(W:PWidget)){.nimcall.}
    stringify*:proc(W:PWidget):string{.nimcall.}
  TWidgetState* = enum 
    WidgetHidden, WidgetDisabled, WidgetActive
  PWidget* = ref object of TObject
    cache*: TBB
    style*: TStyle
    class*: string
    state*: TWidgetState
    parent*: TMaybe[PWidget]
    name*: TMaybe[string]
    onClick*, lostFocus*, gainedFocus*: PSignal[void]
    vt*: ptr TWidgetVT

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
  w.vt.setPos w,pos
proc getPos*(W:PWidget): TPoint2d{.inline.}=
  w.vt.getPos(w)
proc getBB* (W:PWidget):TBB {.inline.}=
  result = w.vt.getBB(w)

proc handleEvent*(W:PWidget; event:var al.TEvent):bool{.inline.}=
  if not w.vt.isNil:
    result = w.vt.handleEvent(w, event)
proc eachWidget*(W:PWidget; f:proc(W:PWidget)) =
  w.vt.eachWidget(w, f)
proc children* (W:PWidget; f:proc(W:PWidget)) =
  w.vt.eachChild(w, f)

proc `$`* (w:PWidget): string =
  w.vt.stringify(w)


proc drawbb* (W:PWidget; color = mapRGB(255,0,0)) {.inline.} = 
  #proc draw_rectangle*(x1,y1,x2,y2:cfloat; color:TColor; thickness:cfloat)
  if w.isnil or w.state == widgetHidden: return
  
  let bb = w.getBB
  draw(bb, color, 2.0)

proc init* (W:PWidget) =
  w.onClick.init
  w.lostFocus.init
  w.gainedFocus.init
  w.state = widgetActive

proc show* (W:pwidget) =
  w.state = widgetActive
proc hide* (w:pwidget) =
  w.state = widgetHidden
  
proc toggleHidden* (W:PWidget) =
  if w.state == widgetHidden: 
    w.show
  elif w.state == widgetActive:
    w.hide

proc findCollisions (widget:PWidget; p:TPoint2d; result:var seq[PWidget]) =
  widget.vt.detectCollisions(widget, p, result)
proc findCollisions* (root: PWidget; p: TPoint2d): seq[PWidget] =
  result = @[]
  root.findCollisions(p, result)
  if (let idx = result.find(root); idx != -1):
    # remove the root widget
    result.delete idx



var defaultVT*: TWidgetVT
defaultVT.draw = proc(W:PWidget) = 
  discard 
defaultVT.setPos = proc(W:PWidget; pos:Tpoint2d)=
  discard
defaultVT.getPos = proc(W:PWidget): TPoint2d =
  point2d(w.cache.left, w.cache.top)
defaultVT.getBB = proc(W:PWidget): TBB =
  return w.cache
defaultVT.handleEvent = proc(W:PWidget;event:var al.TEvent):bool=
  false
defaultVT.detectCollisions = proc(W:PWidget; pos:TPoint2d; result: var seq[PWidget]) =
  if w.state != widgetHidden:
    if pos in w.getBB:
      result.add w
defaultVT.stringify = proc(W:PWidget):string =
  "Widget"
defaultVT.eachWidget = proc (W:PWidget;  f:proc(W:PWidget)) =
  f(w)
defaultVT.eachChild = proc(W:PWidget; f:proc(W:PWidget)) =
  # ignore, default widget doesnt have child (see container)

type
  PContainer* = ref object of PWidget
    ws*: seq[PWidget]

var containerVT* = defaultVT
containerVT.draw = proc(W:PWidget) =
  if w.state != widgetHidden:
    for w in w.PContainer.ws:
      draw w
containerVT.handleEvent = proc(W:PWidget; event:var al.TEvent): bool =
  for wid in w.PContainer.ws:
    if wid.handleEvent(event):
      return true
containerVT.eachWidget = proc(W:PWidget; f:proc(W:PWidget)) =
  f(w)
  for child in w.pcontainer.ws: 
    child.eachWidget f
containerVT.stringify = proc(W:PWidget):string =
  result = "(Container widget (name = $#, len = $#)".format(
    w.name, w.PContainer.ws.len )
  if w.PContainer.ws.len > 0:
    result.add " ("
    result.add((w.PContainer.ws.map do (W:PWidget) -> string: w.vt.stringify(w)).join(", "))
    result.add ")"
  result.add ")"
      
containerVT.detectCollisions = proc(W:PWidget; pos:TPoint2d; result:var seq[PWidget]) =
  if pos in w.getBB:
    let L = result.len
    for widget in w.pcontainer.ws:
      widget.vt.detectCollisions(widget, pos, result)
    if L == result.len:
      # no click detected in sub-things
      # so add w itself
      result.add w

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

template wigout(msg): stmt =
  raise newexception(ebase,msg)

type
  PTextLabel* = ref object of PWidget
    text*: string
    textChanged*:bool
var textLabelVT* = defaultVT
textLabelVT.draw = proc(W:PWidget)=
  let W = W.PTextLabel
  if W.text.isNil: return
  #if w.style.font.isNil:
  #  return
  
  draw_text(
    w.style.font.f, w.style.fontColor, w.pos_x, w.pos_y, 
    fontAlignLeft, w.text.cstring
  )
textLabelVT.getBB = proc(W:PWidget): TBB =
  let w = w.PTextLabel
  if w.textChanged:
    w.cache.width = max(w.style.minimumWidth, w.style.font.f.get_text_width(w.text).float)
    w.cache.height = w.style.font.f.get_font_lineheight().float
    w.textChanged = false
  result = w.cache
textLabelVT.setPos = proc(W:pwidget;pos:tpoint2d)=
  w.cache.left = pos.x
  w.cache.top = pos.y
textLabelVT.stringify = proc(W:PWidget):string =
  "(TextLabel (text=\"$#\"))".format(
    w.PTextLabel.text )

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
    allowedChars*: set[char]

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
inpf_vt.stringify = proc(W:PWidget): string =
  "(InputField (text=\"$#\"))" % W.PTextlabel.text
  
inpf_vt.handleEvent = proc(W:PWidget; event:var al.TEvent): bool =
  if event.kind == eventKeyChar:
    if event.keyboard.unichar > 255 or
       event.keyboard.unichar.char notin w.PInputField.allowedChars:
      return 
  
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
        w.text.add rem
        w.textChanged = true
        w.cursor = max(0, w.cursor-1)
    
    of keyLeft:
      w.cursor = max(0, w.cursor - 1)
    of keyRight:
      w.cursor = min(w.text.len, w.cursor + 1)
    
    else:
      return false
    return true


proc inputField* (text:string; allowedChars = {'\x20'..'\x7E'}): PWidget =
  result = PInputField(
    text:text, cursor:0, 
    vt: inpf_vt.addr, textChanged:true,
    allowedChars: allowedChars) 
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
  if w.state == widgetHidden: return
  
  let w = algui.PWindow(w)
  discard """ draw_text(
    w.style.font, w.style.fontColor, w.pos_x, w.pos_y,
    fontAlignLeft, w.title.cstring
  ) """
  w.title.draw
  w.child.draw
windowVT.eachWidget = proc(W:PWidget; f:proc(W:PWidget)) =
  let W = algui.PWindow(w)
  f(w)
  w.title.eachWidget f
  w.child.eachWidget f
windowvt.eachChild = proc(W:PWidget; f:proc(W:PWidget)) =
  f algui.pwindow(w).title
  f algui.pwindow(w).child
windowvt.stringify = proc(W:PWidget): string =
  "(Window $# $#)".format( algui.pwindow(w).title , algui.pwindow(w).child )

windowvt.detectCollisions = proc(w:pwidget; pos:tpoint2d; result:var seq[pwidget]) =
  if w.state == widgetHidden: return
  
  let w = algui.pwindow(w)
  findCollisions( w.title, pos, result )
  findCollisions( w.child, pos, result )

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
chatlogvt.getPos = proc(W:PWidget):TPoint2d=
  point2d(w.cache.left, w.cache.bottom)
chatlogvt.setPos = proc(W:PWidget;pos:tpoint2d) =
  w.cache.bottom = pos.y
  w.cache.left = pos.x
chatlogvt.getBB = proc(W:PWidget):TBB =
  w.cache
chatlogvt.stringify = proc(W:PWidget): string =
  "(Chatlog (last message = $#))".format(
    if w.PChatlog.log.len > 0: w.PChatlog.log[w.PChatlog.log.high].text else: ""
  ) 
chatlogVT.draw = proc(W:PWidget) =
  let w = w.PChatlog
  let lineHeight = w.style.font.f.get_font_lineheight.float
  var p = point2d( w.cache.left , w.cache.bottom )
  p.x += w.style.paddingLeft
  p.y -= lineHeight
  
  for i in countdown(w.log.high, max(0, w.log.high-w.lines)):
    if p.y < -lineHeight: break
    draw_text w.style.font.f, w.log[i].color, p.x, p.y,
      fontAlignLeft, w.log[i].text
    p.y -= lineHeight
  
proc add* (C:PChatlog; text:string; color:TColor) =
  c.log.add((text,color))
proc chatlog* (lines:int): PWidget =
  result = PChatlog(lines:lines, log: @[], vt: chatlogVT.addr)
  result.init

