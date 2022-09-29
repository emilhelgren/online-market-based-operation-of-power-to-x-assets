include("data_loader.jl")

function evaluate_model_5_old(q, q_adj)
    return sum(
        lambda_F[t]*(E_forecast[t]*q[1])
        + lambda_H * (E_forecast[t]*q[2] + (q_adj[1]*E_real[t] + q_adj[2]*lambda_F[t]))
        - abs(q_adj[1]*E_real[t] + q_adj[2]*lambda_F[t]) * 10
        + lambda_UP[t] * max(E_real[t] - E_forecast[t]*q[1] - E_forecast[t]*q[2] - (q_adj[1]*E_real[t] + q_adj[2]*lambda_F[t]), 0)
        - lambda_DW[t] * max(E_forecast[t]*q[1] + E_forecast[t]*q[2] + (q_adj[1]*E_real[t] + q_adj[2]*lambda_F[t]) - E_real[t], 0)
        for t in eval_periods)
end

function evaluate_model_6_old(q_F, q_H, q_adj)
    return sum(
        lambda_F[t]*(E_forecast[t]*q_F)
        + lambda_H * (E_forecast[t]*q_F + q_adj*E_real[t])
        - abs(q_adj*E_real[t]) * 10
        + lambda_UP[t] * max(E_real[t] - E_forecast[t]*q_F - E_forecast[t]*q_H - q_adj*E_real[t], 0)
        - lambda_DW[t] * max(E_forecast[t]*q_F + E_forecast[t]*q_H + q_adj*E_real[t] - E_real[t], 0)
        for t in eval_periods)
end


eval_periods = collect(2190:2190+730)

obj_3M = evaluate_model_5_old(
    [0.0, 0.20610440625107565], 
    [0.7078389089087356, 0.00023732169532924717])

obj_2M = evaluate_model_5_old(
    [0.023246764990650245, 0.8916910348713235], 
    [0.0, 0.0])


obj_1M = evaluate_model_5_old(
    [0.0, 0.9121817741223718], 
    [0.006097572377092898, -0.000817188269646118]
)

print("\n\n")
print("\n3 months trained obj: $(obj_3M)")
print("\n2 months trained obj: $(obj_2M)")
print("\n1 month trained obj: $(obj_1M)")





# 3 months trained obj: 202211.99595473323
# 1 month trained obj: 162855.5777918261