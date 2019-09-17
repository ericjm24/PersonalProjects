import sportsreference.nfl.boxscore as boxscore
import noaa
from config import *
import requests
import pandas as pd
import datetime as dt
from sqlalchemy import create_engine

games = boxscore.Boxscores(1,2018,40)

stadiums = []
game_data = []
k = 0;
game_keys = []
final_data = None
for gameday in games.games.values():
    for game in gameday:
        game_keys.append(game['boxscore'])

for game_key in game_keys:
    try:
        game = boxscore.Boxscore(game_key)
        url = gplace_url + game.stadium.replace(" ", "%20") +'&key=' + gmaps_key
        response=requests.get(url)
        place_id = ""
        if response.status_code == 200:
            place_id = response.json()['candidates'][0]['place_id']
        if place_id:
            url = gmaps_url + place_id + '&key=' + gmaps_key
            response=requests.get(url)
            loc = response.json()['results'][0]['geometry']['location']
            lat = loc['lat']
            lng = loc['lng']
            extent = ",".join([str(lat-0.25), str(lng-0.25), str(lat+0.25), str(lng+0.25)])
            dat = pd.DataFrame(noaa.get('stations', limit=None, extent=extent))
            dat['latitude'] = dat['latitude'] - lat
            dat['longitude'] = dat['longitude'] - lng
            dat['dist'] = dat['latitude'].map(lambda x: x*x) + dat['longitude'].map(lambda y: y*y)
            stations = dat.sort_values('dist')['id']
            game_date = dt.datetime.strptime(game.date, "%A %b %d, %Y").strftime('%Y-%m-%d')
            for station in stations:
                try:
                    out = noaa.get('data', limit=1000, datasetid="GHCND",stationid = station, startdate = game_date, enddate=game_date)
                    break
                except:
                    None
            temp = {'game_id':game_key, 'home_team':game.home_abbreviation, 'away_team':game.away_abbreviation, 'winning_team':game.winning_abbr, 'date':game.date, 'time':game.time, 'weather_type':out[0]['datatype'], 'weather_value':out[0]['value'], 'station':out[0]['station']}
            print(temp)
            if final_data is None:
                final_Data = pd.DataFrame({k:[v] for k,v in temp.items()})
            else:
                final_data.append(temp)
    except:
        None

engine = create_engine('sqlite:///sports_weather.sqlite', echo=False)
final_data.to_sql('weather', con=engine)
