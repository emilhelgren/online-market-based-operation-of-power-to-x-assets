
using Gurobi
using JuMP
# using printf

E_real = [
    [4.41798436, 4.2868809 , 4.97702469, 4.4798692 , 4.1458924 , 
    4.24256924, 4.18721291, 4.35010486, 4.71606696, 4.54676989], # 1
    [5.13421024, 5.38149358, 5.1341168 , 5.82669197, 5.2938444 , 
    4.95912444, 5.38375814, 5.15747368, 5.67177642, 5.09447949], # 2
    [6.1257037 , 5.83993293, 6.20578469, 6.00712644, 6.19670772,
    6.74429338, 6.30143956, 6.3260893 , 6.46147341, 6.4054159 ], # 3
    [7.1161873 , 7.59643545, 6.7158809 , 7.599571  , 6.88489282,
    7.26574258, 7.28421926, 7.22470964, 7.03760088, 7.03432657], # 4
    [2.77536709, 2.74842367, 2.73583778, 3.07963894, 2.95295101,
    2.63475126, 3.1180267 , 2.79070031, 2.50279846, 2.38711131], # 5
    [5.32393429, 4.8965935 , 5.05723807, 5.13767829, 5.12602303,
    4.80502141, 5.38149453, 5.10033555, 4.69483701, 5.22497854], # 6
    [6.06176203, 5.25051042, 5.49383333, 5.46801304, 6.05757209,
    5.90515774, 5.78946641, 5.26945916, 5.68177314, 5.42829474], # 7
    [6.11617778, 6.41605833, 6.07501826, 6.12405993, 6.48984307,
    6.41378448, 6.4952454 , 6.70210819, 6.91425236, 6.21894837], # 8
    [10.54141627, 11.25918386, 11.20393611, 10.54567837, 10.49664891,
    10.63234451, 10.38816378, 10.46518147, 11.27006989, 10.56783056], # 9
    [0.51556634, 1.24061481, 0.89610178, 0.49976019, 1.04063718,
    0.85334688, 1.05203948, 1.13752195, 0.97502003, 1.08417167] # 10
]

E_forecast = [
    5,      # 1
    6,      # 2
    7,      # 3
    8,      # 4
    3,      # 5
    5.5,    # 6
    6.2,    # 7
    7.2,    # 8
    12,     # 9
    1.1,    # 10
]

periods = collect(1:10)
scenarios1 = collect(1:10)
scenarios2 = collect(1:10)
probs = [0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1, 0.1]


lambda_F = [0.94423281, 1.17482697, 0.68934189, 1.50722456, 1.13033861,
1.55988187, 0.8699497 , 0.819744  , 1.32419046, 0.7800745 ] # mean = 1.079980537
lambda_H = 1.0



lambda_UP = []
lambda_DW = []

randoms_up = [0.81188704, 0.82233711, 0.89069712, 0.77669864, 0.87744114,
0.74194483, 0.74483787, 0.7106238 , 0.76461426, 0.88774201]
randoms_dw = [1.3928639 , 1.28684199, 1.20182008, 1.20636038, 1.23086278,
1.39256566, 1.2537517 , 1.25913517, 1.33020145, 1.21392255]

for t in periods
    t_up = []
    t_dw = []
    for s2 in scenarios2
        push!(t_up, randoms_up[s2]*lambda_F[t])
        push!(t_dw, randoms_dw[s2]*lambda_F[t])
    end
    if (t == 10)
        t_up[8] = 1.1
        t_up[9] = 1.5
        t_up[10] = 5
    end
    push!(lambda_UP, t_up)
    push!(lambda_DW, t_dw)
end



max_wind_capacity = 10.0
max_elec_capacity = 10.0
M = 12.0


#Declare Gurobi model
elec_model = Model(Gurobi.Optimizer)

#Definition of variables
@variable(elec_model, 0<=E_sold[t in periods, s1 in scenarios1])
@variable(elec_model, 0<=E_bought[t in periods, s1 in scenarios1])
@variable(elec_model, E_adj[t in periods, s1 in scenarios1])
@variable(elec_model, 0<=E_adj_abs[t in periods, s1 in scenarios1])
@variable(elec_model, b[t in periods, s1 in scenarios1], Bin) # Binary variable indicating if we are buying (1) or selling (0)
@variable(elec_model, E_T[t in periods, s1 in scenarios1])
@variable(elec_model, q[i=1:2])
# q = [0.8333333333333334, 0.01574658166666672]
@variable(elec_model, q_adj[i=1:2])

#Maximize profit
@objective(elec_model, Max, 
    sum(
        0.1 * sum(
            lambda_F[t] * (E_forecast[t]*q[1])
            + lambda_H * (E_forecast[t]*q[2] + E_adj[t, s1])
            - E_adj_abs[t, s1] * 0.01
            + 0.1 * sum(
                lambda_UP[t][s2] * E_sold[t, s1]
                - lambda_DW[t][s2] * E_bought[t, s1]
            for s2 in scenarios2)
        for s1 in scenarios1)
    for t in periods)
    )


#Max capacity
@constraint(elec_model, wind_capacity[t in periods], max_wind_capacity >= E_forecast[t] * q[1])
@constraint(elec_model, elec_capacity[t in periods], max_elec_capacity >= E_forecast[t] * q[2])

@constraint(elec_model, adj_capacity_up[t in periods, s1 in scenarios1], E_adj[t, s1] <= max_elec_capacity - E_forecast[t] * q[2])
@constraint(elec_model, adj_capacity_dw[t in periods, s1 in scenarios1], -E_forecast[t] * q[2] <= E_adj[t, s1])

@constraint(elec_model, wind_min[t in periods], 0 <= E_forecast[t] * q[1])
@constraint(elec_model, elec_min[t in periods], 0 <= E_forecast[t] * q[2])

# Power SOLD == POSITIVE, BOUGHT == NEGATIVE
@constraint(elec_model, trade[t in periods, s1 in scenarios1], E_real[t][s1] - (E_forecast[t] * q[1]) - (E_forecast[t] * q[2]) - E_adj[t, s1] == E_T[t, s1])

@constraint(elec_model, selling1[t in periods, s1 in scenarios1], E_sold[t, s1] >= E_T[t, s1])
@constraint(elec_model, selling2[t in periods, s1 in scenarios1], E_sold[t, s1] <= E_T[t, s1] + M*b[t, s1])
@constraint(elec_model, selling3[t in periods, s1 in scenarios1], E_sold[t, s1] <= M*(1-b[t, s1]))

@constraint(elec_model, buying1[t in periods, s1 in scenarios1], E_bought[t, s1] >= -E_T[t, s1])
@constraint(elec_model, buying2[t in periods, s1 in scenarios1], E_bought[t, s1] <= -E_T[t, s1] + M*(1-b[t, s1]))
@constraint(elec_model, buying3[t in periods, s1 in scenarios1], E_bought[t, s1] <= M*(b[t, s1]))


@constraint(elec_model, absolute3a[t in periods, s1 in scenarios1], E_adj[t, s1] <= E_adj_abs[t, s1])
@constraint(elec_model, absolute3b[t in periods, s1 in scenarios1], E_adj[t, s1] >= -E_adj_abs[t, s1])


# q_adj * (E_forecast[t] * q[1]) - (E_forecast[t] * q[2]) <--- Gør det ikke-convext, hvis q ikke er fixed
# Så i stedet laver vi det som ekstra parmetre direkte på E_real, i håb om at q[1] og q[2] implicit bliver optimeret for muligheden for at justere, som vil være bedre end hvis de bare blev fixed
@constraint(elec_model, adjustment_parameter[t in periods, s1 in scenarios1], E_adj[t, s1] == q_adj[1]*E_real[t][s1] + q_adj[2]*lambda_F[t]) 

# @constraint(elec_model, tester, 0.1 * sum( lambda_F * (E_forecast*q[1]) + lambda_H * (E_forecast*q[2] + E_adj[s1]) - E_adj_abs[s1] * 0.01 + 0.1 * sum( lambda_UP[s1][s2] * E_sold[s1] - lambda_DW[s1][s2] * E_bought[s1] for s2 in scenarios2) for s1 in scenarios1) <= 9999)

optimize!(elec_model)


print("First line print fix")

println("\nOptimal solution found")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value.(q))")
print("\n\n")
for t in periods
    print("\n\nFor period $t:")
    for s1 in scenarios1
        print("\nFor scenario $s1:")
        print("\n Realized production: $(E_real[t][s1])")
        print("\n Forward price: $(lambda_F[t])")
        print("\n Forward bid: $(value(E_forecast[t]*q[1]))")
        print("\n Hydrogen consumption: $(value(E_forecast[t]*q[2]))")
        print("\n Adjustment: $(value(E_adj[t, s1]))")
        # print("\n Absolute value adjustment: $(value(E_adj_abs[s1]))")
        # print("\n Are we buying?: $(value(b[s1]))")
        print("\n Average buying price: $(sum(lambda_DW[t])/10)")
        print("\n Average selling price: $(sum(lambda_UP[t])/10)")

        print("\n Bought: $(value(E_bought[t, s1]))")
        print("\n Sold: $(value(E_sold[t, s1]))")

    end
end

print("\n\n")
print("Objective value\n")
print(objective_value(elec_model))
print("\n\n")

print("\nq: $(value.(q))")
print("\nq_adj: $(value.(q_adj))")


# Objective value
# 60.92551593771584


# q: [0.8333333333333334, 0.031078500191865338]
# q_adj: [0.006022940912512885, -0.04768310758247846]
 