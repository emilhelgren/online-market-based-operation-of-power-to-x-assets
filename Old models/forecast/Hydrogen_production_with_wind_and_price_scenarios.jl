
using Gurobi
using JuMP
# using printf

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

E_forecast = [e*1.2 + 2 for e in E_real]
# E_forecast[10] = 8

periods = collect(1:10)
scenarios = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]


lambda_F = [
    1.4650081,      # 1
    1.42289899,     # 2 
    1.35264851,     # 3 
    1.4596971,      # 4 
    1.30463661,     # 5 
    1.2615536 ,     # 6 
    1.06535204,     # 7
    1.24963798,     # 8 
    5,              # 9
    1.15056654]     # 10
lambda_H = 1.3
lambda_UP = [0.8*l for l in lambda_F]    
lambda_DW = [1.5*l for l in lambda_F]    



max_wind_capacity = 10
max_elec_capacity = 10
M = 12


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_sold[t in periods])
@variable(elec_model, 0<=E_bought[t in periods])
@variable(elec_model, E_adj[t in periods])
@variable(elec_model, 0<=E_adj_abs[t in periods])
@variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[t in periods])
@variable(elec_model, q[i=1:2])

#Maximize profit
@objective(elec_model, Max, 
    sum(
        lambda_F[t] * (E_forecast[t]*q[1])
        + lambda_H * (E_forecast[t]*q[2] + E_adj[t])
        + lambda_UP[t] * E_sold[t]
        - lambda_DW[t] * E_bought[t]
        - E_adj_abs[t] * 0.1
    for t in periods)
    )


#Max capacity
@constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= E_forecast[t] * q[1])
@constraint(elec_model, elec_capacity[t in periods], max_elec_capacity >= E_forecast[t] * q[2])

@constraint(elec_model, adj_capacity_up[t in periods], E_adj[t] <= max_elec_capacity - E_forecast[t] * q[2])
@constraint(elec_model, adj_capacity_dw[t in periods], -E_forecast[t] * q[2] <= E_adj[t])

@constraint(elec_model, wind_min[t in periods], 0 <= E_forecast[t] * q[1])
@constraint(elec_model, elec_min[t in periods], 0 <= E_forecast[t] * q[2])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[t in periods], E_real[t] - (E_forecast[t] * q[1]) - (E_forecast[t] * q[2]) - E_adj[t] == E_T[t])

@constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(elec_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(elec_model, buying3[t in periods], E_bought[t] <= M*(b[t]))


@constraint(elec_model, absolute3a[s in scenarios], E_adj[s] <= E_adj_abs[s])
@constraint(elec_model, absolute3b[s in scenarios], E_adj[s] >= -E_adj_abs[s])

# @constraint(elec_model, tester[s in scenarios], E_adj_abs[s] <= 0.8)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value.(q))")
print("\n\n")
for t in periods
    obj_s = 0
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forward bid: $(value(E_forecast[t]*q[1]))")
    print("\n Hydrogen consumption: $(value(E_forecast[t]*q[2]))")
    print("\n Adjustment: $(value(E_adj[t]))")
    print("\n Absolute value adjustment: $(value(E_adj_abs[t]))")
    print("\n Are we buying?: $(value(b[t]))")
    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")

end







 