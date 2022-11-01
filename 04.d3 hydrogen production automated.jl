
using Gurobi
using JuMP
using DataFrames
using CSV

include("99.period_selector.jl")

# lambda_H = 40




function get_training_period(current_validation_step, window_size)
    month = 730
    last_time_step = 8760 - month + current_validation_step
    print("Tjek lige collect: $(last_time_step-(month*window_size)):$(last_time_step)\n")
    return collect(last_time_step-(month*window_size):last_time_step)
end

function get_offset(current_validation_step, window_size)
    month = 730
    last_time_step = 8760 - month + current_validation_step
    print("Tjek lige offset: $(last_time_step-(month*window_size))\n")
    return last_time_step - (month * window_size)
end

function train_model(periods, offset)
    #Declare Gurobi model
    elec_model = Model(Gurobi.Optimizer)


    using_features = true
    if (using_features)
        #--------------RESULTS FROM MINIMIZING DEVIATION
        q_forecast_calculated = [0.7770338357162985, 0.03580588292933596, 0.016086189924938307, -0.0074103664477346435, -1.5136952354991787e-5]
        q_intercept_calculated = -0.2673501276620584
        E_forecast = zeros(length(periods))
        for (t, v) in enumerate(periods)
            E_forecast[t] = sum(q_forecast_calculated[i] * x[v, i] * max_wind_capacity for i in collect(1:n_features)) + q_intercept_calculated
        end
    else
        E_forecast = forecast .* nominal_wind_capacity
    end

    #Definition of variables
    @variable(elec_model, 0 <= E_sold[t in periods])
    @variable(elec_model, 0 <= E_bought[t in periods])
    @variable(elec_model, E_adj[t in periods])
    @variable(elec_model, 0 <= E_adj_abs[t in periods])
    @variable(elec_model, b[t in periods], Bin) # Binary variable indicating if we are buying (1) or selling (0)
    @variable(elec_model, E_T[t in periods])
    @variable(elec_model, q_F[1:2])

    @variable(elec_model, 0 <= forward_bid[t in periods])

    #Maximize profit
    @objective(elec_model, Max,
        # 1 / length(periods) *
        sum(
            lambda_F[t+offset] * forward_bid[t]
            + lambda_H * E_adj[t]
            + lambda_UP[t+offset] * E_sold[t]
            -
            lambda_DW[t+offset] * E_bought[t]
            for t in periods)
    )

    #Max capacity
    @constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= forward_bid[t])

    @constraint(elec_model, adj_capacity_up[t in periods], E_adj[t] <= max_elec_capacity)
    @constraint(elec_model, adj_capacity_dw[t in periods], 0 <= E_adj[t])

    @constraint(elec_model, wind_min[t in periods], 0 <= forward_bid[t])

    # Power SOLD == POSITIVE, BOUGHT == NEGATIVE
    @constraint(elec_model, trade[t in periods], E_real[t] - forward_bid[t] - E_adj[t] == E_T[t])

    @constraint(elec_model, selling1[t in periods], E_sold[t] >= E_T[t])
    @constraint(elec_model, selling2[t in periods], E_sold[t] <= E_T[t] + M * b[t])
    @constraint(elec_model, selling3[t in periods], E_sold[t] <= M * (1 - b[t]))

    @constraint(elec_model, buying1[t in periods], E_bought[t] >= -E_T[t])
    @constraint(elec_model, buying2[t in periods], E_bought[t] <= -E_T[t] + M * (1 - b[t]))
    @constraint(elec_model, buying3[t in periods], E_bought[t] <= M * (b[t]))

    @constraint(elec_model, absolute3a[t in periods], E_adj[t] <= E_adj_abs[t])
    @constraint(elec_model, absolute3b[t in periods], E_adj[t] >= -E_adj_abs[t])

    @constraint(elec_model, rational_bidding[t in periods], forward_bid[t] == lambda_F_checker[t+offset] * (E_forecast[t] * q_F[1] + q_F[2]))

    optimize!(elec_model)

    print("\n\n")
    print("We have now trained a model based on $(length(periods)/730) months of data!")

    print("\n\n")


    return value(q_F[1]), value(q_F[2])
end

# q1, q2 = train_model(collect(1:730), 0)
# print("FÆRDIG")
# print("q1: $q1")
# print("q2: $q2")

# print("Tjek lige training period: $(get_training_period(1, 1))")
# q1_1, q2_1 = train_model(get_training_period(v, 1), 8760 - month)
# get_training_period(700, 11)
qs_1_month = []
qs_6_month = []
qs_11_month = []
month = 730
# validation_steps = collect(8760-month:8760)
validation_steps = collect(1:month)
for v in validation_steps
    print("\nCurrently looking at time step $v")
    if (v % 24 == 0)
        print("\nAnother day has passed! Retraining the models...\n")
        base_offset = 8760 - month + v
        q1_1, q2_1 = train_model(collect(1:month), base_offset - month)
        q1_6, q2_6 = train_model(collect(1:month*6), base_offset - (month * 6))
        # q1_11, q2_11 = train_model(collect(1:month*11), base_offset - (month * 11))
        push!(qs_1_month, q1_1, q2_1)
        push!(qs_6_month, q1_6, q2_6)
        # push!(qs_11_month, q1_11, q2_11)
    end
end
# # #---------------------------EXPORT RESULTS--------------------------------
include("98.data_export.jl")
# hydrogen_produced = [value(E_adj[t]) for t in periods]
data = [qs_1_month, qs_6_month, qs_11_month]
names = ["One month window", "Six month window", "Eleven month window"]
filename = "validation_results_03"
easy_export(data, names, filename)

