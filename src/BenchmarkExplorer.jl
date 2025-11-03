module BenchmarkExplorer

using BenchmarkTools
using JSON3
using Dates
using Statistics
using UUIDs

export extract_benchmarks, save_run, load_history, get_benchmark_history, list_benchmarks, get_commits_for_benchmark

include("benchmark_extractor.jl")
include("data_storage.jl")

end
