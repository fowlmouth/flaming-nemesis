import gamestates, chatstate

var app = newGSM(800,600, "hello")
app.push chatstateGS
app.run

when false:
  import
    al, signals, algui,
    basic2d, strutils, tables, os, math,
    fowltek/maybe_t


  var
    gui: TGuiIndex
    
    loginForm, userList, chatArea: PWidget
    logWidget: PChatLog



  import enetcon, packets

  var
    client:PConnection

  type
    UserTable* = object
      users*: seq[TUser]
      name2user*: TTable[string,int]

  proc save* (ut:var usertable; user:TUser) =
    ut.users.ensureLen user.id+1
    ut.users[user.id] = user
    ut.name2user[user.name] = user.id

  proc find* (ut:var userTable; user: TInteger): TMaybe[ptr TUser] =
    let user = user.int
    if user in 0 .. len(ut.users)-1 and not ut.users[user].name.isNil:
      result = just(ut.users[user].addr)

  const
    my_name = "foo"
    address = ("localhost",8024)


  var 
    vt = packets.defaultVT
    ut = userTable(users: @[], name2user:initTable[string,int](64))


  vt.onConnect = proc(C:PConnection; clientID:int) =
    # try to login
    var L: TLogin
    var o = initOpkt(32)
    L.name = my_name
    o << L
    c.broadcast o, channel0, flagReliable

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
      let user = ut.find(c.user)
      if user.has:
        msg = "<$1> $2".format(user.val.name, c.msg)
      else:
        msg = "[$1] $2".format(c.user, c.msg)
    logWidget.add(msg,color)
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
    for u in c.users.mitems:
      ut.save u

  proc connect (ip:string; port:int; timeout:float): bool =
    try:
      let c = newConnection(vt)
      c.connectClient ip,port.int16, timeout
      client = c
      return true
    except:
      echo "Failed to connect: ", getCurrentExceptionMsg()
      return false


  proc submitLogin =
    if client.isNil: return
    
    let name = gui.index["user"].PTextLabel.text
    if name.isNil or name.len == 0: return
    
    var loginpkt = initOpkt(32)
    var login = TLogin(name: name)
    loginpkt << login
    client.broadcast loginpkt, channel0, flagReliable
    
  proc submitChat (text:string) =
    if client.isNil: return
    
    var pkt = initOpkt(256)
    pkt << packets.TChat(msg: text)
    client.broadcast pkt, channel0, 0

  proc setup_gui (D:PDisplay) =
    gui = importGUI("gui.json", D.getDisplayWidth.float, D.getDisplayHeight.float)
    loginForm = gui.index["loginform"]
    userlist = gui.index["userlist"]
    chatArea = gui.index["chatarea"]
    logwidget = gui.index["chat"].PChatLog

    gui.index["submit-login"].onClick.connect submitLogin
    gui.index["chatinput"].PInputfield.textEntered.connect submitChat

  let white = mapRGB(255,255,255)

  proc addChat* (text:string; color = white) =
    logWidget.add text,color

  import al/cam

  var
    D: PDisplay

  al_main:

    discard al.init()
    discard al.initBaseAddons()
    discard al.installEverything()
    
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
      
      #gui
      chatarea.draw
      #chatarea.drawbb
      gui.index["chatinput"].drawbb
      
      userlist.draw
      
      
      if showLogin:
        loginForm.draw
        loginform.drawbb
      
      
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



