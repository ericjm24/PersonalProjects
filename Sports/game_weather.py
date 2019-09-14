import sportsreference.nfl.boxscore as boxscore
import noaa
from config import *
import requests

games = boxscore.Boxscores(1,2018,40)

stadiums = []
game_data = []
k = 0;
for key in games.games.keys():
    for game in games.games[key]:
        temp = boxscore.Boxscore(game[key])
        dat = {'stadium':temp.stadium, 'date':temp.date, 'time':temp.time}
        if temp.stadium not in stadiums:
            stadiums.append(stad)
            dat['stad_id'] = k
            k += 1
        else:
            dat['stad_id'] = stadiums.index(temp.stadium)

place_url = 'https://maps.googleapis.com/maps/api/place/findplacefromtext/json?input='
place_end = '&inputtype=textquery&key=' + gmaps_key
for stadium in stadiums:
    response = requests.get(place_url + stadium.replace(" ", "%20") + place_end)
    place_id = response.json()['candidates'][0]['place_id']
    response = requests.get(gmaps_url + 'place_id=' + place_id + '&key=' + gmaps_key)
    cords = response.json()['results'][0]['geometry']['location']
    lat = cords['lat']
    lng = cords['lng']
    extent = [str(lat-0.25), str(lng-0.25), str(lat)+0.25, str(lng+0.25)].join(',')
    dat = pd.DataFrame(noaa.get('stations', limit=None, extent=extent))
