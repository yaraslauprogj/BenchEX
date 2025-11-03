using BenchmarkExplorer: get_commit_info, get_environment_info, save_run, extract_benchmarks

using Pkg
Pkg.activate(".")

using BenchmarkTools
using Statistics

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using BenchmarkExplorer

include("../benchmarks/trixi/benchmarks.jl")

total_benchmarks = sum(length(group) for group in values(SUITE))

tune!(SUITE)
results = run(SUITE, verbose=true)
benchmarks_data = extract_benchmarks(results, save_raw=false)

commit_info = get_commit_info()
env_info = get_environment_info()

filepath = save_run("trixi", benchmarks_data, commit_info, env_info)

for (name, data) in Iterators.take(benchmarks_data, min(3, length(benchmarks_data)))
    median_ms = data["time"]["median_ns"] / 1e6
    mean_ms = data["time"]["mean_ns"] / 1e6
    min_ms = data["time"]["min_ns"] / 1e6
    memory_kb = data["memory"]["allocated_bytes"] / 1024
end
