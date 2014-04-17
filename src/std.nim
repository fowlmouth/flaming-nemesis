

import json
export json

proc toInt* (J:PJSONNODE): INT {.raises: [EIO].} =
  if j.kind == jInt:
    return j.num.int
  else:
    raise newException(EIO, "Expected int, got "& $j)


