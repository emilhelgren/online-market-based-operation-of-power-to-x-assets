
using Gurobi
using JuMP
# using printf

# Wind forecast

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


noises = [0.3424078581323642 , -0.46135542013446856
, -1.9396549687255036
, -1.1425097709739453
, -0.18599112079633331
, -0.04624286256162224
, -0.15995961815435117
, -1.671875283686103
, -0.9101485767326017
, -0.9992440285893289]

periods = collect(1:10)
x= []
for i in periods
    # noise = randn()
    # print("\nNoise is: $noise")
    push!(x, E_real[i]+noises[i])
end




lambda_F = [0.94423281, 1.17482697, 0.68934189, 1.50722456, 1.13033861,
1.55988187, 0.8699497 , 0.819744  , 1.32419046, 0.7800745 ] # mean = 1.079980537 - switch is between 1.1205 - 1.121

# lambda_F = [0.9, 1.1, 0.7, 1.3, 1.1,
# 1.3, 0.9 , 0.7  , 1.2, 0.8 ] # mean = 1.0 - causes switch to be between 1.01-1.09

lambda_H = 1.00 

lambda_UP = [f*0.6 for f in lambda_F]
lambda_DW = [f*1.6 for f in lambda_F]

max_wind_capacity = 10.0
max_elec_capacity = 10.0
M = 12.0
rho = 1

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
        + lambda_H * rho * (x[t]*q_H)
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


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

for t in periods
    print("\n\nFor period $t:")
    print("\n Realized production: $(E_real[t])")
    print("\n Forward price: $(lambda_F[t])")
    print("\n Forward bid: $(value(x[t]*q_F))")
    print("\n Hydrogen consumption: $(value(x[t]*q_H))")
    print("\n Buying price: $(sum(lambda_DW[t]))")
    print("\n Selling price: $(sum(lambda_UP[t]))")

    print("\n Bought: $(value(E_bought[t]))")
    print("\n Sold: $(value(E_sold[t]))")

end

print("\n\n")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq_F: $(value(q_F))")
print("\nq_F: $(value(q_H))")

