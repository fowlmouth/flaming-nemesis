static:
  if not defined(useChipmunk):
    quit "must -d:useChipmunk for wormhole.nim"
  
import 
  backend, lobby, chatstate,
  gamestates, gui_json,
  json, tables,
  fowltek/maybe_t
import_backends

import
  components, physics_components, 
  entitty_man, cp_phys_sys


type
  pgs = ref object of pbasegs
    em*: EntityManager
    gui: TGuiIndex

let
  data = """
{
  "scenes":{
    "intro":{
      "size":[400,400],
      "entities":[
        ["wormhole",{"pos":[200,200]}]
      ]
    }
  },

  "entities":{
    "wormhole":{

      "Sprite": { "file": "wormhole_192x192.png"},
      "SpriteColsAreAnimation":["milliseconds",100],
      
      "Body": { "mass": "infinity", "shape": "circle", "radius": 5,"elasticity":0.3 },
      "GravitySensor" : { "radius": 1300, "force": 196 } ,
      "CollisionHandler": {"action": "warp", "position": [30,30]}
      
    },
    "hornet":{
      
      "Sprite": { "file": "vehicles/terran/hornet_54x54.png" },
      "SpriteColsAreRoll":true,
      "SpriteRowsAreRotation":true,
      
      "Body": { "mass": 10.0, "shape": "circle", "radius": 18 },
      "Components": ["InputController"],
      "Actuators": 39300,
      "Thrusters": {
        "fwspeed": 45,
        "rvspeed": -1,
      },
      "Emitters": ["Mass Driver", "Bomb", "Skithzar Mine", "MIRV Launcher"],
      "AngularDampners": 0.94,
      "VelocityLimit": 350.0,
      "Health": 70,
      "Battery": {"capacity":1700,"regen-rate":650}

    },
  },

}
"""

type
  EntType = object
    ty*: PTypeinfo
    js*: seq[PJsonNode]
  EntCache* = object
    types*: TTable[string, EntType]
    j*: PJsonNode

proc safeFindComponent* (n:string): int =
  try:
    result = findComponent(n)
  except:
    result = -1

var componentIDs* = initTable[string,TMaybe[int]]()
for c in allComponents:
  componentIDs[c.name] = just(c.id)

proc collectComponents* (J:PJsonNode): seq[int] =
  assert j.kind == jObject
  result = @[]
  for name, x in j:
    if name == "Components":
      for c in x: 
        if (let id = safeFindComponent(name); id != -1):
          result.add id
    elif (let id = safeFindComponent(name); id != -1):
      result.add id
    
proc loadData* (dom: PDomain; node:PJsonNode): EntCache =
  ## cache the TypeInfo for these entitys
  result.types = initTable[string,EntType](64)
  
  for name, dat in node["entities"]:
    let ty = dom.getTypeinfo(dat.collectComponents)
    result.types[name] = EntType(ty: ty, js: @[dat])
  
  result.j = node

proc create* (c: EntCache; name: string): TEntity =
  result = c.types[name].ty.newEntity
  for j in c.types[name].js:
    result.load j

proc loadScene* (c: EntCache; node:pjsonnode): EntityManager =
  result = newEM(64)
  result.systems.add newPhysicsSystem()
  for e in node["entities"]:
    let
      name = e[0].str
      dat  = e[1]
      
      id = result.add c.create(name)
  

var
  gs = baseGS
  
  gameData = Nothing[entCache]()

var dom* = newDomain()  
# uncomment to register it in the lobby's game list thing
registerGame "wormhole", gs

gs.init = proc(gs:var gamestate; m:gsm) =
  var res: pgs
  new res
  
  if not gameData.has:
    gameData = just(dom.loadData(data.parseJson))
  
  res.em = gameData.val.loadScene gameData.val.j["scenes"]["intro"]
  
  discard """ let j = %{
    "font":  %{
      "regular": %{"file": %"Vera.ttf", "size": %14}
    },
    "style": %[
      %[%"default",#%{"type": %"textlabel"}, 
        %{"font": %"regular"}]
    ],
    "root": %{
      "type": %"container"
    }
  } """
  #res.gui = j.importGui(m.window_width.float, m.window_height.float, defaultController)
  
  
  gs = res

gs.update = proc(gs:gamestate; dt:float) =
  for ent in gs.pgs.em.activeEntities:
    ent.update dt

gs.draw = proc(gs:gamestate; ds:drawstate) =
  let gs = gs.pgs
  baseGS.draw gs, ds
  #gs.pgs.gui.root.draw
  
  for ent in gs.em.activeEntities:
    ent.draw ds



gs.handleEvent = proc(gs:gamestate; evt:backend.PEvent): bool =
  if gs.pgs.gui.dispatch(evt) or baseGS.handleEvent( gs, evt ): 
    return true
  
  quit_event_check(evt):
    gs.manager.pop
    return true


registerStandalone "Wormhole", gs

