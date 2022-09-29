
using Gurobi
using JuMP
using DataFrames
using CSV

include("data_loader.jl")

lambda_H = 40
adj_penalty = 0.01

periods = collect(1:730)

#--------------------------------------------------------------------------------------------------
#Declare Gurobi model
pi_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(pi_model, 0<=E_sold[t in periods])
@variable(pi_model, 0<=E_bought[t in periods])
@variable(pi_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(pi_model, E_T[t in periods])
@variable(pi_model, E_F[t in periods])
@variable(pi_model, E_H[t in periods])
@variable(pi_model, E_adj[t in periods])
@variable(pi_model, 0<=E_adj_abs[t in periods])
@variable(pi_model, E_forecast[t in periods])

#Maximize profit
@objective(pi_model, Max, 
    1/length(periods) *
    sum(
        lambda_F[t] * E_F[t]
        + lambda_H * (E_H[t] + E_adj[t])
        - E_adj_abs[t] * adj_penalty
        + lambda_UP[t] * E_sold[t]
        - lambda_DW[t] * E_bought[t]
    for t in periods)
    )


#Max capacity
@constraint(pi_model, wind_capacity[t in periods], max_wind_capacity >= E_F[t])
@constraint(pi_model, elec_capacity[t in periods], max_elec_capacity >= E_H[t])

@constraint(pi_model, adj_capacity_up[t in periods], E_adj[t] <= max_elec_capacity - (E_H[t]))
@constraint(pi_model, adj_capacity_dw[t in periods], -(E_H[t]) <= E_adj[t])

@constraint(pi_model, wind_min[t in periods], 0 <= E_F[t])
@constraint(pi_model, elec_min[t in periods], 0 <= E_H[t])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(pi_model, trade[t in periods], E_real[t] - (E_F[t]) - (E_H[t]) - E_adj[t] == E_T[t])

@constraint(pi_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(pi_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(pi_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(pi_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(pi_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(pi_model, buying3[t in periods], E_bought[t] <= M*(b[t]))


@constraint(pi_model, absolute3a[t in periods], E_adj[t] <= E_adj_abs[t])
@constraint(pi_model, absolute3b[t in periods], E_adj[t] >= -E_adj_abs[t])

@constraint(pi_model, forecast[t in periods], E_forecast[t] == sum(q_forecast_calculated[i]*x[t, i]*max_wind_capacity for i in collect(1:n_features)) + q_intercept_calculated)


optimize!(pi_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(pi_model))
print("\n\n")

print("\nqF: $(value(q_F[1])),  $(value(q_F[2])))")
print("\n\n")
for t in collect(710:720)
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forecasted production: $(value(E_forecast[t]))")
    print("\n Forward price: $(lambda_F[t])")
    print("\n Forward bid: $(value(E_F[t]))")
    print("\n Hydrogen consumption: $(value(E_H[t]))")
    print("\n Adjustment: $(value(E_adj[t]))")
    print("\n Buying price: $(sum(lambda_DW[t]))")
    print("\n Selling price: $(sum(lambda_UP[t]))")
    

    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")
end

print("\n\n")
print("Objective value after training $(length(periods)/730) months\n")
print(objective_value(pi_model))
print("\n\n")

print("\nMean forward price: $(mean(lambda_F[periods]))")


print("\n")
print("Total bought: $(sum(value.(E_bought)))")

print("\n")
print("Total sold: $(sum(value.(E_sold)))")

print("\n")
print("Total adjustment: $(sum(value.(E_adj_abs)))")
print("\n")
print("Net adjustment: $(sum(value.(E_adj)))")
print("\n")
print("Hydrogen produced: $(sum(value(q_H[1]*E_forecast[t] + q_H[2]) for t in periods))")
