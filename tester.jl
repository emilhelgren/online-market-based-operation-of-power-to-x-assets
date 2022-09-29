
using DataFrames
using CSV



lambda_F = DataFrame(CSV.File("./data/forward.csv"))[:, 2]
print(lambda_F)

