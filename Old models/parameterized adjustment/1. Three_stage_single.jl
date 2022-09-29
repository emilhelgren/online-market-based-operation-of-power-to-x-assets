
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
    3,    # 8
    7,      # 9
    6.3       # 10
]

E_forecast = sum(E_real)/10.0
# E_forecast[10] = 8

periods = collect(1:10)
scenarios1 = collect(1:10)
scenarios2 = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]


lambda_F = 1.1
lambda_H = 1.0

lambda_UP = [0.81188704, 0.82233711, 0.89069712, 0.77669864, 0.87744114, 0.74194483, 0.74483787, 0.7106238 , 0.76461426, 0.71023912]
lambda_DW = [1.3928639 , 1.28684199, 1.20182008, 1.20636038, 1.23086278, 1.39256566, 1.2537517 , 1.25913517, 1.33020145, 1.1923741]

max_wind_capacity = 10.0
max_elec_capacity = 10.0
M = 12.0


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_sold[s1 in scenarios1])
@variable(elec_model, 0<=E_bought[s1 in scenarios1])
@variable(elec_model, E_adj[s1 in scenarios1])
@variable(elec_model, 0<=E_adj_abs[s1 in scenarios1])
@variable(elec_model, b[s1 in scenarios1], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[s1 in scenarios1])
@variable(elec_model, q[i=1:2])

#Maximize profit
@objective(elec_model, Max, 
    0.1 * sum(
        lambda_F * (E_forecast*q[1])
        + lambda_H * (E_forecast*q[2] + E_adj[s1])
        - E_adj_abs[s1] * 0.01
        + 0.1 * sum(
            lambda_UP[s2] * E_sold[s1]
            - lambda_DW[s2] * E_bought[s1]
        for s2 in scenarios2)
    for s1 in scenarios1)
    )


#Max capacity
@constraint(elec_model, wind_capacity, max_wind_capacity >= E_forecast * q[1])
@constraint(elec_model, elec_capacity, max_elec_capacity >= E_forecast * q[2])

@constraint(elec_model, adj_capacity_up[s1 in scenarios1], E_adj[s1] <= max_elec_capacity - E_forecast * q[2])
@constraint(elec_model, adj_capacity_dw[s1 in scenarios1], -E_forecast * q[2] <= E_adj[s1])

@constraint(elec_model, wind_min, 0 <= E_forecast * q[1])
@constraint(elec_model, elec_min, 0 <= E_forecast * q[2])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[s1 in scenarios1], E_real[s1] - (E_forecast * q[1]) - (E_forecast * q[2]) - E_adj[s1] == E_T[s1])

@constraint(elec_model, selling1[s1 in scenarios1], E_sold[s1] >= E_T[s1])
@constraint(elec_model, selling2[s1 in scenarios1], E_sold[s1] <= E_T[s1] + M*b[s1])
@constraint(elec_model, selling3[s1 in scenarios1], E_sold[s1] <= M*(1-b[s1]))

@constraint(elec_model, buying1[s1 in scenarios1], E_bought[s1] >= -E_T[s1])
@constraint(elec_model, buying2[s1 in scenarios1], E_bought[s1] <= -E_T[s1] + M*(1-b[s1]))
@constraint(elec_model, buying3[s1 in scenarios1], E_bought[s1] <= M*(b[s1]))


@constraint(elec_model, absolute3a[s1 in scenarios1], E_adj[s1] <= E_adj_abs[s1])
@constraint(elec_model, absolute3b[s1 in scenarios1], E_adj[s1] >= -E_adj_abs[s1])

# @constraint(elec_model, tester, 0.1 * sum( lambda_F * (E_forecast*q[1]) + lambda_H * (E_forecast*q[2] + E_adj[s1]) - E_adj_abs[s1] * 0.01 + 0.1 * sum( lambda_UP[s1][s2] * E_sold[s1] - lambda_DW[s1][s2] * E_bought[s1] for s2 in scenarios2) for s1 in scenarios1) <= 9999)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value.(q))")
print("\n\n")
for s1 in scenarios1
    obj_s = 0
    print("\n\nFor scenario $s1:")
    print("\n Realized production: $(E_real[s1])")
    print("\n Forward price: $(lambda_F)")
    print("\n Forward bid: $(value(E_forecast*q[1]))")
    print("\n Hydrogen consumption: $(value(E_forecast*q[2]))")
    print("\n Adjustment: $(value(E_adj[s1]))")
    # print("\n Absolute value adjustment: $(value(E_adj_abs[s1]))")
    # print("\n Are we buying?: $(value(b[s1]))")
    print("\n Average buying price: $(sum(lambda_DW)/10)")
    print("\n Average selling price: $(sum(lambda_UP)/10)")

    print("\n Bought: $(value(E_bought[s1]))")
    print("\n Sold: $(value(E_sold[s1]))")

end







 