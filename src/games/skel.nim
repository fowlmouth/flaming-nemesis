
import 
  backend, lobby,
  gamestates
import_backends


type pgs = ref object of pbasegs
  gui: pwidget

var gs = baseGS
# uncomment to register it in the lobby's game list thing
#registerGame "WIP state", gs

gs.init = proc(gs:var gamestate; m:gsm) =
  var res: pgs
  new res
  
  let gui = (%{
    "font":  %{
      "regular": %{"file": %"Vera.ttf", "size": %14}
    },
    "style": %{
      %[%{"type":"textlabel"}, %{"font":"regular"}]
    },
    "root": %{
      "type": %"container",
      "widgets": %[
        %{"type": %"textlabel", "text":"Hello"}
      ]
    }
  }).importGui m.window_width, m.window_height
  res.gui = gui.root
  
  gs = res
  
gs.draw = proc(gs:gamestate; ds:drawstate) =
  gs.gui.draw


gs.handleEvent = proc(gs:gamestate; evt:backend.PEvent): bool =
  quit_event_check(evt):
    gs.manager.pop
    return true


when isMainModule:

  var man = newGSM(800,600,"foo")
  man.push gs
  man.run

