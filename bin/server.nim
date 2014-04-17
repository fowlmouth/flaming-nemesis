import 
  enetcon, packets, pkt_tools,
  connection_common, json,
  tables, strutils, 
  fowltek/idgen


const
  port = 8024
let
  defaultConfig = %{
    "name": %"SomeServer",
    "port": %8024
  }

type
  TUserLevel* = enum
    UserAnon, UserBant, UserGuest, UserReg
  
  PUser* = ref object
    id*: int
    name*: string
    level*: TUserLevel
    peer*: RPeer

  PServer* = ref object
    ut*: UserTable[PUser]

proc srv * (con: PConnection): PServer =
  cast[PServer](con.data)

var 
  host: PConnection


  userList = TUserList(users: @[])
  name2user = initTable[string, int](64)

proc sysMsg* (P:RPeer; msg:string) =
  var m:TChat
  m.user = -1
  m.msg = msg
  var x = initOpkt(4+len(msg))
  x << m
  p.send x, channel0, flagReliable
proc sendUserlist* (P:RPeer) =
  var x = initOpkt(128)
  x << userList
  p.send x, channel0, flagReliable

import algorithm
proc `<`* (a,b:TUser):bool = a.id < b.id

var vt = packets.defaultVT

vt.onConnect = proc(C:PConnection; client:int) = 
  when defined(Debug):
    echo "Client ",client," connected from ", c[client].ip
    
  c[client].sysMsg "Welcome to a server. Waiting on a username."


defPkt(vt, pktChat):
  #
  var msg : TChat
  pkt >> msg
  
  when defined(Debug):
    echo msg
  
  msg.user = origin.int32
  var om = initOpkt(sizeof(msg.user)+2+len(msg.msg))
  om << msg
  
  con.broadcast om, channel0, flagReliable

proc acceptUser (C:PConnection; client:int; name:string)=
  name2user[name] = client
  
  userList.users.add TUser(id:client.int32, name:name)
  userList.users.sort system.cmp[TUser]
  
  c[client].sysMsg "Welcome, "& name
  c[client].sendUserlist

proc handleLogin* (C:PConnection; client:int; L:TLogin) =
  echo "New login! ", L
  
  template badLogin (msg): stmt =
    c[client].sysMsg msg
    return
  
  # see if name is good
  if L.name.isNil or L.name.len notin 2 .. 32:
    badLogin "Name should be 2 to 32 characters"
  if name2user.hasKey(L.name):
    badLogin """Name "$#" is in use""" % L.name

  # it is
  c.acceptUser client, L.name
  
defPkt(vt,pktLogin):
  var L: TLogin
  pkt >> L
  
  con.handleLogin origin, L

vt.onDisconnect = proc(C:PConnection; client:int) =
  let srv = c.srv
  
  if client in 0 .. srv.ut.users.high and not srv.ut.users[client].name.isNil:
    var pkt = initOpkt(8)
    pkt << TDisconnect(user: client.TUserID)
    c.broadcast pkt, channel0, flagReliable
    
    srv.ut.users[client].reset

host = newConnection(vt)
host.data = cast[pointer](PServer(ut: initUsertable()))


echo "Starting server on port ", port
host.hostServer port.int16

while true:
  host.update

