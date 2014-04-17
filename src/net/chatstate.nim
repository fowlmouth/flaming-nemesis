#import 
#  al, packets, enetcon,
#  basic2d, strutils, tables,
#  fowltek/maybe_t
import
  signals, 
  gamestates, backend, gui_json,
  basic2d, strutils, tables, os, math,
  fowltek/maybe_t
import_backends
export gui_json

when defined(useEnet):
  import enetcon, packets, connection_common
  const NetEnabled* = true
  var
    vt = packets.defaultVT
else:
  const NetEnabled* = false

type
  PChatState* = ref object of TObject
    when netEnabled:
      client*: PConnection
      ut*: UserTable[TUser]
    gui*: TGuiIndex
    loginForm*, userList, chatArea*, sidepane: PWidget
    chatlog*: PChatLog
    showOpts*: bool
    opts*: PWidget


proc log* (cs:PChatstate; color = green; fmt:string; args:varargs[string,`$`]) =
  let s = fmt.format(args)
  cs.chatlog.add s, color
  echo s
proc netDisabledMsg* (cs:PChatState) =
  cs.log red, "Network is disabled."

proc connect (cs: PChatState; ip:string; port:int; timeout:float): bool =
  when netEnabled:
    try:
      let c = newConnection(vt)
      c.data = cast[pointer](cs)
      c.connectClient ip,port.int16, timeout
      cs.client = c
      return true
    except:
      echo "Failed to connect: ", getCurrentExceptionMsg()
      return false
  else:
    cs.netdisabledmsg

const
  address = ("localhost",8024)

proc toggle* (b:var bool){.inline.} = b = not b

proc cShowLoginForm (cs:PChatState): proc =
  return proc =
    cs.loginForm.toggleHidden

proc cPopState (man:GSM): proc  =
  return proc =
    man.pop

proc cSubmitLogin (cs:PChatState): proc =
  return proc =
    when netEnabled:
      echo "cSubmitLogin()"
      if cs.client.isNil: 
        echo "client is nil"
        return
      
      let name = cs.gui.index["user"].PTextLabel.text
      if name.isNil or name.len == 0: return
      
      var loginpkt = initOpkt(32)
      var login = TLogin(name: name)
      loginpkt << login
      cs.client.broadcast loginpkt, channel0, flagReliable
    else:
      cs.netdisabledmsg

proc cSubmitChat (cs:PChatState): proc(text:string) =
  return proc(text:string) =
    when netEnabled:
      if cs.client.isNil: return
      
      var pkt = initOpkt(256)
      pkt << packets.TChat(msg: text) #cs.gui.index["chatinput"].PInputfield.text)
      cs.client.broadcast pkt, channel0, 0

proc cReconnect (cs:PChatState): proc() =
  return proc =
    when netEnabled:
      if not cs.connect( address[0],address[1], 0.1 ):
        cs.log red, "Failed to connect to $#:$#", address[0],address[1]

proc cToggleOverlay (cs:PChatstate):proc()=
  return proc =
    let child = cs.opts.pcontainer.ws[1]
    if child.state == widgetHidden:
      cs.chatarea.show
      cs.userlist.show
      cs.sidepane.show
      child.show
    elif child.state == widgetActive:
      cs.chatarea.hide
      cs.userlist.hide
      cs.sidepane.hide
      child.hide

proc newChatstate* (man:GSM; file: string; w,h: float): PChatstate =
  var res: PChatState
  new res
  when netEnabled:
    res.ut.init
  res.showOpts = true
  
  var controllers = widgetControllers(
    onclick = {
      "ShowLoginForm":cShowLoginForm(res), 
      "Quit":cPopState(man), 
      "SubmitLogin":cSubmitLogin(res),
      "Reconnect":cReconnect(res),
      "ToggleOverlay":cToggleOverlay(res),
    },
    textEntered = {
      "SubmitChat":cSubmitChat(res)
    }
  )
  
  res.gui = importGUI(file, w,h, controllers)
  res.loginForm = res.gui.index["loginform"]
  res.userList = res.gui.index["userlist"]
  res.chatArea = res.gui.index["chatarea"]
  res.chatLog = res.gui.index["chat"].PChatlog
  res.opts = res.gui.index["opts"]
  res.sidepane = res.gui.index["sidepane"]

  #res.gui.index["submit-login"].onClick.connect res, submitLogin
  #res.gui.index["chatinput"].PInputfield.textEntered.connect res, submitChat
  cReconnect(res)()
  discard """ if not res.connect( address[0],address[1], 0.1 ):
    res.chatLog.add "Failed to connect to $#:$#".format(address[0],address[1]), green """
  
  res

proc draw* (cs:PChatState; ds:DrawState) =
  cs.gui.root.draw


proc handleEvent* (CS:PChatState; event: backend.PEvent): bool =
  result = cs.gui.dispatch(event)
proc dispatch* (cs:PChatState; event:backend.PEvent): bool =
  result = cs.gui.dispatch(event)
## base network 
## the last packet should be used for game-specific packets  

when netEnabled:
  proc cs (c: PConnection): PChatstate =
    cast[PChatState](c.data)

  vt.onConnect = proc(C:PConnection; clientID:int) =
    c.cs.chatLog.add("Connected as client $#" % $clientID, green)

  defPkt(vt, pktChat):
    var c: packets.TChat
    pkt >> c.user
    pkt >> c.msg
    var
      color = mapRGB(255,255,255)
      msg: string
    if c.user == -1:
      swap msg, c.msg
      color = green
    else: 
      let user = con.cs.ut.find(c.user)
      if user.has:
        msg = "<$1> $2".format(user.val.name, c.msg)
      else:
        msg = "[$1] $2".format(c.user, c.msg)
    con.cs.chatLog.add(msg,color)
    when defined(DEBUG):
      echo msg

  defPkt(vt, pktUserList):
    var c: packets.TUserList
    pkt >> c
    let cs = con.cs
    for u in c.users.mitems:
      cs.ut.save u


