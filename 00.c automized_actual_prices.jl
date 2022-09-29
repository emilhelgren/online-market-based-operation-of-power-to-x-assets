
using Gurobi
using JuMP
# using printf

# Wind forecast


include("data_loader.jl")




M = 12.0
rho = 1
periods = collect(1:10)

function optimize_single(h_price)


    #Declare Gurobi model
    elec_model = Model(Gurobi.Optimizer)

    #Definition of variables
    @variable(elec_model, 0<=E_sold[t in periods])
    @variable(elec_model, 0<=E_bought[t in periods])
    @variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
    @variable(elec_model, E_T[t in periods])
    @variable(elec_model, q_F)
    @variable(elec_model, q_H)

    #Maximize profit
    @objective(elec_model, Max, 
        1/10 *
        sum(
            lambda_F[t] * (x[t]*q_F)
            + h_price * rho * (x[t]*q_H)
            + lambda_UP[t] * E_sold[t]
            - lambda_DW[t] * E_bought[t]
        for t in periods)
        )


    #Max capacity
    @constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= x[t] * q_F)
    @constraint(elec_model, elec_capacity[t in periods], max_elec_capacity >= x[t] * q_H)

    @constraint(elec_model, wind_min[t in periods], 0 <= x[t] * q_F)
    @constraint(elec_model, elec_min[t in periods], 0 <= x[t] * q_H)

    # Power SOLD == POSITIVE, BOUGHT == NEGATIVE
    @constraint(elec_model, trade[t in periods], E_real[t] - (x[t] * q_F) - (x[t] * q_H) == E_T[t])

    @constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
    @constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M*b[t])
    @constraint(elec_model, selling3[t in periods], E_sold[t] <= M*(1-b[t]))

    @constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
    @constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M*(1-b[t]))
    @constraint(elec_model, buying3[t in periods], E_bought[t] <= M*(b[t]))

    optimize!(elec_model)

    return [value(q_F), value(q_H)]
end

function optimize_series(n_prices, h_prices)
    qs = []
    for i in 1:n_prices
        q = optimize_single(h_prices[i])
        push!(qs, q)
    end
    return qs
end

n_prices = 40
h_prices = [45 + i*0.1 for i in 1:n_prices]
qs = optimize_series(n_prices, h_prices)

print("\n\n\n")
print("Check qs:")
print("\n\n")
for i in 1:n_prices
    print("\nHydrogen price: $(round(h_prices[i], digits=2)), q: $(round.(qs[i], digits=4))")
end

# print("\n\n\n")
# print(h_prices)
# print("\n\n\n")
# print(qs)
 

