import backend
import_backends

import json
export json

proc toInt* (J:PJSONNODE; default = 0): INT  =
  result = default
  case j.kind
  of jInt:
    return j.num.int
  of jFloat:
    return j.fnum.int
  else:
    discard
proc toFloat*(J:PJsonNode; default = 0.0): float =
  return case j.kind
    of jInt: j.num.float
    of jFloat: j.fnum.float
    else: default

template withKey* (J:PJsonNode; key:string; varName: expr; body: stmt): stmt {.immediate.}=
  if j.hasKey(key): 
    let varName = j[key]
    body

import basic2d, math


# the penalty for having sfml vectors and chipmunk vectors
when defined(useChipmunk):
  import chipmunk as cp
  
  proc vector* [T: TNumber] (x, y: T): TVector = 
    result.x = x.cpfloat
    result.y = y.cpfloat
  proc vector* (v: TVector2d): TVector =
    result.x = v.x
    result.y = v.y
  proc vector* (v: TPoint2d): TVector = 
    result.x = v.x
    result.y = v.y
  when defined(useCSFML):
    proc vec2f* (v: TVector): TVector2f = TVector2f(x: v.x, y: v.y)

  proc vector2d* (v: TVector): TVector2d =
    result.x = v.x
    result.y = v.y
  
  when not TVectorIsTVector2d:
    proc point2d* (v: TVector): TPoint2d =
      point2d(v.x, v.y)

when defined(useCSFML):
  proc vec2f* (v: TPoint2d): TVector2f = TVector2f(x: v.x, y: v.y)

  proc point2d* (p: TVector2i): TPoint2d = point2d(p.x.float, p.y.float)

proc point2d* (v: TVector2d): TPoint2d=
  point2d(v.x, v.y)

proc vector2d* (n: PJSonNode): TVector2d =
  if n.kind == jString:
    case n.str
    of "random-direction":
      result = polarVector2d(deg360.random, 1.0)
    return
  
  assert n.kind == jArray
  if n[0].kind == jString:
    case n[0].str
    of "direction-degrees":
      result = polarVector2d(n[1].toFloat.degToRad, 1.0)
    
    of "v_*_f", "mul_f":
      result = n[1].vector2d * n[2].toFloat
    
    of "add":
      result = n[1].vector2d + n[2].vector2d
    
    else:
      discard
    return
  
  result.x = n[0].toFloat
  result.y = n[1].toFloat
proc point2d* (n: PJsonNode): TPoint2d =
  result = n.vector2d.point2d
  
  
import tables

proc init* [K,V] (t: var TTable[K,V]) {.inline.} =
  t = initTable[k,v]()
