
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

rho = 0.9
rho_adj = 0
lambda_F = 1.2
lambda_H = 1.1
lambda_UP = 1.11
lambda_DW = 1.3
# periods = collect(1:10)
scenarios = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]

lambda_F = [  
    1.23682342181504,       # 1
    1.2958367004583573,     # 2
    0.9175734914087309,     # 3
    1.1518437538018276,     # 4
    0.7942218447415529,     # 5
    0.7906571808126533,     # 6
    1.2623332988271592,     # 7
    1.0425405195765243,     # 8
    0.9499534019691998,     # 9
    0.9127300809417882      # 10
]

# Should always be less than lambda_F
lambda_UP = [l*0.9 for l in lambda_F]

# Should always be greater than lambda_F
lambda_DW = [l*1.9 for l in lambda_F]

rho = 1
rho_adj = 0
lambda_H = 1.0 # lambda_F sometimes higher, sometimes lower

max_wind_capacity = 10
max_elec_capacity = 8
M = 12


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_F)
@variable(elec_model, 0<=E_H)
@variable(elec_model, E_adj[s in scenarios])
@variable(elec_model, 0<=E_adj_abs[s in scenarios])
@variable(elec_model, 0<=E_sold[s in scenarios])
@variable(elec_model, 0<=E_bought[s in scenarios])
@variable(elec_model, b[s in scenarios], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[s in scenarios])

#Maximize profit
@objective(elec_model, Max, 
    sum(
    (lambda_F[s] * E_F
    + lambda_H * rho * (E_H + E_adj[s])
    + lambda_UP[s] * E_sold[s]
    - lambda_DW[s] * E_bought[s]
    - rho_adj*E_adj_abs[s]
    # + lambda_DW * E_T[s]
    ) * probs[s]
    for s in scenarios)
    )

# Out of bounds tester
# @constraint(elec_model, out_of_bounds, sum(
#     (lambda_F * E_F
#     + lambda_H * rho * (E_H + E_adj[s])
#     + lambda_UP * E_UP_abs[s]
#     - lambda_DW * E_DW_abs[s]
#     - rho_adj*E_adj[s]) * probs[s]
#     for s in scenarios) <= 999999)

#Max capacity
@constraint(elec_model, wind_capacity, max_wind_capacity >= E_F)
@constraint(elec_model, elec_capacity, max_elec_capacity >= E_H)
@constraint(elec_model, adj_capacity_up[s in scenarios], E_adj[s] <= max_elec_capacity - E_H)
@constraint(elec_model, adj_capacity_dw[s in scenarios], -E_H <= E_adj[s])


# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[s in scenarios], E_real[s] - E_F - E_H - E_adj[s] == E_T[s])

@constraint(elec_model, selling1[s in scenarios], E_sold[s] >= E_T[s])
@constraint(elec_model, selling2[s in scenarios], E_sold[s] <= E_T[s] + M*b[s])
@constraint(elec_model, selling3[s in scenarios], E_sold[s] <= M*(1-b[s]))

@constraint(elec_model, buying1[s in scenarios], E_bought[s] >= -E_T[s])
@constraint(elec_model, buying2[s in scenarios], E_bought[s] <= -E_T[s] + M*(1-b[s]))
@constraint(elec_model, buying3[s in scenarios], E_bought[s] <= M*(b[s]))

@constraint(elec_model, absolute3a[s in scenarios], E_adj[s] <= E_adj_abs[s])
@constraint(elec_model, absolute3b[s in scenarios], E_adj[s] >= -E_adj_abs[s])

@constraint(elec_model, tester[s in scenarios], E_adj[s] <= 0)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")
print("\n Forward bid: $(value(E_F))")
print("\n Hydrogen consumption: $(value(E_H))")
print("\n\n")

for s in scenarios
    obj_s = 0
    print("\n\nFor scenario $s:")
    print("\n Realized production: $(E_real[s])")
    print("\n Realized prices (F, buy, sell): $(lambda_F[s]), $(lambda_DW[s]), $(lambda_UP[s])")
    print("\n Adjustment: $(value(E_adj[s]))")
    print("\n Absolute value adjustment: $(value(E_adj_abs[s]))")
    # print("\n Traded: $(value(E_T[s]))")
    print("\n Are we buying?: $(value(b[s]))")
    print("\n Bought: $(value(E_bought[s]))")
    print("\n Sold: $(value(E_sold[s]))")

    # Why is this objective value not correct? It's the same wrong value for every scenario for some reason
    obj_s = lambda_F * value(E_F)
    + lambda_H * rho * (value(E_H) + value(E_adj[s]))
    + lambda_UP * value(E_sold[s])
    - lambda_DW * value(E_bought[s])
    - rho_adj*value(E_adj_abs[s])
    obj_s = obj_s * probs[s]
    # print("\n Objective from scenario: $obj_s")
end


#=
1: 



=# 






 