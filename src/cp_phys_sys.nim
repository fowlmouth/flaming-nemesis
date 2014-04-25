import entitty_man, physics_components
export entitty_man
import chipmunk as cp except TBB


type
  CpPhysicsSystem* = ref object of PSystem
    space*: PSpace

proc findPhysicsSystem* (haystack: seq[PSystem]): CpPhysicsSystem =
  for ndl in haystack:
    if ndl of CpPhysicsSystem:
      return CpPhysicsSystem(ndl)

proc newPhysicsSystem* : CpPhysicsSystem = 
  new(result) do (x: CPPhysicsSystem):
    destroy x.space
  result.space = newSpace()
  result.entAdded = proc(sys:PSystem; em:EntityManager; ent:int) =
    em[ent].addToSpace sys.cpPhysicsSystem.space
  result.entDestroyed = proc(sys:PSystem; em:EntityManager; ent:int) =
    em[ent].removeFromSpace sys.cpPhysicsSystem.space
  result.update = proc(sys:PSystem; em:EntityManager; dt:float) =
    sys.cpPhysicsSystem.space.step dt
