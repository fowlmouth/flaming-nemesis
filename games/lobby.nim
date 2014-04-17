import 
  gamestates, backend, net/chatstate, gui_json,
  signals,
  tables, strutils, basic2d,
  al/cam

import_backends

var lobbyGS* = defaultGS
type PBaseGS* = ref object of GameState
  chat*: PChatstate
  networkTimer*: PTimer

var baseGS* = defaultGS
baseGS.enter = proc(gs:GameState) =
  let gs = gs.PBaseGS
  if gs.chat.isNil:
    gs.chat = newChatState(
      gs.manager, "assets/gui.json", 
      gs.manager.window_width.float, gs.manager.window_height.float
    )

baseGS.handleEvent = proc(gs:GameState; event:backend.PEvent):bool =
  result = gs.PBaseGS.chat.handleEvent(event)
  
baseGS.draw = proc(gs:GameState; ds:drawstate) =
  gs.PBaseGS.chat.draw(ds)

type PLobbyGS* = ref object of PBaseGS
  gui: TGuiIndex
  cam: PCamera

var registeredGames: seq[tuple[name:string, gs:ptr gs_vt]] = @[]
proc registerGame* (name:string; gs: var gs_vt) =
  registeredGames.add((name, gs.addr))

lobbyGS.enter = proc(GS:GameState) =
  baseGS.enter(GS)
  
  let GS = GS.PLobbyGS
  
  gs.networkTimer.count = 0
  gs.networkTImer.start
  gs.manager.queue.register gs.networkTimer.eventSource
  
  gs.cam = newCamera(GS.manager.display)
  gs.cam.center = point2d(gs.manager.window_width/2, gs.manager.window_height/2)

lobbyGS.leave = proc(GS:GameState) =
  let GS = GS.PLobbyGS
  
  gs.manager.queue.unregisterEventSource gs.networkTimer.eventSource

proc `$`* (some:GSM): string =
  if some.isNil: "nil.GSM" else: "some GSM"
proc `$`* (some:gameState): string =
  if some.isnil: "nil.gameState" else: "some gameState"
proc `$`* (some:ptr gs_vt): string =
  if some.isNil: "nil.gs_vt" else: "some gs_vt"

lobbyGS.init = proc(GS:var GameState; m: GSM) =
  let 
    w = m.window_width.float
    h = m.window_height.float
  
  var res: PLobbyGS
  new res
  res.chat = newChatstate(m, "assets/gui.json", w,h)
  
  proc preStyle = 
    let
      man = m
      chat = res.chat 
      
      gamelist = res.gui.index["gamelist"].PContainer
    var
      games: seq[PWidget] = @[]
    
    for idx in 0 .. high(registeredGames):
      let 
        vt   = registeredGames[idx].gs
        name = registeredGames[idx].name
        w = textLabel(name)
      w.class = "gamelist-item"
      w.style = gamelist.style
      w.onClick.connect do:
        echo "Switching to ", name, " vt: ", vt
        
        let new_state = man.newGS(vt[])
        new_state.PBaseGS.chat = chat 
        man.push new_state
      
      games.add w
    
    if games.len > 0:
      let t = textLabel("Available games ($#)" % $games.len)
      t.class = "gamelist-item"
      t.style = gamelist.style
      gamelist.add t
      gamelist.add games
  
  res.gui = importGUI(
    "assets/lobby_gui.json", w,h, gui_json.defaultController,
    preStyle = preStyle
  )
  res.networkTimer = createTimer(1/60)
  
  gs = res
  
lobbyGS.draw = proc(GS:GameState; ds:DrawState) =
  let GS = GS.PLobbyGS
  
  gs.cam.use
  
  GS.chat.draw ds
  discard """ gs.chat.chatArea.draw
  gs.chat.chatlog.drawbb blue
  gs.chat.chatArea.drawbb green
   """
  GS.gui.root.draw
  GS.gui.index["gamelist"].drawBB
  



lobbyGS.handleEvent = proc(GS:GameState; event:backend.PEvent): bool=
  if baseGS.handleEvent(gs, event): return true
  
  let GS = GS.PLobbyGS
  
  when defined(useAllegro):
    if event.kind == eventTimer and event.timer.source == gs.networkTimer.eventSource:
      when netEnabled:
        gs.chat.tick

  if GS.chat.handleEvent(event) or 
     GS.gui.dispatch(event):
    echo gs.chat.gui.index["chat"].getBB
    return true
  
  if event.kind == eventKeyDown:
    var offs: TVector2d
    
    case event.keyboard.keycode
    of keyUP:
      offs.y -= 5.0
    of keyDown:
      offs.y += 5.0
    of keyRight:
      offs.x += 5.0
    of keyLeft:
      offs.x -= 5.0
    else:
      discard
    
    gs.cam.move offs
  
  quit_event_check(event):
    gs.manager.pop
    return true
  

when isMainModule:

  var man = newGSM(800,600,"foo")
  man.push lobbyGS
  man.run

