import nake, 
  strutils, httpclient, osproc, re, json

const
  babel_dependencies = [
    "enet","allegro5","fowltek","signals","chipmunk"
  ] # oh yes
  
  
  games = ["pong"]

  enableChipmunk = true
  chipmunkGames = ["wormhole"]
  
  assetsDir = "./assets"

  binDir = "bin"
  srcDir = "src" 
  gamesDir = "games" 

  launcherExe = binDir / "launcher"
  serverExe = binDir / "server"
  
  releaseDefines = "-d:release"
  paths = "-p:\""& srcDir& "\" -p:\""& gamesDir & "\" -p:\""& (srcDir/"net")& "\""
  standardDefines = "-d:useEnet --warnings:off --deadCodeElim:on " & 
      paths & 
      (if enableChipmunk:" -d:useChipmunk" else:"")
  guiDefines = "-d:useAllegro -d:globalSpriteCache"

proc `&`* [t] (a,b: openarray[t]): seq[t] =
  newseq result, len(a) + len(b)
  result.setlen 0
  result.add a
  result.add b


when enableChipmunk:
  template allGames: expr = games & chipmunkGames
else:
  template allGames: expr = games

proc imports (dir:string; modules:varargs[string]): string =
  modules.map(proc(x:string):string="--import:"& (dir / x)).join" "

template gameImports : expr = imports(gamesDir, allGames())

task "build-launcher","build the launcher":
  dire_shell "nimrod c", "--parallelbuild:1", guiDefines, standardDefines, gameImports, launcherExe

task "build-server","build the server":
  dire_shell "nimrod c", guiDefines, standardDefines, gameImports, serverExe

task "build-both","build launcher and server":
  runTask("build-launcher")
  runTask("build-server")


task "build-games", "build all of the games in src/games individually and move them to bin/":
  var failed: seq[string] = @[]
  let 
    dir = getCurrentDir()
    srcDir = dir / "src"
  for game in allGames():
    echo "\L\L\L Building ", game, "\L"
    let game_file = gamesDir/ game
    if not shell(
        "nimrod c", standardDefines, guiDefines,
        gameFile ):
      failed.add game
    else:
      moveFile game_file, binDir/game

  echo "\L$# failed to build.".format(
    failed.len )
  if failed.len > 0:
    echo "  Failures: ", failed

task "dependencies", "install/update them dependencies": 
  var failed:seq[string] = @[]
  for pkg in babel_dependencies:
    if not shell( "babel install -y", pkg ):
      failed.add pkg
  
  if failed.len > 0: echo "Failed: ", failed

when true:
  when defined(WINDOWS): 
    const 
      DLLUtilName = "libeay32.dll"
    from winlean import TSocketHandle
  else:
    const
      versions = "(|.1.0.0|.0.9.9|.0.9.8|.0.9.7|.0.9.6|.0.9.5|.0.9.4)"
    when defined(macosx):
      const
        DLLUtilName = "libcrypto" & versions & ".dylib"
    else:
      const 
        DLLUtilName = "libcrypto.so" & versions

  type 
    MD5_LONG* = cuint
  const 
    MD5_CBLOCK* = 64
    MD5_LBLOCK* = int(MD5_CBLOCK div 4)
    MD5_DIGEST_LENGTH* = 16
  type 
    MD5_CTX* = object 
      A,B,C,D,Nl,Nh: MD5_LONG
      data: array[MD5_LBLOCK, MD5_LONG]
      num: cuint

  {.pragma: ic, importc: "$1".}
  {.push callconv:cdecl, dynlib:DLLUtilName.}
  proc MD5_Init*(c: var MD5_CTX): cint{.ic.}
  proc MD5_Update*(c: var MD5_CTX; data: pointer; len: csize): cint{.ic.}
  proc MD5_Final*(md: cstring; c: var MD5_CTX): cint{.ic.}
  proc MD5*(d: ptr cuchar; n: csize; md: ptr cuchar): ptr cuchar{.ic.}
  proc MD5_Transform*(c: var MD5_CTX; b: ptr cuchar){.ic.}
  {.pop.}

  #from strutils import toHex,toLower

  proc hexStr (buf:cstring): string =
    # turn md5s output into a nice hex str 
    result = newStringOfCap(32)
    for i in 0 .. <16:
      result.add toHex(buf[i].ord, 2).toLower

  proc MD5_File* (file: string): string {.raises:[EIO,Ebase].} =
    ## Generate MD5 hash for a file. Result is a 32 character
    # hex string with lowercase characters (like the output
    # of `md5sum`
    const
      sz = 512
    let f = open(file,fmRead)
    var
      buf: array[sz,char]
      ctx: MD5_CTX

    discard md5_init(ctx)
    while(let bytes = f.readChars(buf, 0, sz); bytes > 0):
      discard md5_update(ctx, buf[0].addr, bytes)

    discard md5_final( buf[0].addr, ctx )
    f.close
    
    result = hexStr(buf)

  proc MD5_Str* (str:string): string {.raises:[EIO].} =
    ##Generate MD5 hash for a string. Result is a 32 character
    #hex string with lowercase characters
    var 
      ctx: MD5_CTX
      res: array[MD5_DIGEST_LENGTH,char]
      input = str.cstring
    discard md5_init(ctx)

    var i = 0
    while i < str.len:
      let L = min(str.len - i, 512)
      discard md5_update(ctx, input[i].addr, L)
      i += L

    discard md5_final(res,ctx)
    result = hexStr(res)

  assert md5_str("Nimrod") == "d4355b7d5acb55f0bed1643c1c710029"

task "assets", "download the latest assets n such":
  let assets = json.parseFile("assets.json")["assets"]
  var failed: seq[string] = @[]
  withDir(assetsDir):
    for asset in assets:
      let
        file = asset["file"].str 
      try:
        let
          url = asset["url"].str
          md5 = asset["md5"].str
        var justDownloaded = false
        if not fileExists(file):
          echo "Downloading ", file, " from ", url
          downloadFile( url, file, timeout=3000)
          justDownloaded = true
        
        if md5_file(file) != md5:
          failed.add file &": Invalid checksum"
          removeFile file
        else:
          echo file, " is good."

      except:
        failed.add file & ": "& getCurrentExceptionMsg()
        removeFile file

  if failed.len > 0:
    echo "Failed: ", failed

