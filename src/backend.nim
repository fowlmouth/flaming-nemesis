
when defined(useCSFML):
  template import_backends*: stmt =
    import csfml, csfml_colors
    export csfml, csfml_colors
  
elif defined(useAllegro):
  import al
  template import_backends*: stmt {.immediate.} =
    import al, algui
    export al, algui

else:
  {.error: "No backend specified.".}

# now a bunch of compability things


template debugcode* (x:expr):stmt =
  echo asttostr(x),": ", x
  

when defined(useCSFML): 
  type 
    PEvent* = var csfml.TEvent
    TEvent* = csfml.TEvent
  type drawState* = object
    w*: PRenderWindow


  import csfml/gui
  export csfml/gui


elif defined(useAllegro):
  var
    white*,black*,red*,green*,blue*,transparent*: TColor
  proc initColors* =
    # call after display is created
    white = mapRGB(255,255,255)
    black = mapRGB(0,0,0)
    red   = mapRGB(255,0,0)
    green = mapRGB(0,255,0)
    blue  = mapRGB(0,0,255)
    transparent = mapRGBA(0,0,0,0)

  type 
    PEvent* = var al.TEvent
    TEvent* = al.TEvent
  type drawState* = object
    d*: PDisplay

  import fowltek/boundingbox
  proc draw* (bb: TBB; color: TColor; thickness = 1.0) {.inline.}=
    al.draw_rectangle(bb.left, bb.top, bb.right, bb.bottom, color, thickness)
