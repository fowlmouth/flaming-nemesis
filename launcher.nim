import gamestates, lobby

# games
import games/pong, games/gui_designer


var app = newGSM(800,600, "hello")
app.push lobbyGS
app.run


