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

  GS_VT* = object
    init* : proc(gs: var GameState; ds:drawState)
    handleEvent*: proc(GS: GameState; evt: backend.PEvent): bool
    update*: proc(GS: GameState; DT:Float)
    draw*: proc(GS: GameState; ds: drawState) 

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
defaultGS.init = proc(gs: var GameState; ds:drawState) =
  gs = gameState()

defaultGS.handleEvent = proc(gs:GameState; evt: backend.PEvent): bool =
  when defined(useCSFML):
    if evt.kind == evtClosed:
      gs.manager.window.close
      gs.manager.running = false
      return true
      
  elif defined(useAllegro):
    if evt.kind == eventDisplayClose:
      gs.manager.running = false
      return true

defaultGS.update = proc(gs:gamestate; dt:float)=
  discard
defaultGS.draw = proc(gs:gamestate; ds: DrawState) =
  discard

proc newGS* (m: GSM; vt: var gs_vt): gamestate =
  vt.init(result, m.getDrawState)
  result.vt = vt.addr

proc topGS* (M:GSM):GameState = m.states[< m.states.len]
proc push* (M:GSM; gs: var gs_vt) =
  let state = m.newGS(gs)
  m.states.add state
  state.m = m
proc push* (M:GSM; gs: GameState) =
  m.states.add gs
  gs.m = m

proc pop* (M: GSM) = 
  discard m.states.pop

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
  
  result.states.newSeq 0

    
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
    discard al.run_main(0, cast[cstringarray](m), proc(argc:cint, argv:cstringarray):cint{.cdecl.} =
      let m = cast[GSM](argv) 
      var
        last = getTime()
        drawTimer = createTimer(framerate)
        evt: al.TEvent
        
      m.queue.register drawTimer.eventSource
      drawTimer.start
      
      while m.running:
        m.queue.waitForEvent(evt)
        if m.topGS.vt.handleEvent(m.topGS, evt):
          continue
        
        if evt.kind == eventTimer and evt.timer.source == drawTimer.eventSource:
            let cur = al.getTime()
            let dt = last - cur
            last = cur
            
            m.topGS.vt.update m.topGS, dt
            
            set_target_backbuffer m.display
            clearToColor mapRGB(0,0,0)
            var ds = drawState(d:m.display)
            m.topGS.vt.draw(m.topGS, ds)
            flipDisplay()

      drawTimer.stop
    )

when defined(useAllegro):
  al.init()


