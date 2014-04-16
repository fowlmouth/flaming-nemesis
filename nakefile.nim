import nake, strutils

const
  serverExe = "server"
  launcherExe = "launcher"
  
  releaseDefines = "-d:release"
  standardDefines = "-d:useEnet --deadCodeElim:on" 
  guiDefines = "-d:useAllegro"

  games = ["pong", "gui_designer"]

  gameImports = games.map(proc(x:string):string="--import:games/$#" % x).join" "

task "build-server","build the server":
  dire_shell "nimrod c", guiDefines, standardDefines, gameImports, serverExe
task "build-launcher","build the launcher":
  dire_shell "nimrod c", guiDefines, standardDefines, gameImports, launcherExe

task "build-both","run both of those ^":
  runTask("build-server")
  runTask("build-launcher")

task "build-games", "build all of the games in src/games individually":
  var failed: seq[string] = @[]
  let 
    dir = getCurrentDir()
    srcDir = dir / "src"
  for game in games:
    let game_file = srcDir/"games"/game
    if not shell(
        "nimrod c", standardDefines, guiDefines, "-p:$#" % srcDir, game_file
        gameFile ):
      failed.add game
    else:
      moveFile game_file, dir/game

  if failed.len > 0:
    echo "Failed to build: ", failed
  else:
    echo "All games built bro."

task "release","":
  shell "nimrod c", 
    releaseDefines, standardDefines, guiDefines, 
    gameImports, launcherExe

task "dependencies", "install them dependencies": 
  var failed:seq[string] = @[]
  for pkg in ["enet","allegro5","fowltek"]:
    if not shell( "babel install", pkg ):
      failed.add pkg
  
  if failed.len > 0: echo "Failed: ", failed
