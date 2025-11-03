using Pkg
Pkg.activate(".")

using Bonito
using CairoMakie
using Dates

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using BenchmarkExplorer

const PROJECT = "trixi"

available_benchmarks = list_benchmarks(PROJECT)

if isempty(available_benchmarks)
    exit(1)
end

DEFAULT_BENCH_1 = length(available_benchmarks) >= 1 ? available_benchmarks[1] : ""
DEFAULT_BENCH_2 = length(available_benchmarks) >= 2 ? available_benchmarks[2] : available_benchmarks[1]

function create_benchmark_plot(benchmark_name::String, title::String)
    history = get_benchmark_history(PROJECT, benchmark_name)
    
    if isempty(history)
        fig = Figure(size=(600, 400))
        ax = Axis(fig[1, 1], title=title)
        text!(ax, 0.5, 0.5, text="No data available", align=(:center, :center))
        return fig
    end
    
    commits = [h.commit for h in history]
    median_values = [h.value / 1e6 for h in history]
    mean_values = [h.mean / 1e6 for h in history]
    min_values = [h.min / 1e6 for h in history]
    
    x_indices = 1:length(commits)
    
    fig = Figure(size=(800, 500))
    ax = Axis(fig[1, 1], 
              title=title,
              xlabel="Commit",
              ylabel="Time (ms)",
              xticks=(x_indices, commits),
              xticklabelrotation=π/4)
    
    lines!(ax, x_indices, median_values, label="Median", color=:blue, linewidth=2)
    scatter!(ax, x_indices, median_values, color=:blue, markersize=10)
    
    lines!(ax, x_indices, mean_values, label="Mean", color=:orange, linewidth=2)
    scatter!(ax, x_indices, mean_values, color=:orange, markersize=10)
    
    lines!(ax, x_indices, min_values, label="Min", color=:green, linewidth=2)
    scatter!(ax, x_indices, min_values, color=:green, markersize=10)
    
    axislegend(ax, position=:lt)
    
    return fig
end

app = App() do session::Session
    header = DOM.div([
        DOM.h1("BenchmarkExplorer Dashboard", 
               style="text-align:center; color:#2c3e50; margin-bottom:10px;"),
        DOM.p("Project: $PROJECT | Benchmarks: $(length(available_benchmarks))",
              style="text-align:center; color:#7f8c8d; font-size:1.1em;")
    ])
    
    history = load_history(PROJECT)
    info_box = if !isempty(history)
        first_bench = first(keys(history))
        commits = collect(keys(history[first_bench]))
        
        if !isempty(commits)
            latest_commit = commits[1]
            latest_time = history[first_bench][commits[1]]["metadata"]["timestamp"]
            
            for commit in commits[2:end]
                timestamp = history[first_bench][commit]["metadata"]["timestamp"]
                if timestamp > latest_time
                    latest_commit = commit
                    latest_time = timestamp
                end
            end
            
            metadata = history[first_bench][latest_commit]["metadata"]
            commit = metadata["commit"]
            
            DOM.div([
                DOM.div([
                    DOM.strong("Latest run: "),
                    DOM.span("$(commit["short_hash"]) on $(commit["branch"])"),
                    DOM.span(" • ", style="margin: 0 10px;"),
                    DOM.span("$latest_time")
                ], style="font-size:0.95em; color:#555;")
            ], style="background:#f8f9fa; padding:15px; margin:20px 0; border-radius:8px; text-align:center;")
        else
            DOM.div("")
        end
    else
        DOM.div("")
    end
    
    println("📊 Creating plot 1: $DEFAULT_BENCH_1")
    fig1 = create_benchmark_plot(DEFAULT_BENCH_1, "Benchmark 1: $DEFAULT_BENCH_1")
    plot1_container = DOM.div([
        DOM.h2("📈 Benchmark 1", style="color:#333; margin-top:30px;"),
        DOM.p(DEFAULT_BENCH_1, style="color:#666; font-family:monospace; font-size:0.9em;"),
        fig1
    ], style="background:#fff; padding:20px; margin:20px 0; border-radius:10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);")
    
    println("📊 Creating plot 2: $DEFAULT_BENCH_2")
    fig2 = create_benchmark_plot(DEFAULT_BENCH_2, "Benchmark 2: $DEFAULT_BENCH_2")
    plot2_container = DOM.div([
        DOM.h2("📈 Benchmark 2", style="color:#333; margin-top:30px;"),
        DOM.p(DEFAULT_BENCH_2, style="color:#666; font-family:monospace; font-size:0.9em;"),
        fig2
    ], style="background:#fff; padding:20px; margin:20px 0; border-radius:10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1);")
    
    footer = DOM.div([
        DOM.p("Last updated: $(Dates.now())", 
             style="text-align:center; color:#999; font-size:0.85em; margin-top:40px;")
    ])
    
    return DOM.div([
        header,
        info_box,
        plot1_container,
        plot2_container,
        footer
    ], style="font-family:-apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Arial, sans-serif; padding:20px; max-width:1400px; margin:0 auto; background:#f5f7fa; min-height:100vh;")
end

port = 8089
try
    global server = Bonito.Server(app, "127.0.0.1", port)
    println("http://localhost:$port")
catch e
    port = 8090
    global server = Bonito.Server(app, "127.0.0.1", port)
    println("http://localhost:$port (port 8089 was busy)")
end

try
    while true
        sleep(1)
    end
catch e
    if isa(e, InterruptException)
        println("")
    else
        rethrow(e)
    end
end
