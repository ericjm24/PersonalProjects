#For use with the alphavantage api.
#Documentation at https://www.alphavantage.co/documentation/

import requests as rq
import pandas as pd
import time
from config import alpha_key, alpha_time, alpha_url
import matplotlib.pyplot as plt

key_url = "&apikey=" + alpha_key

def get(func, *args, **kwargs):
    url = alpha_url + "?function=" + func.upper().replace(" ","_")
    for k,v in kwargs.items():
        url += '&' + str(k) + '=' + str(v)
    url += key_url
    print(url)
    response = rq.get(url)
    if response.status_code == 200:
        dat = response.json()
        keys = [k for k in dat.keys() if k.lower().replace(" ","") != 'metadata']
        assert len(keys)==1
        keys = keys[0]
        out = []
        for k,v in dat[keys].items():
            temp = {k2.split(". ")[-1] : v2 for k2, v2 in v.items()}
            temp['date'] = k
            out.append(temp)

        return out
    return response

def get_pd(func, *args, **kwargs):
    dat = pd.DataFrame(get(func, *args, **kwargs))
    dat["date"] = pd.to_datetime(dat["date"])
    for c in dat.columns:
        if c != 'date':
            dat[c] = dat[c].astype(float)
    return dat

def finance_series(data, title='value'):
    assert type(data) == pd.DataFrame
    out = None
    for col in data.columns:
        if col == 'date':
            continue
        temp = data[["date", col]]
        temp = temp.rename(columns={col:title})
        if out is None:
            out = temp.assign(type=col)
        else:
            out = out.append(temp.assign(type=col))
    return out

def plot(data, symbols="all", type='close', normalize = False, range = None, *args, **kwargs):
    data = data.groupby('type').get_group(type)
    if range is not None:
        data = data.iloc[range[0]:range[1],:]
    if symbols == 'all':
        symbols = [col for col in data.columns if (col != 'date' and col != 'type')]

    for symbol in symbols:
        if normalize == False:
            plt.plot(data['date'], data[symbol], label = symbol, *args, **kwargs)
        else:
            plt.plot(data['date'], data[symbol]/data[symbol].mean(), label = symbol, *args, **kwargs)
