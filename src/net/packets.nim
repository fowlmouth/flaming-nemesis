

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
  proc `<<`* (L:POpkt; R:ty) =
    body

template defPkt* (vt; id; body:stmt): stmt {.immediate.} =
  if vt.incoming.len < id.int+1:
    vt.incoming.setLen id.int+1
  vt.incoming[id.int] = proc(con:PConnection; origin:int; pkt:PIpkt) =
    body


type
  TChat* = object
    user*: TUserID
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
  ID_Record* [T:TInteger] = object
    id*: T
    name*: string

proc `>>`* [T] (L: PIPkt; R: var IDRecord[T]) =
  L >> r.id
  L >> r.name
proc `<<`* [T] (L: POPkt; R: IDRecord[T]) = 
  L << r.id
  L << r.name

type
  TUser* = IDRecord[int32]
  TUserList* = object
    numUsers*: uint16
    users*: seq[TUser]

load_impl(TUserlist):  
  var userID: int32
  L >> userID
  while userID != -1:
    var name: string
    L >> name
    if r.users.isNil: newSeq r.users, 0
    R.users.add(TUser(id: userID, name: name))
    L >> userID
  L >> r.numUsers
  assert r.numUsers.int == r.users.len

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
  var x: TUserList
  pkt >> x
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
  TGameRecord* = ID_Record[int16]
  TGamelist* = object
    games*: seq[TGameRecord]

load_impl(Tgamelist):
  L >> r.games
store_impl(TGamelist):
  L << pktGamelist.tpktid
  L << r.games

defPkt(defaultVT, pktGamelist):
  var gl: TGamelist
  pkt >> gl
  echo "Game list: ", gl.games



