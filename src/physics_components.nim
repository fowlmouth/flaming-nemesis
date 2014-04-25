import backend
import_backends
import 
  basic2d, json,
  std, components, 
  fowltek/entitty, fowltek/boundingbox,
  fowltek/maybe_t
import chipmunk as cp except TBB


proc bb* (b: cp.TBB): boundingBox.TBB =
  bb(b.l.float, b.t.float, (b.r - b.l).float, (b.b - b.t).float)


proc addToSpace* (s: PSpace) {.multicast.}
proc removeFromSpace*(s: PSpace){.multicast.}

proc impulse* (f: TVector2d) {.unicast.}

proc getBody*: TMaybe[cp.PBody]{.unicast.}

import cp_phys_sys

type
  Body* = object
    b*: cp.PBody
    s*: cp.PShape
Body.setDestructor do (E: PEntity):
  if not e[body].s.isNil:
    free e[body].s
  if not e[body].b.isNil:
    free e[body].b

msgImpl(Body, getAngle) do -> float:
  entity[body].b.getAngle.float
msgImpl(Body, getMass) do -> float:
  entity[body].b.getMass.float
msgImpl(Body, getRadius) do -> TMaybe[float]:
  just(entity[body].s.getCircleRadius.float)
msgImpl(Body, calculateBB, 1000) do (result: var TBB):
  result.expandToInclude(entity[body].s.getBB.bb)
msgImpl(Body, getBody) do -> TMaybe[cp.PBody]:
  maybe(entity[body].b)

msgImpl(Body, load) do (J: PJsonNode):
  if j.hasKey("Body"):
    let j = j["Body"]
    
    if j.hasKey("mass"):
      let mass = j["mass"].toFloat
      if entity[body].b.isNIL:
        entity[body].b = newBody(mass, 1.0)
      else:
        entity[body].b.setMass mass

    if j.hasKey("shape"):
      if not entity[body].s.isnil:
        let shape = entity[body].s
        
        raise newException(EIO, "current shape must be cleared for entity "& $entity.id)
        
      discard """ entity.em 
      entity.emCallback do (em:EntityManager; id:int):
        em.findPhysicsSystem.space.removeShape(shape)
        free shape
       """
      discard """ entity.scheduleRC do (x: PEntity; r: PRoom):
          #destroy the old shape
          r.physSys.space.removeShape(shape)
          free shape """

      case j["shape"].str
      of "circle":
        let 
          mass = entity[body].b.getMass
          radius = j["radius"].toFloat
        
        
        let 
          moment = momentForCircle(mass, radius, 0.0, vectorZero)
        entity[body].b.setMoment(moment)
        
        let
          shape = newCircleShape(entity[body].b, radius, vectorZero)
        shape.setElasticity( 1.0 )
        entity[body].s = shape
      else:
        quit "unk shape type: "& j["shape"].str
  
    if j.hasKey("elasticity"):
      entity[body].s.setElasticity j["elasticity"].toFloat
  
  if j.hasKey("initial-impulse"):
    var vec = j["initial-impulse"].vector2d
    entity.impulse vec
  if j.hasKey("initial-position") and not entity[body].b.isNil:
    entity.setPos j["initial-position"].point2d
  elif j.hasKey("Position") and not entity[body].b.isNil:
    entity.setPos j["Position"].point2d

msgImpl(Body, setPos) do (p: TPoint2d):
  if not entity[body].b.isNil:
    entity[body].b.setPos vector(p.x, p.y)
msgImpl(Body, getPos) do -> TPoint2d:
  point2d(entity[body].b.p)

msgImpl(Body,setVel) do (v: TVector2d):
  entity[body].b.setVel vector(v)
msgImpl(Body, getVel) do -> TVector2d:
  vector2d(entity[Body].b.getVel)

msgImpl(Body, addToSpace) do (s: PSpace):
  if not entity[body].b.isNil:
    discard s.addBody(entity[body].b)
    entity[body].b.setUserdata cast[pointer](entity.id)
  if not entity[body].s.isNil:
    discard s.addShape(entity[body].s)
    entity[body].s.setUserdata cast[pointer](entity.id)
msgImpl(Body, removeFromSpace) do (s: PSpace):
  if not entity[body].s.isNil:
    s.removeShape(entity[body].s)
    reset entity[body].s.data
  if not entity[body].b.isNil:
    s.removeBody(entity[body].b)
    reset entity[body].b.data

msgImpl(Body, impulse) do (f: TVector2d):
  entity[Body].b.applyImpulse(
    vector(f), vectorZero)

proc thrustFwd* {.unicast.}
proc thrustBckwd* {.unicast.}
proc turnRight* {.multicast.}
proc turnLeft* {.multicast.}
proc fire* (slot = 0) {.unicast.}

const thrust = 50.0
const turnspeed = 40.0
msgImpl(Body, thrustFwd) do:
  entity[body].b.applyImpulse(
    entity[Body].b.getAngle.vectorForAngle * entity.getFwSpeed,#thrust,
    vectorZero
  )
msgImpl(Body, thrustBckwd) do:
  entity[body].b.applyImpulse(
    -entity[body].b.getAngle.vectorForAngle * entity.getRvSpeed,# thrust,
    vectorZero
  )
msgImpl(Body,turnLeft) do:
  entity[body].b.setTorque(- entity.getTurnspeed)
msgImpl(Body,turnRight)do:
  entity[body].b.setTorque(entity.getTurnspeed)
