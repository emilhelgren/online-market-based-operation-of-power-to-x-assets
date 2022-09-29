
using Gurobi
using JuMP
using DataFrames
using CSV

include("data_loader.jl")

lambda_H = 40

periods = collect(1:730)

#--------------RESULTS FROM MINIMIZING DEVIATION
q_forecast_calculated = [0.7770338357162985, 0.03580588292933596, 0.016086189924938307, -0.0074103664477346435, -1.5136952354991787e-5]
q_intercept_calculated = -0.2673501276620584


#--------------------------------------------------------------------------------------------------
#Declare Gurobi model
std_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(std_model, 0<=E_sold[t in periods])
@variable(std_model, 0<=E_bought[t in periods])
@variable(std_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(std_model, E_T[t in periods])
@variable(std_model, q_F[1:2])
@variable(std_model, E_forecast[t in periods])

#Maximize profit
@objective(std_model, Max, 
    1/length(periods) *
    sum(
        lambda_F[t] * (E_forecast[t]*q_F[1] + q_F[2])
        + lambda_UP[t] * E_sold[t]
        - lambda_DW[t] * E_bought[t]
    for t in periods)
    )


#Max capacity
@constraint(std_model, wind_capacity[t in periods], max_wind_capacity >= E_forecast[t] * q_F[1] + q_F[2])

@constraint(std_model, wind_min[t in periods], 0 <= E_forecast[t] * q_F[1] + q_F[2])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(std_model, trade[t in periods], E_real[t] - (E_forecast[t] * q_F[1] + q_F[2]) == E_T[t])

@constraint(std_model, selling1[t in periods], E_sold[t] >= E_T[t])
@constraint(std_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
@constraint(std_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

@constraint(std_model, buying1[t in periods], E_bought[t] >= -E_T[t])
@constraint(std_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
@constraint(std_model, buying3[t in periods], E_bought[t] <= M*(b[t]))

@constraint(std_model, forecast[t in periods], E_forecast[t] == sum(q_forecast_calculated[i]*x[t, i]*max_wind_capacity for i in collect(1:n_features)) + q_intercept_calculated)



optimize!(std_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(std_model))
print("\n\n")

print("\nqF: $(value(q_F[1])),  $(value(q_F[2])))")
print("\n\n")
for t in collect(1:10)
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forecasted production: $(value(E_forecast[t]))")
    print("\n Forward price: $(lambda_F[t])")
    print("\n Forward bid: $(value(E_forecast[t]*q_F[1] + q_F[2]))")
    print("\n Buying price: $(sum(lambda_DW[t]))")
    print("\n Selling price: $(sum(lambda_UP[t]))")

    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")
end

print("\n\n")
print("Objective value after training $(length(periods)/730) months\n")
print(objective_value(std_model))
print("\n\n")


print("\nqF: $(value(q_F[1])),  $(value(q_F[2]))")
print("\n")
print("\nMean forward price: $(mean(lambda_F[periods]))")


print("\n")
print("Total bought: $(sum(value.(E_bought)))")

print("\n")
print("Total sold: $(sum(value.(E_sold)))")

# Hydrogen:
# 18276.44967806111

# No hydrogen:
# 15448.119440720035