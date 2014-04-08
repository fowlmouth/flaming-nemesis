
when defined(useCSFML):
  template import_backends*: stmt =
    import csfml, csfml/gui, csfml_colors
    export csfml, csfml/gui, csfml_colors
  
elif defined(useAllegro):
  template import_backends*: stmt =
    import al, algui
    export al, algui
  
else:
  {.error: "No backend specified.".}

import_backends

when defined(useCSFML): 
  type 
    PEvent* = var csfml.TEvent
    TEvent* = csfml.TEvent
  type drawState* = object
    w*: PRenderWindow

elif defined(useAllegro):
  type 
    PEvent* = var al.TEvent
    TEvent* = al.TEvent
  type drawState* = object
    d*: PDisplay
