
import fowltek/idgen, fowltek/entitty, signals
export idgen, entitty

type
 
  EM_CB* = proc(EM:EntityManager; ent:int)

  EM_VT* = object
    onEntAdded* : EM_CB
    onEntDestroyed* : EM_CB
  #   
  EntityManager* = ref TEntityManager
  TEntityManager* = object
    entities: seq[TEntity]
    idgen: TIDgen[int]
    active: seq[int]
    doomed: seq[int]
    vt*: EM_VT
    systems*: seq[PSystem] 
    
    entityAdded*,entityDestroyed*: PSignal[PEntity]
    
    
  PSystem* = ref TSystem
  TSystem* = object of TObject
    slots*: seq[PSignalBase]
    added_to_em*,removed_from_em* : proc(sys:PSystem; em:EntityManager)  

type PUpdateSystem* = ref object of PSystem
  active*: seq[int]
proc updateSystem* : PUpdateSystem =
  result = PUpdateSystem(active: @[])
  result.added_to_em = proc(sys:PSystem; em:EntityManager) =
    # connect to the em's signals
    em.entityAdded.connect(sys) do (sys:PSystem; entity:int):
      sys.PUpdateSystem.active.add entity
    em.entityDestroyed.connect(sys) do (sys:PSystem; entity:int):
      if(let idx = sys.PUpdateSystem.active.find(entity); idx != -1):
        sys.PUpdateSystem.active.del idx
  result.removed_from_em = proc(sys:PSystem; em:EntityManager) =
    em.entityAdded.disconnect sys
    em.entityDestroyed.disconnect sys

proc add* (em:EntityManager; system:PSystem) =
  em.systems.add system
  system.added_to_em(system, em)

proc init* (em: EntityManager; initialSize = 1024) =
  em.entities.newseq initialSize
  em.idgen.init
  em.doomed.newseq 0
  em.active.newseq 0
  em.systems.newSeq 0
proc init* (sys: PSystem) =
  sys.entAdded = proc(sys:PSystem;em:EntityManager;ent:int) = 
    #
  sys.entDestroyed = proc(sys:PSystem;em:EntityManager;ent:int) = 
    #
  sys.update = proc(sys:PSystem;em:EntityManager; dt:float)= 
    #

proc newEM* (initialSize = 1024): EntityManager = 
  result = EntityManager()
  result.init

proc `[]`* (em: EntityManager; idx: int): PEntity = em.entities[idx]

iterator activeEntities* (EM:EntityManager): PEntity = 
  for id in em.active: yield em[id]

proc entityBeingAdded (em:entitymanager; ent:int){.inline.} =

  em.entityAdded.emit em[ent]

  if not em.vt.onEntAdded.isNil:
    em.vt.onEntAdded( em, ent )

proc entityBeingDestroyed (em:entitymanager; ent:int){.inline.} =

  for sys in em.systems:
    sys.entDestroyed sys, em, ent
     
  if not em.vt.onEntDestroyed.isNil:
    em.vt.onEntDestroyed( em, ent )

proc add* (EM: EntityManager; E: TEntity): int =
  result = em.idgen.get
  em.entities.ensureLen result+1
  em.entities[result] = E
  em[result].id = result
  em.active.add result
  em.entityBeingAdded result
proc add* (EM:EntityManager; ty: PTypeInfo): int =
  result = em.add( ty.newEntity )

proc del* (EM: EntityManager; ID: int) =
  ## Destroys the entity. Do not use this lightly, it is prefered to 
  ## use em.doom(id) and em.killDoomed 
  if em[id].id == -1: return
  if (let idx = em.active.find(id); idx != -1):
    em.active.del idx
  em.entityBeingDestroyed(id)
  em[id].destroy
  em[id].id = -1

proc doom*(EM: EntityManager; ID: int) = 
  em.doomed.add id
proc killDoomed* (EM: EntityManager)= 
  ## Destroys entities scheduled to be destroyed
  for id in em.doomed: em.del id
  em.doomed.setLen 0

