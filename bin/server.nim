import 
  enetcon, packets, pkt_tools,
  connection_common, std,
  json,
  tables, strutils, 
  fowltek/idgen


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

  TComChannel* = object
    name*: string
    users*: seq[int]
  
  PServer* = ref object of PClient
    port*:int16
    userList*: TUserList
    comChannels: seq[TComChannel]

proc srv * (con: PConnection): PServer =
  cast[PServer](con.data)

proc initComChan (name:string): TComChannel =
  TComChannel(users: @[], name: name)

proc newServer* (vt:var TConnectionVT; cfg: PJsonNode): PServer =
  let
    port = cfg["port"].toInt

  result = PServer(con: newConnection(vt), running: true)
  result.name = cfg["name"].str
  result.comChannels = @[ initComChan("pubchat") ]
  result.ut.init
  result.userList.users.newSeq 0
  result.port = port.int16
  result.con.data = cast[pointer](result)
  result.con.hostServer port.int16

proc run* (s:PServer) =
  echo "Starting server on port ", s.port
  while s.running:
    s.update

proc sysMsg* (srv:PServer; client:int; msg:string) =
  var x = initOpkt(sizeof(TPktID) + sizeof(uint16) + len(msg))
  x << TChat(user: -1, msg: msg)
  srv.con[client].send x, channel0, flagReliable
  
proc sendUserlist* (srv:PServer; client:int) =
  var x = initOpkt(128)
  x << srv.userList
  srv.con[client].send x, channel0, flagReliable

import algorithm
proc `<`* (a,b:TUser):bool = a.id < b.id

var vt = packets.defaultVT

vt.onConnect = proc(C:PConnection; client:int) = 
  when defined(Debug):
    echo "Client ",client," connected from ", c[client].ip
  c.srv.sysMsg client, "Welcome to a server. Waiting on a username."

vt.onBadPacket = proc(C:PConnection; client:int)=
  

proc `==`* (a:TUser; b:int32):bool = a.id == b

vt.onDisconnect = proc(C:PConnection; client:int) =
  let srv = c.srv
  if (let (has,u) = srv.findUser(client); has):
    
    var pkt = initOpkt(8)
    pkt << TDisconnect(user: client.TUserID)
    srv.con.broadcast pkt, channel0, flagReliable
    
    srv.ut.rm client
    
    let idx = srv.userList.users.find(client.int32)
    srv.userList.users.delete idx

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

proc acceptUser (srv:PServer; client:int; name:string)=
  let u_u = TUser(id:client.int32, name:name)
  srv.ut.save u_u
  srv.userList.users.add u_u
  srv.userList.users.sort system.cmp[TUser]
  
  srv.sysMsg client, "Welcome, "& name
  srv.sendUserList client

proc handleLogin* (srv:PServer; client:int; L:TLogin) =
  echo "New login! ", L
  
  template badLogin (msg): stmt =
    srv.sysMsg client, msg
    return
  
  # see if name is good
  if L.name.isNil or L.name.len notin 2 .. 32:
    badLogin "Name should be 2 to 32 characters."
  if srv.ut.find(L.name):
    badLogin "That name is in unavailable."

  # it is
  srv.acceptUser client, L.name

defPkt(vt,pktLogin):
  var L: TLogin
  pkt >> L
  con.srv.handleLogin origin, L



when isMainModule:
  var server = newServer(vt, defaultConfig)
  server.run
else:
  proc newStandardServer* (cfg:PJsonNode): PServer =
    newServer(vt, cfg)

