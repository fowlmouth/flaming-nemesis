#import 
#  al, packets, enetcon,
#  basic2d, strutils, tables,
#  fowltek/maybe_t
import
  signals, 
  gamestates, backend,
  basic2d, strutils, tables, os, math,
  fowltek/maybe_t
import_backends

import enetcon, packets, connection_common

type
  PChatState* = ref object of GameState
    client: PConnection
    ut: UserTable
    networkTimer: PTimer
  
    gui: TGuiIndex
    loginForm, userList, chatArea: PWidget
    chatWindow: PChatlog
    showLogin: bool
var
  vt = packets.defaultVT

proc connect (gs: PChatState; ip:string; port:int; timeout:float): bool =
  try:
    let c = newConnection(vt)
    c.connectClient ip,port.int16, timeout
    gs.client = c
    return true
  except:
    echo "Failed to connect: ", getCurrentExceptionMsg()
    return false

proc submitLogin (GS:PChatState) =
  if gs.client.isNil: return
  
  let name = gs.gui.index["user"].PTextLabel.text
  if name.isNil or name.len == 0: return
  
  var loginpkt = initOpkt(32)
  var login = TLogin(name: name)
  loginpkt << login
  gs.client.broadcast loginpkt, channel0, flagReliable
  
proc submitChat (GS:PChatState; text:string) =
  if gs.client.isNil: return
  
  var pkt = initOpkt(256)
  pkt << packets.TChat(msg: text)
  gs.client.broadcast pkt, channel0, 0


var 
  chatstateGS* = defaultGS

chatstateGS.init = proc(gs:var gamestate; ds:drawstate ) =
  var res: PChatState
  new res
  res.client = newConnection(vt)
  res.client.data = cast[pointer](res)
  res.ut = initUsertable()
  res.networkTimer = createTimer(1/60)
  
  res.gui = importGUI("gui.json", ds.d.getDisplayWidth.float, ds.d.getDisplayHeight.float)
  res.loginForm = res.gui.index["loginform"]
  res.userlist = res.gui.index["userlist"]
  res.chatArea = res.gui.index["chatarea"]
  res.chatWindow = res.gui.index["chat"].PChatLog

  res.gui.index["submit-login"].onClick.connect res, submitLogin
  res.gui.index["chatinput"].PInputfield.textEntered.connect res, submitChat

  discard res.connect( "localhost",8024, 1.0 
  gs = res

chatstateGS.draw = proc(gs:gamestate; ds:drawState) =
  let gs = gs.PChatState
  #gui
  gs.chatarea.draw
  #chatarea.drawbb
  gs.gui.index["chatinput"].drawbb
  
  gs.userlist.draw
  
  
  if gs.showLogin:
    gs.loginForm.draw
    gs.loginform.drawbb

chatstateGS.handleEvent = proc(gs:GameState; evt:backend.PEvent): bool =
  if gs.PChatstate.gui.root.handleEvent(evt): return true
  
  when defined(useCSFML): 
    case evt.kind
    of evtClosed:
      gs.manager.window.close
      gs.manager.running = false
      return true
    else:
      discard
  elif defined(useAllegro):
    case evt.kind
    of eventDisplayClose:
      gs.manager.running = false
      return true
    else:
      discard

proc gs (c: PConnection): PChatstate =
  cast[PObject](c.data).PChatState

var
  client:PConnection

const
  my_name = "foo"
  address = ("localhost",8024)

vt.onConnect = proc(C:PConnection; clientID:int) =
  echo "Connected as client ", clientID
  
  discard """ # try to login
  var L: TLogin
  var o = initOpkt(32)
  L.name = my_name
  o << L
  c.broadcast o, channel0, flagReliable """

defPkt(vt, pktChat):
  var c: packets.TChat
  pkt >> c.user
  pkt >> c.msg
  var
    color = mapRGB(255,255,255)
    msg: string
  if c.user == -1:
    swap msg, c.msg
  else: 
    let user = con.gs.ut.find(c.user)
    if user.has:
      msg = "<$1> $2".format(user.val.name, c.msg)
    else:
      msg = "[$1] $2".format(c.user, c.msg)
  con.gs.chatWindow.add(msg,color)
  echo msg

proc `$`* [T] (some:seq[T]): string =
  result = "["
  for i in 0 .. < len(some):
    result.add($ some[i])
    if i < <len(some):
      result.add ", "
  result.add "]"

defPkt(vt, pktUserList):
  var c: packets.TUserList
  pkt >> c
  let gs = con.gs
  for u in c.users.mitems:
    gs.ut.save u


discard """ let white = mapRGB(255,255,255)

proc addChat* (text:string; color = white) =
  logWidget.add text,color

import al/cam

  D = createDisplay(800,640)
  let
    drawTimer = createTimer(1/60)
    networkTimer = createTimer(2/60)
    q = createEventQueue()
    cam = newCamera(D)
  cam.center = point2d(800/2,640/0)
  
  let
    white = mapRGB(255,255,255)
    
  drawTimer.start
  
  template screen_height: expr = d.getDisplayHeight
  template screen_width: expr = d.getDisplayWidth
  
  q.register d.eventSource
  q.register drawTimer.eventSource
  q.register getKeyboardEventSource()
  q.register getMouseEventSource()
  
  setup_gui d
  addChat "hello", white
  addChat "there", white
  
  if connect(address[0],address[1], timeout = 1.0):
    networkTimer.start

  var 
    evt: al.TEvent
    last = al.getTime()
    
    showLogin = true
  #  loginForm = {"user":"foo"}.toTable
  
  template redraw: stmt =
    let
      cur = al.getTime()
      dt = cur - last
    last = cur
    
    #if drawTimer.count mod 500 == 0: cam.zoom 0.99
    #cam.use
    
    cleartocolor maprgb(0,0,0)
    
    
    flipDisplay()
  
  while true:
    q.waitForEvent evt
    if gui.root.handleEvent(evt): continue
    
    case evt.kind
    of EventTimer:
      if evt.timer.source == drawTimer.eventSource:
        redraw
      elif evt.timer.source == networkTimer.eventSource:
        client.update
      
    of eventKeyChar:
    
      if evt.keyboard.unichar in 32 .. 126:
        #inputHandle evt.keyboard.unichar.char

    of eventDisplayClose:
    
      break

    of eventKeyDown:
    
      case evt.keyboard.keycode
      of keyEscape:
        break
        
      else:
        discard
    else:
      discard

 """

