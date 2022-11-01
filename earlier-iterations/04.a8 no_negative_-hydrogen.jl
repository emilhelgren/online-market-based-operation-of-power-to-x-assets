
using Gurobi
using JuMP
using DataFrames
using CSV

include("data_loader.jl")

# lambda_H = 40

periods = collect(1:730)




#--------------------------------------------------------------------------------------------------
#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)


using_features = true
if (using_features)
    #--------------RESULTS FROM MINIMIZING DEVIATION
    q_forecast_calculated = [0.7770338357162985, 0.03580588292933596, 0.016086189924938307, -0.0074103664477346435, -1.5136952354991787e-5]
    q_intercept_calculated = -0.2673501276620584
    @variable(elec_model, E_forecast[t in periods])
    @constraint(elec_model, forecast[t in periods], E_forecast[t] == sum(q_forecast_calculated[i] * x[t, i] * max_wind_capacity for i in collect(1:n_features)) + q_intercept_calculated)
else
    E_forecast = forecast .* nominal_wind_capacity
end

#Definition of variables
@variable(elec_model, 0 <= E_sold[t in periods])
@variable(elec_model, 0 <= E_bought[t in periods])
@variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[t in periods])
@variable(elec_model, q_F[1:2])

@variable(elec_model, 0 <= forward_bid[t in periods])

#Maximize profit
@objective(elec_model, Max,
    1 / length(periods) *
    sum(
        lambda_F[t] * forward_bid[t]
        +
        lambda_UP[t] * E_sold[t]
        -
        lambda_DW[t] * E_bought[t]
        for t in periods)
)


#Max capacity
@constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= forward_bid[t])

@constraint(elec_model, wind_min[t in periods], 0 <= forward_bid[t])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[t in periods], E_real[t] - forward_bid[t] == E_T[t])

@constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M * b[t])
@constraint(elec_model, selling3[t in periods], E_sold[t] <= M * (1 - b[t]))

@constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M * (1 - b[t]))
@constraint(elec_model, buying3[t in periods], E_bought[t] <= M * (b[t]))


@constraint(elec_model, rational_bidding[t in periods], forward_bid[t] == (E_forecast[t] * q_F[1] + q_F[2]))
# @constraint(elec_model, rational_bidding[t in periods], forward_bid[t] == lambda_F_checker[t] * (E_forecast[t] * q_F[1] + q_F[2]))


optimize!(elec_model)


print("First line print fix")


for t in collect(100:110)
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forecasted production: $(value(E_forecast[t]))")
    print("\n Forward price: $(lambda_F[t])")
    print("\n Calculated bid: $(value(E_forecast[t]*q_F[1] + q_F[2]))")
    print("\n Forward bid actual: $(value(forward_bid[t]))")
    # print("\n Hydrogen consumption: $(value(E_forecast[t]*q_H[1] + q_H[2]))")
    # print("\n Adjustment: $(value(E_adj[t]))")
    # print("\n Absolute value adjustment: $(value(E_adj_abs[s]))")
    # print("\n Are we buying?: $(value(b[s]))")
    print("\n Buying price: $(sum(lambda_DW[t]))")
    print("\n Selling price: $(sum(lambda_UP[t]))")

    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")
end

obj_values = []
for t in eachindex(periods)
    act_obj = lambda_F[t] * value(forward_bid[t]) + lambda_UP[t] * value(E_sold[t]) - lambda_DW[t] * value(E_bought[t])
    push!(obj_values, act_obj)
end

print("\n\n")
print("Objective value after training $(length(periods)/730) months\n")
print(objective_value(elec_model))
print("\n\n")


print("\nqF: $(value(q_F[1])),  $(value(q_F[2]))")
# print("\nqH: $(value(q_H[1])),  $(value(q_H[2]))")
print("\n")
print("\nMean forward price: $(mean(lambda_F[periods]))")
print("\nHydrogen price: $(lambda_H)")

print("\n")
print("Total bought: $(sum(value.(E_bought)))")

print("\n")
print("Total sold: $(sum(value.(E_sold)))")

print("\n")

# print("Hydrogen produced: $(sum(value(E_adj[t]) for t in periods))")

#---------------------------EXPORT RESULTS--------------------------------
include("98.data_export.jl")
# hydrogen_produced = [value(E_adj[t]) for t in periods]
data = [lambda_F, value.(forward_bid), value.(E_sold), value.(E_bought), obj_values]
names = ["Forward price", "Forward bid", "Power sold", "Power bought", "Objective values"]
filename = "RES_04.a8"
easy_export(data, names, filename)



# Hydrogen price
# 35.199999999999996