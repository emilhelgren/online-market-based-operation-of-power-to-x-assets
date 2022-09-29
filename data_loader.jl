using DataFrames
using CSV

#--------------------------------------------------------------------------
#----------------------------------IMPORTS---------------------------------
#--------------------------------------------------------------------------
lambda_F = DataFrame(CSV.File("./data/forward.csv"))[:, 2]
# lambda_F = DataFrame(CSV.File("./data/2020/prices_formatted.csv"))[:,6]
lambda_UP = DataFrame(CSV.File("./data/balance_up.csv"))[:, 2]
lambda_DW = DataFrame(CSV.File("./data/balance_dw.csv"))[:, 2]

lambda_UP = [l*0.3 for l in lambda_F]
lambda_DW = [l*1.8 for l in lambda_F]

realized = DataFrame(CSV.File("./data/realized.csv"))[:, 2]
forecast = DataFrame(CSV.File("./data/forecasts.csv"))[:, 2]

# Features are:
# offshore_DK2 | offshore_DK1 | onshore_DK2 | onshore_DK1 | solar_DK2
x = DataFrame(CSV.File("./data/features.csv"))
# x = DataFrame(CSV.File("./data/features_with_realized.csv"))
x = x[:, 2:size(x)[2]]          # Remove first column which is just the index
n_features = size(x)[2]

include("hydrogen_prices.jl")

#--------------------------------------------------------------------------
#----------------------------MODEL PARAMETERS------------------------------
#--------------------------------------------------------------------------


MAKE_BALANCING_PRICES_MORE_RADICAL = true

if (MAKE_BALANCING_PRICES_MORE_RADICAL)
    lambda_UP = lambda_UP .- 10
    lambda_DW = lambda_DW .+ 10
end

function mean(arr)
    return sum(arr)/length(arr)
end

# Normalizing so values are in [0, 1.0]
max_value = max(maximum(realized), maximum(forecast))

realized = realized ./ max_value
forecast = forecast ./ max_value

nominal_wind_capacity = 10.0    # Random decision
max_elec_capacity = 10.0        # Random decision
adj_penalty = 0.000001          # Why is the specific value of this so important?

E_real = realized .* nominal_wind_capacity
# E_forecast = forecast .* nominal_wind_capacity

max_wind_capacity = nominal_wind_capacity * 1.3     # Random decision
M = max(max_wind_capacity, max_elec_capacity)


periods = collect(1:length(lambda_F))
periods = collect(1:730*2) # 730 is 1 month

# Random decision
# lambda_H = hydrogen_price       # 92.81682907199999
# lambda_H = mean(lambda_F)*1.9   
lambda_H = 48


#------------------------CHECK FEATURES FOR MISSING

# anymissing = false

# for i in collect(1:length(E_real))
#     for n in collect(1:n_features)
#         if (ismissing(x[i, n]))
#             print("Missing value at $(i)")
#             print("Missing value at $(i)")
#             print("Missing with feature $(n)")
#             print("Missing value at $(i)")
#             anymissing = true
#         end

#     end

# end
# if (!anymissing)
#     print("NO MISSING VALUES!")
# end

#------------------------CHECK PRICES FOR MISSING

# anymissing = false

# for i in collect(1:length(E_real))
#     if (ismissing(lambda_F[i]))
#         print("Missing value at $(i)")
#         print("Missing value at $(i)")
#         print("Missing value at $(i)")
#         anymissing = true
#     end
# end
# if (!anymissing)
#     print("NO MISSING VALUES!")
# end