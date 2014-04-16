import backend
import_backends

type
  GameState* = ref object of TObject
    m: GSM
    vt*: ptr GS_VT
  
  GSM* = ref object 
    states: seq[GameState]
    running*: bool
    when defined(useCSFML):
      window*:PRenderWindow
      clock: PClock
    elif defined(useAllegro):
      queue*: PEventQueue
      display*:PDisplay
      keyDown*: array[keyMax, bool]

  GS_VT* = object
    init* : proc(gs: var GameState; m: GSM)
    handleEvent*: proc(GS: GameState; evt: backend.PEvent): bool
    update*: proc(GS: GameState; DT:Float)
    draw*: proc(GS: GameState; ds: drawState) 
    
    enter*, leave*: proc(GS:GameState)


proc window_width* (G:GSM): int =
  when defined(useCSFML):
    g.window.getSize.x.int
  elif defined(useAllegro):
    g.display.get_display_width.int
proc window_height*(G:GSM): int =
  when defined(useCSFML):
    g.window.getSize.y.int
  elif defined(useAllegro):
    g.display.get_display_height.int

proc manager* (G:GameState):GSM = g.m
proc getDrawState* (G:GSM): DrawState =
  when defined(useCSFML):
    drawState(w: g.window)
  elif defined(useAllegro):
    drawState(d: g.display)

var defaultGS*: GS_VT
defaultGS.init = proc(gs: var GameState; M: GSM) =
  gs = gameState()


defaultGS.update = proc(gs:gamestate; dt:float)=
  discard
defaultGS.draw = proc(gs:gamestate; ds: DrawState) =
  discard

proc newGS* (m: GSM; vt: var gs_vt): gamestate =
  vt.init(result, m)
  result.m = m
  result.vt = vt.addr

proc topGS* (M:GSM):GameState = m.states[< m.states.len]

proc add_state (M:GSM; state: GameState) =
  if m.states.len > 0:
    # .leave the current state
    if not m.topGS.vt.leave.isNil:
      m.topGS.vt.leave( m.topGS )
  
  state.m = m
  m.states.add state

  if not state.vt.enter.isNil:
    state.vt.enter( state )
    

proc push* (M:GSM; gs: var gs_vt) =
  m.add_state m.newGS(gs)
  
proc push* (M:GSM; gs: GameState) =
  m.add_state gs

proc pop* (M: GSM) = 
  let s = m.states.pop
  if not s.vt.leave.isNil:
    s.vt.leave( s )
  if m.states.len == 0:
    m.running = false


template quit_event_check* (evt; body:stmt):stmt {.immediate.}=
  when defined(useAllegro):
   if evt.kind == eventDisplayClose:
    body
  elif defined(useCSFML):
   if evt.kind == evtQuit:
    body

defaultGS.handleEvent = proc(gs:GameState; evt: backend.PEvent): bool =
  quit_event_check(evt):
    gs.manager.pop


proc newGSM* (w,h:int; title:string): GSM =
  when defined(useCSFML):
    result = GSM(
      window: newRenderWindow(videoMode(w.cint,h.cint,32), title, sfDefaultStyle)
    )
    result.clock = newClock()
  elif defined(useAllegro):
    result = GSM(
      display: createDisplay(w.cint, h.cint)
    )
    result.display.setWindowTitle title
    
    discard initBaseAddons()
    discard installEverything()
    
    let q = createEventQueue()
    q.register getKeyboardEventSource()
    q.register getMouseEventsource()
    q.register result.display.eventSource()
    
    result.queue = q 
    
    initColors()
  
  result.states.newSeq 0

discard """ template run_main_arg* (argument; argName; body:stmt): stmt =
  discard al.run_main(0, cast[cstringarray](argument)) do (argc:cint,argv:cstringarray)->cint{.cdecl.}:
    let argName{.inject.} = cast[type(argument)](argv)
    body 
     """
discard """ proc run_main_arg [T:ref|ptr] (arg:T; func:proc(arg:T){.nimcall.}) =
  type TBlah = tuple[func: proc(arg:T){.nimcall.}, arg: T]
  var arr: TBlah = (func, arg)
  discard al.run_main(0, cast[cstringarray](addr arr)) do (argc:cint;argv:cstringarray)->cint{.cdecl.}:
    let (func,arg) = cast[ptr TBlah](argv)[]
    func arg
 """


proc al_main2* [T] (arg:T; func:proc(arg:T){.nimcall.}) =
    #block:
    type TBlah = tuple[func: type(func), arg: T]
    var hax : TBlah = (func,arg)
    discard al.run_main(0, cast[cstringarray](hax.addr)) do (argc:cint;argv:cstringarray)->cint{.cdecl.}:
      let hax = cast[ptr TBlah](argv)
      hax.func hax.arg

template al_main2* (body:stmt):stmt =
  discard run_main(0, nil, proc(argc:cint; argv:cstringarray):cint{.cdecl.} =
    body
  )


proc run* (M: GSM) =
  
  m.running = true
  const framerate = 1/60

  when defined(useCSFML): 
    var evt: csfml.TEvent
    while m.running:
      while m.window.pollEvent(evt):
        discard m.topGS.vt.handleEvent(m.topGS, evt)
      if not m.running: break
      
      if m.clock.elapsedTime.asSeconds >= framerate:
        let dt = m.clock.restart.asMilliseconds / 1000
        m.topGS.vt.update (m.topGS,dt)
        m.window.clear black
        let ds = drawState(w: m.window)
        m.topGS.vt.draw(m.topGS, ds)
        m.window.display

  elif defined(useAllegro):
    
    #discard al.run_main(0, cast[cstringarray](m)) do (argc:cint, argv:cstringarray)->cint{.cdecl.}:
    #  let man = cast[GSM](argv)
    al_main(m) do (man:GSM):
      var
        last = getTime()
        drawTimer = createTimer(framerate)
        evt{.noInit.}: al.TEvent
        
      man.queue.register drawTimer.eventSource
      drawTimer.start
      
      while man.running:
        man.queue.waitForEvent(evt)
        if evt.kind == eventKeyDown: man.keyDown[evt.keyboard.keycode] = true
        elif evt.kind == eventKeyUp: man.keyDown[evt.keyboard.keycode] = false
        if man.topGS.vt.handleEvent(man.topGS, evt):
          continue
        
        if evt.kind == eventTimer and evt.timer.source == drawTimer.eventSource:
            let cur = al.getTime()
            let dt = last - cur
            last = cur
            
            man.topGS.vt.update man.topGS, dt
            
            set_target_backbuffer man.display
            clearToColor mapRGB(0,0,0)
            var ds = drawState(d:man.display)
            man.topGS.vt.draw(man.topGS, ds)
            flipDisplay()

      drawTimer.stop
    

when defined(useAllegro):
  al.init()


