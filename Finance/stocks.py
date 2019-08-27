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

def read_sector(sector):
    path = 'Data/' + sector.title().replace(" ","_") + '_data.csv'
    try:
        dat = pd.read_csv(path)
        dat['date'] = dat['date'].astype('datetime64[ns]')
        num_ticks = 0
        for col in dat.columns:
            if "Unnamed" in col:
                dat.drop(columns=col, inplace=True)
            elif col != "date" and col != "type":
                num_ticks += 1
        print("Found data on " + str(num_ticks) + " companies.")
    except:
        dat = None
        print("No data found.")

    return dat

def get_sector(sector):
    path = 'Data/' + sector.title().replace(" ", "_") + '_data.csv'
    dat = read_sector(sector)
    tickers = []
    if dat is not None:
        for col in dat.columns:
            if col != "date" and col != "tyoe":
                tickers.append(col)

    k = 1
    companies = pd.read_csv("Resources/companies.csv")
    companies = companies.groupby('Sector').get_group(sector)
    for row in companies.itertuples():
        if k > 400:
            break
        if dat is not None:
            if row.Symbol in tickers:
                continue
        print(row.Name + ' (' + row.Symbol +')')
        try:
            temp = get_pd(func='time series daily', symbol=row.Symbol, outputsize='full')
            temp = finance_series(temp, title=row.Symbol)
            k += 1
            print(len(temp))
            print("k =", k)
            if len(temp) < 1000:
                continue
            if dat is None:
                dat = temp
            else:
                dat = pd.merge(dat, temp, how='outer', on=['date', 'type'])

            tickers.append(row.Symbol)
            if not k % 10:
                dat.to_csv(path)
                print("**********\nSAVING\n**********")
        except:
            None

        time.sleep(15)

    dat.to_csv(path)

def print_sectors(sector=None):
    if sector is None:
        print(pd.read_csv("Resources/companies.csv").groupby("Sector")["Symbol"].count())
    else:
        try:
            sector = sector.replace("_"," ").title()
            comps = pd.read_csv("Resources/companies.csv").groupby("Sector")
            print(comps.get_group(sector).groupby("Industry")["Symbol"].count())
        except:
            print("Sector not found.")
            print(pd.read_csv("Resources/companies.csv").groupby("Sector")["Symbol"].count())
