import nake

const
  serverExe = "server"
  launcherExe = "launcher"
  
  releaseDefines = "-d:release" 

  games = ["pong"]

task "build-server","build the server":
  shell "nimrod c", serverExe
task "build-launcher","build the launcher":
  shell "nimrod c", launcherExe

task "build-both","run both of those ^":
  runTask("build-server")
  runTask("build-launcher")

task "build-games", "build all of the games in src/games individually":
  var failed: seq[string] = @[]
  let dir = getCurrentDir()
  withDir("src/games"):
    for game in games:
      if not shell("nimrod c", "-p:..", "-d:useAllegro", game):
        failed.add game
      else:
        moveFile game, dir/game

  if failed.len > 0:
    echo "Failed to build: ", failed
  else:
    echo "All games built bro."
task "release","":
  shell "nimrod c", releaseDefines, launcherExe
