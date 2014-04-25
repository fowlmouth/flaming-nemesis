import tables, fowltek/maybe_t
export tables, maybe_t

type
  UserInterface* = generic u
    u.id is TInteger
    u.name is string

  UserTable* [T] = object
    users*: seq[T]
    name2user*: TTable[string,int]

proc save* [T] (ut:var usertable[T]; user: T) =
  ut.users.ensureLen user.id+1
  ut.users[user.id] = user
  ut.name2user[user.name] = user.id.int
proc find* [T] (ut:var userTable[T]; user: TInteger): TMaybe[ptr T] =
  # get a temporary pointer to the TUser record
  let user = user.int
  if user in 0 .. len(ut.users)-1:
    let u = ut.users[user].addr
    if not u.name.isNil:
      return just(u)
proc find* [T] (ut:var userTable[T]; name:string): Tmaybe[ptr T]=
  if ut.name2user.haskey(name): return just(ut.users[ut.name2user[name]].addr)

proc rm* [T] (ut:var userTable[T]; id:int) =
  if (let (has,u) = ut.find(id); has):
    ut.name2user.del u.name
    reset u[]

proc init* [T] (ut:var userTable[T]) =
  ut.users.newSeq 0
  ut.name2user = initTable[string,int](32)

from packets import TUser
import enetcon

type
  PClient* = ref object of TObject
    id*: int
    name*: string
    con*: PConnection
    ut*: usertable[TUser]
    running*: bool

proc connect* (client:PClient; host:string; port:int; timeout = 5.0) =
  client.con.connectClient host, port.int16, timeout
  
proc newClient* (vt:var TConnectionVT; name: string): PClient =
  new result
  result.name = name
  result.ut.init
  result.con = newConnection(vt)
  result.con.data = cast[pointer](result)

proc client* (con:PConnection):PClient = cast[PClient](con.data)
proc update* (cli:PClient){.inline.} = cli.con.update
proc findUser*  (cli:PClient; user: TInteger): TMaybe[ptr TUser] {.inline.} =
  cli.ut.find(user)




