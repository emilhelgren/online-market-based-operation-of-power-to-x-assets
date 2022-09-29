
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

E_forecast = [e*1.2 for e in E_real]

periods = collect(1:10)
scenarios = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]


lambda_F = 1.3
lambda_UP = 0.7
lambda_DW = 1.7

phi_p = lambda_F - lambda_UP
phi_m = lambda_DW - lambda_F

max_wind_capacity = 10
M = 12


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_sold[t in periods])
@variable(elec_model, 0<=E_bought[t in periods])
@variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[t in periods])
@variable(elec_model, q)

#Maximize profit
@objective(elec_model, Max, 
    sum(
        lambda_F * (E_forecast[t]*q)
        + lambda_UP * E_sold[t]
        - lambda_DW * E_bought[t]
    for t in periods)
    )


#Max capacity
@constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= E_forecast[t] * q)

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[t in periods], E_real[t] - (E_forecast[t] * q) == E_T[t])

@constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(elec_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(elec_model, buying3[t in periods], E_bought[t] <= M*(b[t]))

# @constraint(elec_model, tester[s in scenarios], E_adj_abs[s] <= 0.8)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value(q))")
print("\n\n")
for t in periods
    obj_s = 0
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forward bid: $(value(E_forecast[t]*q))")
    print("\n Are we buying?: $(value(b[t]))")
    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")

end


#=
1: 



=# 






 