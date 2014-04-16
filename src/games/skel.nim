
import 
  backend, lobby,
  gamestates, json, gui_json
import_backends

assert defined(useAllegro)

type pgs = ref object of pbasegs
  gui: tguiindex

var gs = baseGS
# uncomment to register it in the lobby's game list thing
#registerGame "WIP state", gs

let gui_data = %{
  "font":  %{
    "regular": %{"file": %"Vera.ttf", "size": %14}
  },
  "style": %[
    %[%{"type": %"textlabel"}, %{"font": %"regular", "position": %[%10,%300]}]
  ],
  "root": %{
    "type": %"container",
    "widgets": %[
      %{"type": %"textlabel", "text": %"Hello"}
    ]
  }
}

gs.init = proc(gs:var gamestate; m:gsm) =
  var res: pgs
  new res
  
  res.gui = gui_data.importGui(m.window_width.float, m.window_height.float, defaultController)
  
  gs = res

gs.draw = proc(gs:gamestate; ds:drawstate) =
  baseGS.draw gs, ds
  gs.pgs.gui.root.draw


gs.handleEvent = proc(gs:gamestate; evt:backend.PEvent): bool =
  if baseGS.handleEvent( gs, evt ) or gs.pgs.gui.dispatch(evt): return true
  
  quit_event_check(evt):
    gs.manager.pop
    return true


when isMainModule:

  var man = newGSM(800,600,"foo")
  man.push gs
  man.run

