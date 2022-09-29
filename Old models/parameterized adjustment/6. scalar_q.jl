
using Gurobi
using JuMP
using DataFrames
using CSV

include("data_loader.jl")


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_sold[t in periods])
@variable(elec_model, 0<=E_bought[t in periods])
@variable(elec_model, E_adj[t in periods])
@variable(elec_model, 0<=E_adj_abs[t in periods])
@variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[t in periods])
@variable(elec_model, q_F)
@variable(elec_model, q_H)
# q = [0.8333333333333334, 0.01574658166666672]
@variable(elec_model, q_adj)

#Maximize profit
@objective(elec_model, Max, 
    1/10 *
    sum(
        lambda_F[t] * (E_forecast[t]*q_F)
        + lambda_H * (E_forecast[t]*q_H + E_adj[t])
        - E_adj_abs[t] * 10
        + lambda_UP[t] * E_sold[t]
        - lambda_DW[t] * E_bought[t]
    for t in periods)
    )


#Max capacity
@constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= E_forecast[t] * q_F)
@constraint(elec_model, elec_capacity[t in periods], max_elec_capacity >= E_forecast[t] * q_H)

@constraint(elec_model, adj_capacity_up[t in periods], E_adj[t] <= max_elec_capacity - E_forecast[t] * q_H)
@constraint(elec_model, adj_capacity_dw[t in periods], -E_forecast[t] * q_H <= E_adj[t])

@constraint(elec_model, wind_min[t in periods], 0 <= E_forecast[t] * q_F)
@constraint(elec_model, elec_min[t in periods], 0 <= E_forecast[t] * q_H)

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[t in periods], E_real[t] - (E_forecast[t] * q_F) - (E_forecast[t] * q_H) - E_adj[t] == E_T[t])

@constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(elec_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(elec_model, buying3[t in periods], E_bought[t] <= M*(b[t]))


@constraint(elec_model, absolute3a[t in periods], E_adj[t] <= E_adj_abs[t])
@constraint(elec_model, absolute3b[t in periods], E_adj[t] >= -E_adj_abs[t])


# q_adj * (E_forecast[t] * q[1]) - (E_forecast[t] * q[2]) <--- Gør det ikke-convext, hvis q ikke er fixed
# Så i stedet laver vi det som ekstra parmetre direkte på E_real, i håb om at q[1] og q[2] implicit bliver optimeret for muligheden for at justere, som vil være bedre end hvis de bare blev fixed
# price_norm = sum(lambda_F)/length(prices)
# prod_norm = sum(E_real)/length(E_real)
@constraint(elec_model, adjustment_parameter[t in periods], E_adj[t] == q_adj*E_real[t]) 

# @constraint(elec_model, tester, 0.1 * sum( lambda_F * (E_forecast[t]*q[1]) + lambda_H * (E_forecast[t]*q[2] + E_adj[s]) - E_adj_abs[s] * 0.01 + 0.1 * sum( lambda_UP[s][s2] * E_sold[s] - lambda_DW[s][s2] * E_bought[s] for s2 in scenarios2) for s in scenarios) <= 9999)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nqF: $(value(q_F))")
print("\nqH: $(value(q_H))")
print("\nqAdj: $(value(q_adj))")
print("\n\n")
for t in collect(1:10)
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forward price: $(lambda_F[t])")
    print("\n Forward bid: $(value(E_forecast[t]*q_F))")
    print("\n Hydrogen consumption: $(value(E_forecast[t]*q_H))")
    print("\n Adjustment: $(value(E_adj[t]))")
    # print("\n Absolute value adjustment: $(value(E_adj_abs[s]))")
    # print("\n Are we buying?: $(value(b[s]))")
    print("\n Buying price: $(sum(lambda_DW[t]))")
    print("\n Selling price: $(sum(lambda_UP[t]))")

    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")
end

print("\n\n")
print("Objective value after training $(length(periods)/730) months\n")
print(objective_value(elec_model))
print("\n\n")


print("\nqF: $(value(q_F))")
print("\nqH: $(value(q_H))")
print("\nqAdj: $(value(q_adj))")

print("\nMean forward price: $(mean(prices[periods]))")

print("\n\n")

print("\n\n")
print("Total bought: $(sum(value.(E_bought)))")

print("\n\n")
print("Total sold: $(sum(value.(E_sold)))")
# Objective value
# 5.637708873775014


# q: [0.9753807321417984, 0.0]
# q_adj: [1.6960710308889495, -1.2061924773373642]
# q_adj: [1.6960710308889495, -1.2061924773373642]