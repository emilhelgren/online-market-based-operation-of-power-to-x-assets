
using Gurobi
using JuMP
# using printf

E_real = [
    5,      # 1
    4.9,    # 2
    5.4,    # 3
    5.3,    # 4
    5.6,    # 5
    6.1,    # 6
    4.8,    # 7
    6.3,    # 8
    7,      # 9
    3       # 10
]

# periods = collect(1:10)
scenarios = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]


lambda_F = 1.3
lambda_UP = 0.7
lambda_DW = 1.7

max_wind_capacity = 10
M = 12


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_F)
@variable(elec_model, 0<=E_sold[s in scenarios])
@variable(elec_model, 0<=E_bought[s in scenarios])
@variable(elec_model, b[s in scenarios], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[s in scenarios])

#Maximize profit
@objective(elec_model, Max, 
    sum(
    (lambda_F * E_F
    + lambda_UP * E_sold[s]
    - lambda_DW * E_bought[s]
    ) * probs[s]
    for s in scenarios)
    )


#Max capacity
@constraint(elec_model, wind_capacity, max_wind_capacity >= E_F)

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[s in scenarios], E_real[s] - E_F == E_T[s])

@constraint(elec_model, selling1[s in scenarios], E_sold[s] >= E_T[s])
@constraint(elec_model, selling2[s in scenarios], E_sold[s] <= E_T[s] + M*b[s])
@constraint(elec_model, selling3[s in scenarios], E_sold[s] <= M*(1-b[s]))

@constraint(elec_model, buying1[s in scenarios], E_bought[s] >= -E_T[s])
@constraint(elec_model, buying2[s in scenarios], E_bought[s] <= -E_T[s] + M*(1-b[s]))
@constraint(elec_model, buying3[s in scenarios], E_bought[s] <= M*(b[s]))

# @constraint(elec_model, tester[s in scenarios], E_adj_abs[s] <= 0.8)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

for s in scenarios
    obj_s = 0
    print("\n\nFor scenario $s:")
    print("\n Realized production: $(E_real[s])")
    print("\n Forward bid: $(value(E_F))")
    print("\n Are we buying?: $(value(b[s]))")
    print("\n Bought: $(value(E_bought[s]))")
    print("\n Sold: $(value(E_sold[s]))")

end


#=
1: 



=# 






 