import entitty_man, physics_components
export entitty_man
import chipmunk as cp except TBB


type
  CpPhysicsSystem* = ref object of PSystem
    space*: PSpace
    update: proc(sys:PSystem; em:EntityManager; dt:float)

proc findPhysicsSystem* (haystack: seq[PSystem]): CpPhysicsSystem =
  for ndl in haystack:
    if ndl of CpPhysicsSystem:
      return CpPhysicsSystem(ndl)

proc newPhysicsSystem* : CpPhysicsSystem = 
  new(result) do (x: CPPhysicsSystem):
    if not x.space.isNil:
      free x.space
      
  result.added_to_em = proc(sys:PSystem; em:EntityManager) =
    # connect to the em's signals
    em.entityAdded.connect(sys) do (sys:PSystem; entity:ptr TEntity):
      entity[].addToSpace sys.CpPhysicsSystem.space
    em.entityDestroyed.connect(sys) do (sys:PSystem; entity:ptr TEntity):
      entity[].removeFromSpace sys.CpPhysicsSystem.space

  result.removed_from_em = proc(sys:PSystem; em:EntityManager) =
    em.entityAdded.disconnect sys
    em.entityDestroyed.disconnect sys

  result.space = newSpace()
  
  result.update = proc(sys:PSystem; em:EntityManager; dt:float) =
    sys.cpPhysicsSystem.space.step dt
