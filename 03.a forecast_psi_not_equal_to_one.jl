
using Gurobi
using JuMP
using DataFrames
using CSV

include("data_loader.jl")

lambda_H = 48

# periods = collect(1:10)


psi_up = lambda_F .- lambda_UP
psi_dw = lambda_DW .- lambda_F

#Declare Gurobi model
prediction_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(prediction_model, E_T[t in periods])
@variable(prediction_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(prediction_model, 0<=E_sold[t in periods])
@variable(prediction_model, 0<=E_bought[t in periods])
@variable(prediction_model, q_forecast[1:n_features])
@variable(prediction_model, q_intercept)

#Maximize profit
@objective(prediction_model, Min, 
    1/length(periods) *
    sum(
        psi_up[t] * E_sold[t]
        + psi_dw[t] * E_bought[t]
    for t in periods)
    )

# q_fixet = [1, 0, 0, 0, 0]
# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(prediction_model, trade[t in periods], E_real[t] - (sum(q_forecast[i]*x[t, i]*max_wind_capacity for i in collect(1:n_features)) + q_intercept) == E_T[t])

@constraint(prediction_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(prediction_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(prediction_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(prediction_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(prediction_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(prediction_model, buying3[t in periods], E_bought[t] <= M*(b[t]))

# @constraint(prediction_model, fixer1, q_forecast[1] == 1)
# @constraint(prediction_model, fixer2[i in collect(2:n_features)], q_forecast[i] == 0)
# @constraint(prediction_model, fixer3, q_intercept == 0)



optimize!(prediction_model)

print("\n")
print("\n")
for t in collect(100:110)
    print("\n")
    print("\n")
    print("\n")
    print("Realized production: $(E_real[t])")
    # print("\n")
    # print("Features: $(x[t,:])")
    print("\n")
    print("Bid: $(value(sum(q_forecast[i]*x[t, i]*max_wind_capacity for i in collect(1:n_features))))")
    print("\n")
    print("Traded: $(value(E_T[t]))")
    print("\n")
    print("Sold: $(value(E_sold[t]))")
    print("\n")
    print("Bought: $(value(E_bought[t]))")
    print("\n")
    print("Psi_up: $(psi_up[t])")
    print("\n")
    print("Psi_dw: $(psi_dw[t])")

end


print("\n\n\n")
print("Objective value: $(objective_value(prediction_model))")
print("\n")
print("Total sold: $(sum(value.(E_sold)))")

print("\n")
print("Total bought: $(sum(value.(E_bought)))")
print("\n")

print("q values: ")
print(value.(q_forecast))
print("\n")
print("intercept: $(value(q_intercept))")


#-------------------Results from training whole period
# All features and intercept:
# Objective value: 6.558094397661448

# All features no intercept:
# Objective value: 6.598354640216128

# Forecast feature and intercept:
# Objective value: 6.614853220410857

# Forecast feature no intercept:
# Objective value: 6.674292693574297

# Just guess forecast:
# Objective value: 13.987418223790428