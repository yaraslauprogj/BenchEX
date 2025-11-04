#!/usr/bin/env julia

push!(LOAD_PATH, joinpath(@__DIR__, "..", "src"))
using BenchmarkExplorer

using Bonito
using CairoMakie
const DOM = Bonito.DOM

const PROJECT = "trixi"
const PORT = 8080

function create_plot_with_data(bench_name, commits_data)
    commits = sort(collect(keys(commits_data)), 
                  by = k -> commits_data[k]["metadata"]["timestamp"])
    
    if isempty(commits)
        return nothing, nothing
    end
    
    medians = Float64[]
    means = Float64[]
    mins = Float64[]
    
    for c in commits
        data = commits_data[c]["data"]
        if haskey(data, "median_ns")
            push!(medians, data["median_ns"] / 1e6)
            push!(means, data["mean_ns"] / 1e6)
            push!(mins, data["min_ns"] / 1e6)
        elseif haskey(data, "time")
            push!(medians, data["time"]["median_ns"] / 1e6)
            push!(means, data["time"]["mean_ns"] / 1e6)
            push!(mins, data["time"]["min_ns"] / 1e6)
        else
            continue
        end
    end
    
    if isempty(medians)
        return nothing, nothing
    end
    
    fig = Figure(size=(900, 450))
    ax = Axis(fig[1, 1],
        title=bench_name,
        xlabel="Commit",
        ylabel="Time (ms)",
        xticklabelrotation=π/4
    )
    
    lines!(ax, 1:length(commits), medians, label="Median", color=:blue, linewidth=2)
    lines!(ax, 1:length(commits), means, label="Mean", color=:orange, linewidth=2)
    lines!(ax, 1:length(commits), mins, label="Min", color=:green, linewidth=2)
    
    scatter!(ax, 1:length(commits), medians, color=:blue, markersize=12)
    scatter!(ax, 1:length(commits), means, color=:orange, markersize=12)
    scatter!(ax, 1:length(commits), mins, color=:green, markersize=12)
    
    ax.xticks = (1:length(commits), commits)
    axislegend(ax, position=:rt)
    
    table_rows = []
    for i in 1:length(commits)
        row = DOM.tr([
            DOM.td(commits[i], style="padding:5px; font-family:monospace; font-size:0.85em;"),
            DOM.td("$(round(medians[i], digits=2))", style="padding:5px; color:#3498db; font-weight:bold;"),
            DOM.td("$(round(means[i], digits=2))", style="padding:5px; color:#e67e22; font-weight:bold;"),
            DOM.td("$(round(mins[i], digits=2))", style="padding:5px; color:#27ae60; font-weight:bold;")
        ])
        push!(table_rows, row)
    end
    
    data_table = DOM.table([
        DOM.thead(DOM.tr([
            DOM.th("Commit", style="padding:8px; text-align:left; border-bottom:2px solid #ddd;"),
            DOM.th("Median (ms)", style="padding:8px; text-align:left; border-bottom:2px solid #ddd; color:#3498db;"),
            DOM.th("Mean (ms)", style="padding:8px; text-align:left; border-bottom:2px solid #ddd; color:#e67e22;"),
            DOM.th("Min (ms)", style="padding:8px; text-align:left; border-bottom:2px solid #ddd; color:#27ae60;")
        ])),
        DOM.tbody(table_rows)
    ], style="width:100%; border-collapse:collapse; margin-top:15px; font-size:0.9em;")
    
    return fig, data_table
end

function create_dashboard()
    history = load_history(PROJECT)
    
    if isempty(history)
        return DOM.div([
            DOM.h1("No data found"),
            DOM.p("Run: julia scripts/run.jl")
        ])
    end
    
    bench_names = list_benchmarks(PROJECT)
    sections = []
    
    for bench_name in bench_names
        commits_data = history[bench_name]
        
        if isempty(commits_data)
            continue
        end
        
        fig, data_table = create_plot_with_data(bench_name, commits_data)
        
        if fig === nothing
            continue
        end
        
        section = DOM.div([
            DOM.h3(bench_name, 
                  style="color:#2c3e50; margin:0; padding:15px; background:#ecf0f1; cursor:pointer; border-radius:5px;"),
            DOM.div([
                fig,
                DOM.details([
                    DOM.summary("Show data table", 
                               style="cursor:pointer; padding:10px; background:#f8f9fa; margin-top:10px; border-radius:5px;"),
                    data_table
                ])
            ], style="padding:20px;")
        ], style="background:#fff; margin:20px 0; border-radius:10px; box-shadow:0 2px 10px rgba(0,0,0,0.1);")
        
        push!(sections, section)
    end
    
    return DOM.div([
        DOM.h1("Trixi Benchmarks", 
               style="color:#2c3e50; border-bottom:3px solid #3498db; padding:20px; margin:0;"),
        DOM.div([
            DOM.p("Total benchmarks: $(length(sections))", style="margin:5px 0;"),
            DOM.p("Median | Mean | Min", style="margin:5px 0; font-weight:bold;")
        ], style="background:#f8f9fa; padding:15px; margin:20px; border-radius:8px; text-align:center;"),
        DOM.div(sections, style="padding:0 20px;")
    ], style="font-family:'Segoe UI',Tahoma,sans-serif; max-width:1600px; margin:0 auto;")
end

app = App() do session::Session
    return create_dashboard()
end

server = Bonito.Server(app, "0.0.0.0", PORT)
println("http://localhost:$PORT")
wait(server)
