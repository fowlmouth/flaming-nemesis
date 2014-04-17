

proc ensureLen* [T] (s: var seq[T]; L: int) {.inline.}=
  if s.len < L:
    s.setLen L

iterator mitems* [T] (s:var seq[T]): var T {.inline.}=
  for idx in 0 .. high(s): yield s[idx]

const
  channel0* = 0.cuchar
  channel1* = 1.cuchar
  channels* = 2
type
  TPktID* = uint16
  TUserID* = int32
  TPktTy* = enum
    pktChat = 0, 
    pktUserList,
    pktLogin,
    pktDisconnect,
    pktGame, pktGamelist

import enetcon, enet, pkt_tools, strutils


template load_impl*  (ty; body:stmt):stmt {.immediate.}=
  proc `>>`* (L:PIpkt; R:var ty) =
    body
template store_impl* (ty; body:stmt):stmt {.immediate.}=
  proc `<<`* (L:var Opkt; R:ty) =
    body


template defPkt* (vt; id; body:stmt): stmt {.immediate.} =
  if vt.incoming.len < id.int+1:
    vt.incoming.setLen id.int+1
  vt.incoming[id.int] = proc(con:PConnection; origin:int; pkt:PIpkt) =
    body

type
  TChat* = object
    user*: int32
    msg*: string
store_impl(TChat):
  L << pktChat.TPktID
  L << r.user
  L << r.msg
load_impl(TChat):
  L >> r.user
  L >> r.msg

var defaultVT* = TConnectionVT(incoming: @[])
defaultVT.incoming.setLen TPktTy.high.int-1
defPkt(defaultVT, PktChat):
  var c: TChat
  pkt >> c.user
  pkt >> c.msg
  echo "<$1> $2"

type
  TUser* = object 
    id*: int32
    name*: string
  TUserList* = object
    numUsers*: uint16
    users*: seq[TUser]

load_impl(TUser):
  L >> R.id
  L >> R.name
load_impl(TUserlist):  
  var userID: int32
  L >> userID
  while userID != -1:
    var name: string
    L >> name
    if r.users.isNil: newSeq r.users, 0
    R.users.add TUser(id: userID, name: name)
    L >> userID
  L >> r.numUsers
  assert r.numUsers.int == r.users.len
  
store_impl(TUser):
  L << r.id
  L << r.name
store_impl(TUserList):
  L << pktUserList.TPktID
  var numUsers = 0
  
  for idx in 0 .. high(R.users):
    template this: expr = r.users[idx]
    if this.name.isNil or this.name.len == 0:
      continue
    L << this
    inc numUsers
  L << -1i32
  L << numUsers.uint16
  
defPkt(defaultVT, pktUserList):
  var x = TUserList(users: @[])
  pkt >> x.users
  echo x.users.len, " Users:"
  for i in 0 .. < x.users.len:
    echo "  ", x.users[i].name

type
  TLogin* = object
    name*: string
 
load_impl(TLogin):
  L >> R.name
store_impl(TLogin):
  L << pktLogin.TPktID
  L << R.name

defPkt(defaultVT, pktLogin):
  var L: TLogin
  pkt >> L
  echo "Login ignored. ", L

type
  TDisconnect* = object
    user*: TUserID

load_impl(TDisconnect):
  L >> r.user
store_impl(TDisconnect):
  L << pktDisconnect.tpktid
  L << r.user
defPkt(defaultVT, pktDisconnect):
  var d: TDisconnect
  pkt >> d
  echo "User ", d.user, " disconnected."


type
  TGamePkt* = object
    gameID*: int16
load_impl(TGamePkt):
  L >> r.gameID
store_impl(TGamePkt):
  L << pktGame.tpktid
  L << r.gameID

defPkt(defaultVT, pktGame):
  var gp: TGamePkt
  pkt >> gp.gameID
  echo "Game packet not handled! id = ", gp.gameID

type
  TGameRecord* = tuple
    id: int16
    name: string
  TGamelist* = object
    games*: seq[TGameRecord]

load_impl(TGamerecord):
  L >> r.id
load_impl(Tgamelist):
  L >> r.games
store_impl(TGameRecord):
  L << r.id
  L << r.name
store_impl(TGamelist):
  L << pktGamelist.tpktid
  L << r.games

defPkt(defaultVT, pktGamelist):
  var gl: TGamelist
  pkt >> gl
  echo "Game list: ", gl.games



