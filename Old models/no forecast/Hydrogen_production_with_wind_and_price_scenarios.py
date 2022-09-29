
import pandas as pd
# from google.cloud import storage   
from multiprocessing.pool import ThreadPool
from pulp import *
import numpy as np
from datetime import datetime
from sympy import symbols, solve

scenarios = range(10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]
E_real = [
    5,      # 1
    4.9,    # 2
    5.4,    # 3
    5.3,    # 4
    5.6,    # 5
    6.1,    # 6
    4.8,    # 7
    6.3,    # 8
    7,      # 9
    3       # 10
]

lambda_F = [  
    1.23682342181504,       # 1
    1.2958367004583573,     # 2
    0.9175734914087309,     # 3
    1.1518437538018276,     # 4
    0.7942218447415529,     # 5
    0.7906571808126533,     # 6
    1.2623332988271592,     # 7
    1.0425405195765243,     # 8
    0.9499534019691998,     # 9
    0.9127300809417882      # 10
]

# Should always be less than lambda_F
lambda_UP = [l*0.9 for l in lambda_F]

# Should always be greater than lambda_F
lambda_DW = [l*1.1 for l in lambda_F]

rho = 0.9
rho_adj = 0
lambda_H = 1

max_wind_capacity = 10
max_elec_capacity = 8
M = 12

################# model  ##################
m = LpProblem("elec_model", LpMaximize)

E_F = LpVariable('forward_bid', 0)
E_H = LpVariable('hydrogen_bid', 0)
E_adj = LpVariable.dicts('hydrogen adjustment', (s for s in scenarios))
E_adj_abs = LpVariable.dicts('hydrogen adjustment absolue', (s for s in scenarios), 0)
E_sold = LpVariable.dicts('Power sold', (s for s in scenarios), 0)
E_bought = LpVariable.dicts('Power bought', (s for s in scenarios), 0)
b = LpVariable.dicts('buying binary', (s for s in scenarios), cat='Binary')
E_T = LpVariable.dicts('power traded', (s for s in scenarios))

m += lpSum( 
    ( 
        lambda_F * E_F
        + lambda_H * (E_H + E_adj[s])
        + lambda_UP * E_sold[s]
        - lambda_DW * E_bought[s]
        - rho_adj * E_adj_abs[s]
        ) * probs[s]
    for s in scenarios)

m += max_wind_capacity >= E_F
m += max_elec_capacity >= E_H

for s in scenarios:
    m += E_adj[s] <= max_elec_capacity - E_H
    m += -E_H <= E_adj[s]
    m += E_real[s] - E_F - E_H - E_adj[s] == E_T[s]
    m += E_sold[s] >= E_T[s]
    m += E_sold[s] <= E_T[s] + M*b[s]
    m += E_sold[s] <= M*(1-b[s])
    m += E_bought[s] >= -E_T[s]
    m += E_bought[s] <= -E_T[s] + M*(1-b[s])
    m += E_bought[s] <= M*b[s]
    m += E_adj[s] <= E_adj_abs[s]
    m += E_adj[s] >= -E_adj_abs[s]
    

# The problem is solved using PuLP's choice of Solver
status = m.solve()
#print(status)
# The status of the solution is printed to the screen
print("Status:", LpStatus[m.status])


# Each of the variables is printed with it's resolved optimum value
for v in m.variables():
    #print(f"vi kigger nu på: {v.name}")
    if (v.name == "forward_bid" or v.name == "hydrogen_bid"):
        print(v.name, "=", v.varValue)
        


for s in scenarios:
    print(f"\n\nFor period {s+1}")
    for v in m.variables():
        # print(v.name)
        if (v.name == f"hydrogen_adjustment_{s}"):
            print(f"Adjustment: {v.varValue}")
        if (v.name == f"hydrogen_adjustment_absolue_{s}"):
            print(f"Absolute adjustment: {v.varValue}")
        if (v.name == f"Power_sold_{s}"):
            print(f"Sold: {v.varValue}")
        if (v.name == f"Power_bought_{s}"):
            print(f"Bought: {v.varValue}")




