import backend
import_backends

import basic2d, math

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

elif defined(useCSFML):
  # inline funcs, remove set/get from csfml names

  type
    PCircleShape* = ref csfml.PCircleShape
  proc newCircleShape* : shapes.PCircleShape =
    new(result) do (x: shapes.PCircleShape):
      destroy x[]
    result[] = csfml.newCircleShape(30,1.0)

  proc fillColor* (C:shapes.PCircleShape): TColor {.inline.}=
    c.getFillColor
  proc `fillColor=`* (c: shapes.PCircleShape; color:TColor) {.inline.}=
    c[].setFillColor color

