
using Gurobi
using JuMP
# using printf


periods = collect(1:10)
scenarios = collect(1:10)
scenarios2 = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]

E_real = [
    5,      # 1
    4.9,    # 2
    5.4,    # 3
    5.3,    # 4
    5.6,    # 5
    6.1,    # 6
    4.8,    # 7
    3,    # 8
    7,      # 9
    6.3       # 10
]

# E_forecast = sum(E_real)/10

noises = [0.3424078581323642 , -0.46135542013446856
, -1.9396549687255036
, -1.1425097709739453
, -0.18599112079633331
, -0.04624286256162224
, -0.15995961815435117
, -1.671875283686103
, -0.9101485767326017
, -0.9992440285893289]

E_forecast = []
for i in periods
    # noise = randn()
    # print("\nNoise is: $noise")
    push!(E_forecast, E_real[i]+noises[i])
end





lambda_F = [0.94423281, 1.17482697, 0.68934189, 1.50722456, 1.13033861,
1.55988187, 0.8699497 , 0.819744  , 1.32419046, 0.7800745 ] # mean = 1.079980537
lambda_H = 1.079980537



lambda_UP = [l*0.6 for l in lambda_F]
lambda_DW = [l*1.6 for l in lambda_F]


max_wind_capacity = 10.0
max_elec_capacity = 10.0
M = 12.0


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_sold[t in periods])
@variable(elec_model, 0<=E_bought[t in periods])
# @variable(elec_model, E_adj[t in periods])
# @variable(elec_model, 0<=E_adj_abs[t in periods])
@variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[t in periods])
@variable(elec_model, q[i=1:2])
# q = [0.8333333333333334, 0.01574658166666672]
# @variable(elec_model, q_adj[i=1:2])

#Maximize profit
@objective(elec_model, Max, 
    1/10 *
    sum(
        lambda_F[t] * (E_forecast[t]*q[1])
        + lambda_H * (E_forecast[t]*q[2])
        # - E_adj_abs[t] * 0.01
        + lambda_UP[t] * E_sold[t]
        - lambda_DW[t] * E_bought[t]
    for t in periods)
    )


#Max capacity
@constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= E_forecast[t] * q[1])
@constraint(elec_model, elec_capacity[t in periods], max_elec_capacity >= E_forecast[t] * q[2])

# @constraint(elec_model, adj_capacity_up[t in periods], E_adj[t] <= max_elec_capacity - E_forecast[t] * q[2])
# @constraint(elec_model, adj_capacity_dw[t in periods], -E_forecast[t] * q[2] <= E_adj[t])

@constraint(elec_model, wind_min[t in periods], 0 <= E_forecast[t] * q[1])
@constraint(elec_model, elec_min[t in periods], 0 <= E_forecast[t] * q[2])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[t in periods], E_real[t] - (E_forecast[t] * q[1]) - (E_forecast[t] * q[2]) == E_T[t])

@constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(elec_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(elec_model, buying3[t in periods], E_bought[t] <= M*(b[t]))


# @constraint(elec_model, absolute3a[t in periods], E_adj[t] <= E_adj_abs[t])
# @constraint(elec_model, absolute3b[t in periods], E_adj[t] >= -E_adj_abs[t])


# q_adj * (E_forecast[t] * q[1]) - (E_forecast[t] * q[2]) <--- Gør det ikke-convext, hvis q ikke er fixed
# Så i stedet laver vi det som ekstra parmetre direkte på E_real, i håb om at q[1] og q[2] implicit bliver optimeret for muligheden for at justere, som vil være bedre end hvis de bare blev fixed
price_norm = 1.079980537
prod_norm = sum(E_real)/10
# @constraint(elec_model, adjustment_parameter[t in periods], E_adj[t] == q_adj[1]*E_real[t]/prod_norm + q_adj[2]*lambda_F[t]/price_norm) 

# @constraint(elec_model, tester, 0.1 * sum( lambda_F * (E_forecast[t]*q[1]) + lambda_H * (E_forecast[t]*q[2] + E_adj[s]) - E_adj_abs[s] * 0.01 + 0.1 * sum( lambda_UP[s][s2] * E_sold[s] - lambda_DW[s][s2] * E_bought[s] for s2 in scenarios2) for s in scenarios) <= 9999)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value.(q))")
print("\n\n")
for t in periods
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forward price: $(lambda_F[t])")
    print("\n Forward bid: $(value(E_forecast[t]*q[1]))")
    print("\n Hydrogen consumption: $(value(E_forecast[t]*q[2]))")
    # print("\n Adjustment: $(value(E_adj[t]))")
    # print("\n Absolute value adjustment: $(value(E_adj_abs[s]))")
    # print("\n Are we buying?: $(value(b[s]))")
    print("\n Buying price: $(sum(lambda_DW[t]))")
    print("\n Selling price: $(sum(lambda_UP[t]))")

    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")
end

print("\n\n")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value.(q))")
# print("\nq_adj: $(value.(q_adj))")

# Objective value
# 5.59936200839425


# q: [1.0344737556121708, 0.0]