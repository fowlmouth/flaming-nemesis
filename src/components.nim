import backend
import_backends

import 
  std, sprites, entitty_man,

  json, basic2d, math,
  
  fowltek/entitty,fowltek/maybe_t,
  fowltek/boundingbox




proc draw* (ds: DrawState) {.unicast.}
proc update*(dt:float) {.multicast.}

proc load* (J:PJsonNode) {.multicast.}


proc setPos* (p: TPoint2d) {.unicast.}
proc getPos* : TPoint2d {.unicast.}
proc getAngle*: float {.unicast.}
proc setVel* (v: TVector2d) {.unicast.}
proc getVel* : TVector2d {.unicast.}
proc getRadius*: TMaybe[float] {.unicast.}
proc getTurnspeed* : float {.unicast.}
proc getFwSpeed* : float {.unicast.}
proc getRvSpeed* : float {.unicast.}

type EM_Member* = object
  ## Default component for all entities
  em: EntityManager 
proc em* (entity:PEntity): EntityManager {.inline.}=
  entity[EM_Member].em


proc on_expire {.multicast.}
proc expire* (X:PEntity) =
  x.on_expire
  x[EM_Member].em.doom x.id

proc on_explode  {.multicast.}
proc explode* (X:PEntity) =
  x.on_explode
  x[EM_Member].em.doom x.id


type
  Position* = object
    p: TPoint2d
msgImpl(Position,setPos) do (p: TPoint2d):
  entity[position].p = p
msgImpl(Position,getPos) do -> TPoint2d:
  entity[position].p
msgImpl(Position,load) do (J: PJsonNode):
  if j.hasKey("Position") and j["Position"].kind == jArray:
    entity[Position].p = point2d(j["Position"])
    echo entity[Position].p


type  
  Orientation* = object
    angle: float
msgImpl(Orientation,getAngle) do -> float:
  entity[Orientation].angle

msgIMpl(Orientation,load)do(J:PJsonNode):
  if j.hasKey("Orientation"):
    entity[Orientation].angle = j["Orientation"].toFloat


# draw scale (0.0 to 1.0)
proc getscale_pvt(result:var float) {.unicast.}
proc getscale* (E: PEntity): TVector2d = 
  result.x = 1.0
  E.getscalePVT result.x
  result.y = result.x

type SpriteScale* = object
  s*:float
SpriteScale.componentInfo.name = "Scale"
msgImpl(SpriteScale, load)do(J:PjsonNode):
  withKey(j, "Scale", s):
    entity[spritescale].s = j["Scale"].toFloat
msgImpl(SpriteScale, getScalePVT, 1) do (result: var float):
  result = entity[spritescale].s


proc calculateBB* (result:var TBB) {.multicast.}

type
  Sprite* = object
    t: SpriteSheet
    when defined(useCSFML):
      s: PSprite
    elif defined(useAllegro):
      origin*: TPoint2d
    w,h: int
    row,col:int
    dontRotate: bool

Sprite.setDestructor do (X:PEntity): 
  when defined(useCSFML):
    if not X[Sprite].s.isNil:
      destroy X[Sprite].s
  
msgImpl(Sprite,load) do (J:PJsonNode):
  withKey(j, "Sprite", j):
    let sp = entity[sprite].addr
    withKey(j,"file",f):
      sp.t = loadSprite(f.str)
      sp.w = sp.t.frameW
      sp.h = sp.t.frameH
      
      when defined(useCSFML):
        sp.s = sp.t.create(0,0)
      elif defined(useAllegro):
        sp.origin = point2d(sp.w / 2, sp.h / 2)
        
    withkey(j,"origin",j):
      when defined(useCSFML):
        if not sp.s.isNil:
          sp.s.setOrigin vec2f(point2d(j))
      else:
        sp.origin = point2d(j)
    
    when defined(useCSFML):  
      withKey(j,"repeated-texture",rt):
        if not sp.s.isNil:
          sp.s.getTexture.setRepeated(rt.bval)
      withkey(j,"texture-rect-size",trs):
        let sz = trs.point2d
        var r = sp.s.getTextureRect
        r.width=sz.x.cint
        r.height=sz.y.cint
        sp.s.setTextureRect r
      
msgImpl(Sprite,draw,9001) do (ds:DrawState):
  when defined(useCSFML):
    let s = entity[sprite].s
    s.setPosition entity.getPos.vec2f
    if not entity[sprite].dontRotate:
      s.setRotation entity.getAngle.radToDeg
    s.setScale entity.getScale
    ds.w.draw s
    
  elif defined(useAllegro):
    let 
      s = entity[sprite].addr
      pos = entity.getPos
      dest = point2d( pos.x - s.origin.x , pos.y - s.origin.y )
      scale = entity.getScale
    
      rect = s.t.getSrcRect(s.row, s.col)
      
    if s.dontRotate:
      #proc draw_scaled_bitmap*(bmp:PBitmap; sx,sy,sw,sh, dx,dy,dw,dh:cfloat; flags:cint)
      draw_scaled_bitmap s.t.bmp,
        rect.x.float, rect.y.float, rect.w.float, rect.h.float, 
        dest.x, dest.y, rect.w.float * scale.x, rect.h.float * scale.y,
        0
    else:
      # proc draw_scaled_rotated_bitmap*(bmp:PBitmap; 
      #   cx,cy,dx,dy,xscale,yscale,angle:cfloat; flags:cint)
      set_clip rect
      draw_scaled_rotated_bitmap s.t.bmp, 
        pos.x,pos.y, dest.x,dest.y,
        scale.x, scale.y,
        entity.getAngle,
        0
    
      reset_clipping_rectangle()


proc bbCentered* (p: TPoint2d; w, h: float): boundingbox.TBB =
  bb( p.x - (w/2) , p.y - (h/2) , w, h)

msgImpl(Sprite,calculateBB) do (result: var TBB):
  let scale = entity.getScale
  result.expandToInclude(
    bbCentered(
      entity.getPos, 
      entity[sprite].w.float * scale.x, 
      entity[sprite].h.float * scale.y
    )
  )





type
  SpriteColsAreAnimation* = object
    index*:int
    timer*,delay*:float
SpriteColsAreAnimation.requiresComponent Sprite

SpriteColsAreAnimation.setInitializer do (X:PENTITY):
  x[spriteColsAreAnimation].timer = 1.0
  x[spriteColsAreAnimation].delay = 1.0
msgImpl(SpriteColsAreAnimation, load) do (J:PJsonNode):
  withKey( j,"SpriteColsAreAnimation",sa ):
    if sa.kind != jBool:
      let d = sa.toFloat
      entity[spriteColsAreAnimation].delay = d
      entity[spriteColsAreAnimation].timer = d
msgImpl(SpriteColsAreAnimation,update) do (DT:FLOAT):
  let sa = entity[spriteColsAreAnimation].addr
  sa.timer -= dt
  if sa.timer <= 0:
    sa.timer = sa.delay
    sa.index = (sa.index + 1) mod entity[sprite].t.cols
    entity[sprite].col = sa.index

type
  OneShotAnimation* = object
    index*: int
    delay*,timer*:float
OneShotAnimation.requiresComponent Sprite 

OneShotAnimation.setInitializer do (E: PEntity):
  let osa = e[oneshotanimation].addr
  osa.delay = 1.0
  osa.timer = osa.delay

msgImpl(OneShotAnimation, load) do (J: PJsonNOde):
  withKey(j,"OneShotAnimation",osa):
    let d = osa.toFloat
    entity[oneShotAnimation].delay = d
    entity[oneShotAnimation].timer = d

msgImpl(OneShotAnimation, update) do (dt: float):
  let osa = entity[oneShotAnimation].addr
  osa.timer -= dt
  if osa.timer <= 0:
    osa.timer = osa.delay
    osa.index.inc 1 
    if osa.index == entity[sprite].t.cols:
      entity.expire
      discard """ entity.scheduleRC do (X: PEntity; R: PRoom):
        r.doom(x.id) """
    else:
      entity[sprite].col = osa.index


type SpriteRowsAreRotation* = object
SpriteRowsAreRotation.requiresComponent Sprite

msgImpl(SpriteRowsAreRotation, load) DO (J:PJSONNODE):
  entity[sprite].dontRotate = true
  
msgImpl(SpriteRowsAreRotation, postUpdate) do (em:EntityManager):
  let row = int( (( entity.getAngle + DEG90 ) mod DEG360) / DEG360 * entity[sprite].t.rows.float )
  entity[sprite].row = row

type SpriteColsAreRoll* = object
  roll: float
  rollRate: float
SpriteColsAreRoll.setInitializer do (X:PENTITY):
  X[SpriteColsAreRoll].rollRate = 0.2


msgImpl(SpriteColsAreRoll, turnRight) do :
  entity[SpriteColsAreRoll].roll -= entity[SpriteColsAreRoll].rollRate
msgImpl(SpriteColsAreRoll, turnLeft) do :
  entity[SpriteColsAreRoll].roll += entity[SpriteColsAreRoll].rollRate

msgImpl(SpriteColsAreRoll, postUpdate) DO (em: EntityManager):
  let rs = entity[spriteColsAreRoll].addr
  if rs.roll < -1: rs.roll = -1
  elif rs.roll > 1: rs.roll = 1
  else:         rs.roll *= 0.98
  let col = int( ( (rs.roll + 1.0) / 2.0) * (< entity[sprite].t.cols).float )
  entity[sprite].col = col
  


