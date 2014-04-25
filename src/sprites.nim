import backend
import_backends
import
  tables,json,os,re,strutils,
  std


type
  KeyedAnimation* = object
    animStates*: TTable[string,AnimInfo]
  
  AnimationMode* = enum
    AnimLoop, AnimBounce

  AnimInfo* = ref object
    mode*: AnimationMode
    frames*: seq[TFrame]
  
  TFrameKind = enum
    basicFrame, animState
  TFrame = object
    case kind: TFrameKind
    of basicFrame:
      row*,col*: int
      time*: float
    of AnimState: 
      anim*: AnimInfo


proc toSeconds* (J:PJSONNODE): FLOAT =
  if j.kind == jArray:
    case j[0].str
    of "ms","milliseconds":
      return j[1].toFloat / 1000
    of "secs","seconds":
      return j[1].toFloat
  result = 1.0

proc load (frame:var TFrame; j:PJsonNode; parent: KeyedAnimation) =
  if j.hasKey"animation":
    frame = TFrame(kind: AnimState, anim: parent.animStates[j["animation"].str])
    return
  frame = TFrame(kind: BasicFrame)
  frame.row = j["row"].toInt
  frame.col = j["col"].toInt
  frame.time = j["time"].toSeconds

proc load (anim:AnimInfo; j:PJsonNode; parent: KeyedAnimation) =
  
  for frame in j["frames"]:
    var f: TFrame
    f.load frame, parent
    anim.frames.add f

proc loadKeyedAnim* (J:PJsonNode): KeyedAnimation =
  result.animStates = initTable[string,AnimInfo](8)
  if j.hasKey"animations":
    let anims = j["animations"]
    for name,anim in anims.pairs:
      result.animStates[name] = animInfo(frames: @[])
      result.animStates[name].load anim, result
  

type
  SpriteSheet* = ref object
    when defined(useAllegro):
      bmp*: PBitmap
    elif defined(useCSFML):
      tex*: PTexture

    rows*,cols*: int
    frameW*,frameH*:int
    file*: string
  
  SpriteSheetCache* = ref object
    cache*: TTable[string,SpriteSheet]
    assetsDir*: string

when defined(useAllegro) or defined(useSDL2):
  proc getSrcRect* (S:SpriteSheet; row,col:int): TRect[int32] =
    result.x = int32(col * s.frameW)
    result.y = int32(row * s.frameH)
    result.w = int32(s.frameW)
    result.h = int32(s.frameH)

let
  imageFilenamePattern* = re".+_(\d+)x(\d+)\.\S{3,4}"

proc newSpriteCache* (assetsDir = "assets"): SpriteSheetCache=
  result = SpriteSheetCache(assetsDir: assetsDir, cache: initTable[string,SpriteSheet](64))

proc loadSprite* (db: SpriteSheetCache; file:string): SpriteSheet {.
      raises:[EIO,EOverflow,EInvalidValue].} =
  result = db.cache[file]
  if not result.isNil:
    return
  
  when defined(useAllegro):
    let bmp = load_bitmap(db.assetsDir / file)
    if bmp.isNil:
      raise newException(EIO, "Failed to load image "& file)
    
    let
      sz = (x: bmp.getWidth, y: bmp.getHeight)
  
    new(result) do (s:SpriteSheet):
      destroy s.bmp
    result.bmp = bmp
  
  elif defined(useCSFML):
    var img = newImage(db.assetsdir / file)
    if img.isNil:
      raise newException(EIO, "Failed to load image "& file)
    let 
      sz = img.getSize
    
    let tex = img.newTexture
    destroy img
    if tex.isNil:
      raise newException(EIO, "Failed to create texture for image "& file)
    
    new(result) do (s:SpriteSheet):
      destroy s.tex
    result.tex = tex
  
  if result.isNil:
    raise newException(EIO, "No backend to load sprite sheet with and what-not.")
  
  var frameW,frameH: int
  if file =~ imageFilenamePattern:
    frameW = matches[0].parseInt.int
    frameH = matches[1].parseInt.int
  
  result.file = file
  result.frameW = frameW
  result.frameH = frameH
  result.rows = int(sz.y / frameH)
  result.cols = int(sz.x / frameW)
  
  db.cache[file] = result


when defined(globalSpriteCache):
  let db* = newSpriteCache()
  proc loadSprite* (file:string): SpriteSheet = loadSprite(db,file)

