import nake, strutils

const
  babel_dependencies = ["enet","allegro5","fowltek","signals"] # oh yes

  binDir = "bin"

  launcherExe = binDir / "launcher"
  serverExe = binDir / "server"
  
  releaseDefines = "-d:release"
  srcDir = "src" # assume bin/ src/ assets/ layout
  gamesDir = "games" 
  paths = "-p:\""& srcDir& "\" -p:\""& gamesDir & "\" -p:\""& (srcDir/"net")& "\""
  standardDefines = "-d:useEnet --deadCodeElim:on " & paths 
  guiDefines = "-d:useAllegro"

  games = ["pong", "gui_designer"]
let
  gameImports = games.map(proc(x:string):string="--import:"& (gamesDir / x)).join" "


task "build-launcher","build the launcher":
  dire_shell "nimrod c", guiDefines, standardDefines, gameImports, launcherExe

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
  for game in games:
    let game_file = gamesDir/ game
    if not shell(
        "nimrod c", standardDefines, guiDefines,
        gameFile ):
      failed.add game
    else:
      moveFile game_file, binDir/game

  echo "$1 / $2 games built successfully.".format(
    games.len - failed.len, games.len )
  if failed.len > 0:
    echo "  Failures: ", failed


task "dependencies", "install/update them dependencies": 
  var failed:seq[string] = @[]
  for pkg in ["enet","allegro5","fowltek"]:
    if not shell( "babel install -y", pkg ):
      failed.add pkg
  
  if failed.len > 0: echo "Failed: ", failed
