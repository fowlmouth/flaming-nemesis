import backend
import_backends
import 
  gamestates,
  games/lobby, chatstate,
  basic2d,
  fowltek/boundingbox ,
  math
randomize()

when defined(useAllegro):

  type 
    TShapeVT* = object
      draw*: proc(s:PShape; DS:DrawState){.nimcall.}
    PShape* = ref object of TObject
      pos, orign: TPoint2d
      fillColor*,outlineColor*: TColor
      outlineThickness*:float
      vt*: TShapeVT
  
  proc init* (s:PShape) =
    s.fillColor = white
    s.outlineColor = transparent
    s.outlineThickness = 0
  
  proc position* (s:PShape): Tpoint2d = s.pos
  proc `position=`*(s:PShape;p:tpoint2d) = s.pos = p
  proc move* (s:PShape; offs:TVector2d){.inline.} =
    s.position = s.position + offs
  
  proc draw* (S:PShape; ds:DrawState){.inline.} = s.vt.draw(s,ds)
  
  type 
    RectangleShape* = ref object of PShape
      size*: TVector2d
  
  proc newRectangleShape* : RectangleShape=
    new result
    result.PShape.init
    result.vt.draw = proc(S:PShape; DS:DrawState) =
      let r = s.RectangleShape
      draw_filled_rectangle(
        r.pos.x, r.pos.y, r.size.x+r.pos.x, r.size.y+r.pos.y,
        r.fillColor
      )
      draw_rectangle(
        r.pos.x, r.pos.y, r.size.x+r.pos.x, r.size.y+r.pos.y,
        r.outlineColor,
        r.outlineThickness
      )
  type 
    PCircleShape* = ref object of PShape
      radius*: float
  
  proc newCircleShape* : PCircleShape =
    new result
    result.PShape.init
    result.vt.draw = proc (S:PShape; DS:DrawState) =
      let c = S.PCircleShape
      draw_filled_circle c.pos.x,c.pos.y, c.radius, c.fillColor
      draw_circle c.pos.x, c.pos.y, c.radius, c.outlineColor, c.outlineThickness
  
  proc getRadius* (C:PCircleShape): float =
    c.radius

type 
  PPongGS* = ref object of PBaseGS
    ball: PCircleShape
    ballVelocity: TVector2d
    
    pad1,pad2: RectangleShape

var pongGS = baseGS
pongGS.init = proc(GS:var GameState; M:GSM) =
  debugCode m.isNIl
  let screenSize = (m.window_width.float, m.window_height.float)
  var result: PPongGS
  new result
  result.ball = pong.newCircleShape()
  result.ball.radius = 5.0
  result.ball.position = point2d( screenSize[0] / 2 , screenSize[1] / 2 )
  result.ball.fillColor = mapRGB(255,255,255)
  result.ballVelocity = polarVector2d(deg360 * random(1.0), 95)
  
  
  const
    paddleWidth = 10.0
    paddleHeight= 50.0
  
  let pad1 = newRectangleShape()
  pad1.size = vector2d(paddleWidth, paddleHeight)
  pad1.position = point2d(10,10)
  pad1.fillColor = red
  let pad2 = newRectangleShape()
  pad2.size = vector2d(paddleWidth, paddleHeight)
  pad2.position = point2d(screensize[0]-10-paddleWidth, 10)
  pad2.fillColor = green
  result.pad1 = pad1
  result.pad2 = pad2
  
  gs = result
  
pongGS.update = proc(GS:GameState; dt:float) =
  #
  let gs = gs.PPongGS
  let ks = gs.manager.keydown.addr
  block:
    var move = vector2d(0,0)
    if ks[keyUp]:
      move.y -= 5
    if ks[keyDown]:
      move.y += 5
    gs.pad1.move move 
  
  gs.ball.position = gs.ball.position + gs.ballVelocity * dt
  if gs.ball.position.y < gs.ball.radius or gs.ball.position.y > gs.manager.window_width.float - gs.ball.radius:
    gs.ballVelocity.y = -gs.ballVelocity.y
    gs.ball.position = gs.ball.position + gs.ballVelocity * 2 * dt
  

pongGS.handleEvent = proc(GS:GameState; event:backend.PEvent): bool =
  if gs.PPongGS.chat.handleEvent(event):
    return true
  
  quit_event_check(event):
    gs.manager.pop

pongGS.draw = proc(GS:GameState; ds: DrawState) =
  let gs = gs.pponggs
  gs.chat.draw ds
  
  gs.pad1.draw ds
  gs.pad2.draw ds
  gs.ball.draw ds

registerGame "Pong", pongGS

when isMainModule:
  let g = newGSM(800,600,"pong")
  g.push pongGS
  g.run
