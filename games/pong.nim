import backend
import_backends
import 
  gamestates, chatstate, shapes,
  lobby,
  basic2d,
  fowltek/boundingbox ,
  math
randomize()

type 
  PPongGS* = ref object of PBaseGS
    center*: TPoint2d
    ball: PCircleShape
    ballVelocity: TVector2d
    pad1,pad2: RectangleShape

proc resetBall (gs:PPongGS) =
  gs.ball.position = gs.center
  gs.ballVelocity = polarVector2d(deg360 * random(1.0), 95)

var pongGS = baseGS
pongGS.init = proc(GS:var GameState; M:GSM) =
  
  let screenSize = (m.window_width.float, m.window_height.float)
  var result: PPongGS
  new result
  result.center = point2d(screenSize[0]/2, screenSize[1]/2)
  result.ball = shapes.newCircleShape()
  result.ball.radius = 5.0
  result.ball.fillColor = mapRGB(255,255,255)
  
  
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
    elif ks[keyDown]:
      move.y += 5
    gs.pad1.move move 
  
  gs.ball.position = gs.ball.position + gs.ballVelocity * dt
  if gs.ball.position.y < gs.ball.radius or gs.ball.position.y > gs.manager.window_width.float - gs.ball.radius:
    gs.ballVelocity.y = -gs.ballVelocity.y
    gs.ball.position = gs.ball.position + gs.ballVelocity * 2 * dt
  

pongGS.handleEvent = proc(GS:GameState; event:backend.PEvent): bool =
  if baseGS.handleEvent(gs, event):
    return true
  
  quit_event_check(event):
    gs.manager.pop

pongGS.draw = proc(GS:GameState; ds: DrawState) =
  let gs = gs.pponggs
  gs.chat.draw ds
  
  gs.pad1.draw ds
  gs.pad2.draw ds
  gs.ball.draw ds

registerStandalone "Pong", pongGS

