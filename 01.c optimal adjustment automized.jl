
using Gurobi
using JuMP
using DataFrames
using CSV

include("data_loader.jl")



# lambda_F = [0.94423281, 1.17482697, 0.68934189, 1.50722456, 1.13033861,
# 1.55988187, 0.8699497 , 0.819744  , 1.32419046, 0.7800745 ] # mean = 1.079980537
# lambda_H = 1.08

# lambda_UP = [min(l*0.8 + randn()/10, l) for l in lambda_F]
# lambda_DW = [max(l*1.2 + randn()/10, l) for l in lambda_F]



function optimize_single(h_price)
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

    #Maximize profit
    @objective(elec_model, Max, 
        1/length(periods) *
        sum(
            lambda_F[t] * (E_forecast[t]*q_F)
            + h_price * (E_forecast[t]*q_H + E_adj[t])
            - E_adj_abs[t] * adj_penalty
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

    optimize!(elec_model)
    return [value(q_F), value(q_H), sum(value.(E_bought)), sum(value.(E_sold)), sum(value.(E_adj_abs)), sum(value.(E_adj)), objective_value(elec_model), h_price]
end




function optimize_series(n_prices, h_prices)
    results = []
    for i in 1:n_prices
        # [q_F, q_H, total_bought, total_sold, total_adjusment, net_adjustment, obj_value, h_price]
        result = optimize_single(h_prices[i])
        push!(results, result)
    end
    return results
end

periods = collect(1:10)
n_prices = 10
h_prices = [40 + i*1 for i in 1:n_prices]

results = optimize_series(n_prices, h_prices)

for result in results
    print("\n\n")
    print("\nHydrogen price: $(result[8])")
    print("\nCheck q_F: $(result[1])")
    print("\nCheck q_H: $(result[2])")
    print("\nCheck total_bought: $(result[3])")
    print("\nCheck total_sold: $(result[4])")
    print("\nCheck total_adjusment: $(result[5])")
    print("\nCheck net_adjustment: $(result[6])")
    print("\nCheck obj_value: $(result[7])")


end