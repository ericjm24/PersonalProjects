# -*- coding: utf-8 -*-
"""
Created on Mon Aug 12 14:07:36 2019

@author: ericj
"""

import requests as rq
import time
#import numpy as np
#import pandas as pd
#import csv
from math import ceil

LIM = 1000
from config import noaa_key, noaa_url, noaa_time
headers = {'token':noaa_key}

def get(inp, limit = None, *args, **kwargs):
    time.sleep(noaa_time)
    if limit is None:
        return get(inp, limit = get(inp, limit='count', *args, **kwargs), *args, **kwargs)
    url = noaa_url + inp + '?'
    for k,v in kwargs.items():
        url += str(k) + '=' + str(v) + '&'
    if type(limit) == str:
        if limit == 'response':
            return rq.get(url, headers=headers)
        elif limit == 'meta':
            return rq.get(url, headers=headers).json()['metadata']['resultset']
        elif limit == 'count':
            return get(inp, limit='meta', *args, **kwargs)['count']
        elif limit == 'all':
            count = get(inp, limit='count', *args, **kwargs)
            return get(inp, limit=count-kwargs.get('offset', 0), *args, **kwargs)
    
    elif limit <= 1000:
        url += 'limit=' + str(round(limit))
        response = rq.get(url, headers=headers)
        return response.json()['results']
    else:
        num_pages = ceil(limit/1000)
        t = 0
        out = []
        while t < num_pages:
            print(" ".join(["Retrieving page", str(t+1), "of", str(num_pages)]))
            kwargs['offset'] = t*LIM + 1
            if t == num_pages-1:
                temp = get(inp, limit=limit - t*LIM, *args, **kwargs)
            else:
                temp = get(inp, limit=LIM, *args, **kwargs)
            if type(temp) == list:
                out += temp
            else:
                out.append(temp)
            
            t += 1
            time.sleep(noaa_time)
        
        return out
