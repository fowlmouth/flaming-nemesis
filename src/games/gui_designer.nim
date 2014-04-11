
import 
  basic2d,

  signals,
  
  backend, lobby,
  gamestates, gui_json,json,tables
import_backends

var jeVT = algui.defaultVT
type
  PJsonEditor* = ref object of PWidget
    root*: PJsonNode
    child: PWidget

proc build_je_widget (j:pjsonnode): pwidget =
  case j.kind
  of jObject:
    let containr = vbox().PContainer
    
    for key,val in j.pairs:
      let keyline = hbox().PContainer
      
      var collapseButton: pwidget
      if val.kind == jObject:
        collapseButton = textLabel("[-]")
        keyline.add collapseButton

      keyline.add textlabel(key)
      
      let val_widget = val.build_je_widget
      if not val_widget.isNil:
        keyline.add val_widget 
        
        if val.kind == jObject:
          collapseButton.onClick.connect(val_widget) do (w:pwidget):
            w.toggleHidden
      
      containr.add keyline.pwidget
    
    return containr
  of jString:
    result = inputField(j.str)
    
  else:
    discard

proc buildChild* (w:pjsoneditor) =
  let n = w.root.build_je_widget
  w.child = n

proc jsonEditor* (node: PJsonNode): PWidget =
  var res: PJsonEditor
  new res
  res.root = node
  res.vt = jeVT.addr
  res.init
  res.buildChild
  return res

jeVT.setPos = proc(w:pwidget; pos:tpoint2d) =
  w.pjsoneditor.child.setPos pos
jeVT.draw = proc(W:pwidget) =
  w.pjsoneditor.child.draw

type pgs = ref object of pbasegs
  gui: tguiindex

var gs = baseGS
# uncomment to register it in the lobby thing
registerGame "GUI Designer", gs

gs.init = proc(gs:var gamestate; m:gsm) =
  var res: pgs
  new res
  
  let
    j = %{
      "fonts": %{
        "regular": %{"file": %"Vera.ttf", "size": %14}
      },
      "style": %[
        %[%"default", %{"font": %"regular"}],
        %[%"opts", %{"position": %[%100,%100]}]
      ],
      "root": %{
        "type": %"container",
        "widgets": %[
          %{"type": %"container", "name": %"userjson"},
          %{"type": %"vbox","name": %"opts","widgets": %[
            %{"type": %"button","text": %"foo"}         ]}
        ]
      }
    }
  
  res.gui = j.importGUI(m.window_width.float, m.window_height.float) 
  res.gui.index["userjson"].PContainer.add jsonEditor(j)
  res.gui.postStyles
  
  
  gs = res
  
gs.draw = proc(gs:gamestate; ds:drawstate) =
  let gs = gs.pgs
  basegs.draw gs, ds
  gs.gui.root.draw


gs.handleEvent = proc(gs:gamestate; evt:backend.PEvent): bool =
  result = baseGS.handleEvent(gs, evt)
  if result: return
  
  quit_event_check(evt):
    gs.manager.running = false
    return true


when isMainModule:

  var man = newGSM(800,600,"foo")
  man.push gs
  man.run

