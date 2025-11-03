using JSON3
using Dates
using UUIDs

function save_run(project::String, benchmarks_data::Dict, commit_info::Dict, env_info::Dict)
    history_file = joinpath("data", project, "history.json")
    mkpath(dirname(history_file))
    
    history = if isfile(history_file)
        content = read(history_file, String)
        isempty(strip(content)) ? Dict{String, Any}() : JSON3.read(content, Dict{String, Any})
    else
        Dict{String, Any}()
    end
    
    run_metadata = Dict(
        "timestamp" => Dates.format(now(UTC), "yyyy-mm-ddTHH:MM:SS.sss") * "Z",
        "run_id" => string(uuid4()),
        "commit" => commit_info,
        "environment" => env_info
    )
    
    commit_hash = commit_info["short_hash"]
    
    for (benchmark_name, benchmark_data) in benchmarks_data
        if !haskey(history, benchmark_name)
            history[benchmark_name] = Dict{String, Any}()
        end
        
        history[benchmark_name][commit_hash] = Dict(
            "data" => benchmark_data,
            "metadata" => run_metadata
        )
    end
    
    open(history_file, "w") do f
        JSON3.pretty(f, history)
    end
    
    return history_file
end


function load_history(project::String)
    history_file = joinpath("data", project, "history.json")
    
    if !isfile(history_file)
        return Dict{String, Any}()
    end
    
    content = read(history_file, String)
    if isempty(strip(content))
        return Dict{String, Any}()
    end
    
    return JSON3.read(content, Dict{String, Any})
end

function get_benchmark_history(project::String, benchmark_path::String; metric::String="median_ns")
    history = load_history(project)
    
    if !haskey(history, benchmark_path)
        return []
    end
    
    benchmark_commits = history[benchmark_path]
    
    result = []
    for (commit_hash, commit_data) in benchmark_commits
        data = commit_data["data"]
        metadata = commit_data["metadata"]
        
        value = get(data["time"], metric, 0)
        
        push!(result, (
            timestamp = metadata["timestamp"],
            commit = commit_hash,
            commit_full = metadata["commit"]["hash"],
            branch = metadata["commit"]["branch"],
            value = value,
            mean = get(data["time"], "mean_ns", 0),
            min = get(data["time"], "min_ns", 0),
            max = get(data["time"], "max_ns", 0)
        ))
    end
    
    sort!(result, by = x -> x.timestamp)
    
    return result
end


function list_benchmarks(project::String)
    history = load_history(project)
    return sort(collect(keys(history)))
end

function get_commits_for_benchmark(project::String, benchmark_path::String)
    history = load_history(project)
    
    if !haskey(history, benchmark_path)
        return String[]
    end
    
    commits = collect(keys(history[benchmark_path]))
    
    commits_with_time = [(commit, history[benchmark_path][commit]["metadata"]["timestamp"]) for commit in commits]
    sort!(commits_with_time, by = x -> x[2])
    
    return [x[1] for x in commits_with_time]
end

function get_commit_info()
    if haskey(ENV, "BENCHMARK_COMMIT_HASH")
        return Dict(
            "hash" => ENV["BENCHMARK_COMMIT_HASH"],
            "short_hash" => ENV["BENCHMARK_COMMIT_SHORT"],
            "branch" => get(ENV, "BENCHMARK_COMMIT_BRANCH", "main"),
            "message" => get(ENV, "BENCHMARK_COMMIT_MESSAGE", "Benchmark run"),
            "author" => get(ENV, "BENCHMARK_COMMIT_AUTHOR", get(ENV, "USER", "unknown")),
            "date" => Dates.format(now(), "yyyy-mm-dd HH:MM:SS")
        )
    end
    
    commit_hash = try
        strip(read(`git rev-parse HEAD`, String))
    catch
        "unknown"
    end
    
    commit_short = length(commit_hash) >= 7 ? commit_hash[1:7] : commit_hash
    
    return Dict(
        "hash" => commit_hash,
        "short_hash" => commit_short,
        "branch" => try strip(read(`git branch --show-current`, String)) catch; "unknown" end,
        "message" => try strip(first(split(read(`git log -1 --pretty=%B`, String), '\n'))) catch; "" end,
        "author" => try strip(read(`git log -1 --pretty=%ae`, String)) catch; "" end,
        "date" => try strip(read(`git log -1 --pretty=%ci`, String)) catch; "" end
    )
end

function get_environment_info()
    return Dict(
        "julia_version" => string(VERSION),
        "os" => string(Sys.KERNEL),
        "cpu" => Sys.cpu_info()[1].model,
        "cpu_cores" => Sys.CPU_THREADS,
        "ram_gb" => round(Sys.total_memory() / 1e9, digits=2),
        "hostname" => gethostname()
    )
end
