using BenchmarkTools
using Statistics

function extract_benchmarks(results::BenchmarkGroup; prefix::String="", save_raw::Bool=false)
    benchmarks = Dict{String, Any}()
    
    for (name, value) in results
        full_path = isempty(prefix) ? string(name) : "$prefix/$name"
        
        if value isa BenchmarkGroup
            merge!(benchmarks, extract_benchmarks(value; prefix=full_path, save_raw=save_raw))
        elseif value isa BenchmarkTools.Trial
            benchmarks[full_path] = extract_trial_data(value; save_raw=save_raw)
        elseif value isa BenchmarkTools.TrialEstimate
            benchmarks[full_path] = extract_estimate_data(value)
        end
    end
    
    return benchmarks
end

function extract_trial_data(trial::BenchmarkTools.Trial; save_raw::Bool=false)
    times_ns = trial.times
    gctimes_ns = trial.gctimes
    
    data = Dict(
        "time" => Dict(
            "median_ns" => Float64(median(times_ns)),
            "mean_ns" => Float64(mean(times_ns)),
            "min_ns" => Float64(minimum(times_ns)),
            "max_ns" => Float64(maximum(times_ns)),
            "std_dev_ns" => Float64(std(times_ns)),
            "percentile_95_ns" => Float64(quantile(times_ns, 0.95)),
            "percentile_99_ns" => Float64(quantile(times_ns, 0.99))
        ),
        "memory" => Dict(
            "allocated_bytes" => Float64(trial.memory),
            "allocations" => Float64(trial.allocs)
        ),
        "gc" => Dict(
            "total_time_ns" => Float64(sum(gctimes_ns)),
            "count" => count(>(0), gctimes_ns),
            "mean_time_ns" => count(>(0), gctimes_ns) > 0 ? Float64(mean(gctimes_ns[gctimes_ns .> 0])) : 0
        ),
        "samples" => Dict(
            "count" => length(times_ns)
        ),
        "params" => Dict(
            "seconds" => trial.params.seconds,
            "samples" => trial.params.samples,
            "evals" => trial.params.evals
        )
    )
    
    if save_raw
        data["samples"]["times_ns"] = Vector{Float64}(times_ns)
        data["samples"]["gc_times_ns"] = Vector{Float64}(gctimes_ns)
    end
    
    return data
end

function extract_estimate_data(estimate::BenchmarkTools.TrialEstimate)
    return Dict(
        "time" => Dict(
            "median_ns" => Float64(BenchmarkTools.time(estimate)),
            "mean_ns" => 0,
            "min_ns" => 0,
            "max_ns" => 0,
            "std_dev_ns" => 0
        ),
        "memory" => Dict(
            "allocated_bytes" => Float64(BenchmarkTools.memory(estimate)),
            "allocations" => Float64(BenchmarkTools.allocs(estimate))
        ),
        "samples" => Dict(
            "count" => 0
        )
    )
end
