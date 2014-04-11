import nake, strutils

const
  serverExe = "server"
  launcherExe = "launcher"
  
  releaseDefines = "-d:release"
  standardDefines = "--deadCodeElim:on" 

  games = ["pong", "gui_designer","skel"]
let
  gameImports = games.map(proc(x:string):string="--import:games/$#" % x).join" "

task "build-server","build the server":
  dire_shell "nimrod c", standardDefines, gameImports, serverExe
task "build-launcher","build the launcher":
  dire_shell "nimrod c", "-d:useAllegro", standardDefines, gameImports, launcherExe

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
    if not shell("nimrod c", standardDefines, 
        "-p:$#" % srcDir, "-d:useAllegro", game_file):
      failed.add game
    else:
      moveFile game_file, dir/game

  if failed.len > 0:
    echo "Failed to build: ", failed
  else:
    echo "All games built bro."

task "release","":
  shell "nimrod c", releaseDefines, gameImports, launcherExe
