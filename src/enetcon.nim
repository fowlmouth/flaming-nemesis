import enet, fowltek/idgen, pkt_tools
export enet, pkt_tools

type
  TConnectionKind = enum
    ConClient, ConServer

  RPeer* = ref object
    p*: PPeer
    ip*: string
    id*: int
    data*:pointer

  PConnection* = ref TConnection
  TConnection* = object
    vt*: ptr TConnectionVT
    host:PHost
    case kind: TConnectionKind
    of ConClient: 
      peer: RPeer
    of ConServer: 
      peers: seq[RPeer]
      peerID: TIdgen[int]
    data*:pointer
    
  TPktHandler* = proc(C:PConnection; origin:int; pkt:PPacket)
  TConnectionVT* = object
    onConnect*: proc(C:PConnection; client:int) # run when a client connects
    onDisconnect*:proc(C:PConnection; client:int) # run when a client disconnects
    incoming*: seq[TPktHandler]

proc newPeer* (P: PPeer): RPeer =
  result = RPeer(P:P)
  p.data = cast[pointer](result)

proc newPeer* (id:int; P:PPeer):RPeer =
  result = newPeer(p)
  result.id = id

proc newConnection* (vt: var TConnectionVT): PConnection =
  new(result) do (x:PConnection):
    # 
    if not x.host.isNil:
      #
  result.vt = vt.addr

proc hostServer* (C:PConnection;
    port: int16; incomingBandwidth, outgoingBandwidth = 0) =
  var address: enet.TAddress
  address.host = EnetHostAny
  address.port = port.cushort
  
  c.host = create_host(address.addr, 32, 2, 
    incomingBandwidth.cuint, outgoingBandwidth.cuint)
  if c.host.isNil:
    raise newException(EIO, "Failed to start server.")
  c.kind = conServer
  c.peers.newSeq 0
  c.peerID.init

proc connectClient* (C:PConnection; ip:string; port:int16; timeout = 5.0;
    incomingBandwidth,outgoingBandwidth = 0) =
  
  var address: enet.TAddress
  discard set_host( address, ip )
  address.port = port.cushort
  
  c.host = create_host(nil, 1, 2, 
    incomingBandwidth.cuint,outgoingBandwidth.cuint)
  c.kind = conClient
  c.peer = c.host.connect(address, 2,0).newPeer
  
  template conFail (n): stmt =
    raise newException(EIO, "Failed to connect to "& ip &" (step "& $n &")")
  
  var L = c.host.isNil or c.peer.p.isNil
  if L:
    conFail 1
  
  var evt: TEvent
  L = c.host.hostService(evt, cuint(timeout * 1000)) > 0 and 
      evt.kind == evtConnect
  if not L:
    c.peer.reset
    conFail 2

  # get network welcome
  L = c.host.hostService(evt, cuint(timeout * 1000)) > 0 and 
      evt.kind == evtReceive
  if not L:
    evt.packet.destroy
    conFail 3 

  var clientID: int32
  evt.packet >> clientID
  evt.packet.referenceCount = 0
  evt.packet.destroy
  
  c.peer.id = clientID
  
  if not c.vt.onConnect.isNil:
    c.vt.onConnect(c, clientID)


proc dispatch* (C:PConnection; client:int; pkt:PPacket) =
  # 
  while pkt.referenceCount < pkt.dataLength:
    var
      ty: uint16
    pkt >> ty
    let ID = ty.int
    when defined(Debug):
      echo "Dispatching packet ", ID, " ", c.vt.incoming.isNil
    
    if ID notin 0 .. high(c.vt.incoming):
      break
    
    if C.vt.incoming[ID].isNil:
      break
  
    C.vt.incoming[ID](C, client, pkt)
    
proc `[]`* (C:PConnection; id:int): RPeer =
  C.peers[id]

proc broadcast*(C:PConnection; pkt:var OPkt; channel:cuchar; flags=0.cint) =
  if c.host.isNil:
    return
  let p = pkt.createPacket(flags)
  c.host.broadcast(channel, p)
  #destroy p
proc send* (Peer: RPeer;
    pkt: var OPkt; channel: cuchar; flags: cint = 0): cint {.discardable.}=
  let p = pkt.createPacket(flags)
  result = peer.p.send(channel, p)
  #destroy p
  if result != 0:
    raise newException(EIO, "Could not send the packets =(")

proc handleConnection (C:PConnection; P:PPeer) =
  # new id
  let id = c.peerID.get
  if id > c.peers.high:
    c.peers.setLen id+1
  
  let P = newPeer(p)
  P.ID = ID
  c.peers[ID] = P
  
  # get address
  var e_addr: array[100,char]
  discard p.p.address.getHostIP(e_addr, 100)
  p.ip = $e_addr
  
  # send welcome message (client ID)
  var pkt = initOpkt(2)
  pkt << p.id
  p.send pkt, 0.cuchar, flagReliable
  
  # run onConnect callbac
  if not c.vt.onConnect.isNil:
    c.vt.onConnect(c, id)

proc update* (C:PConnection; iterations = 100) =
  if c.isNil: return

  var 
    evt: TEvent
  for i in 1 .. iterations:
    if c.host.hostService(evt, 1) < 1:
      break
    
    case evt.kind
    
    of evtConnect:
      #new client
      assert c.kind == conServer
      c.handleConnection evt.peer

    of evtDisconnect:
      #disconnection
      case c.kind
      of conServer:
        let peer = cast[RPeer](evt.peer.data)
        if not peer.isNil:
          #
          if not c.vt.onDisconnect.isNIL:
            c.vt.onDisconnect c,peer.id
          c.peerID.release peer.id
          c.peers[peer.id] = nil
      
      of conClient:
        #
      
    of evtReceive:
      # received packets
      var origin: int
      if c.kind == conServer:
        origin = cast[RPeer](evt.peer.data).id  
      C.dispatch origin, evt.packet
      evt.packet.referenceCount = 0
      evt.packet.destroy
  
    else:
      break
