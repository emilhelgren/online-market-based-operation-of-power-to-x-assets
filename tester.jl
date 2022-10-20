
using DataFrames
using CSV
realized = [
        4,
        5,
        7,
        13,
        16,
        3,
        4,
        3,
        7,
        8
    ]

for i in eachindex(realized)
    print(i)
end