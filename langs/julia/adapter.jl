#!/usr/bin/env julia
# argv: julia adapter.jl <src> <class> <cases.json>
# include the solution, instantiate Simulation or InMemoryDatabase,
# call snake_case methods, compare JSON encodings.

module MiniJson
export decode, encode

mutable struct Parser
    s::String
    i::Int
    n::Int
end

function peek(p::Parser)
    return p.i > p.n ? UInt8(0) : codeunit(p.s, p.i)
end

function bump!(p::Parser)
    c = peek(p)
    p.i += 1
    return c
end

function skipws!(p::Parser)
    while p.i <= p.n
        c = codeunit(p.s, p.i)
        if c == 0x20 || c == 0x09 || c == 0x0a || c == 0x0d
            p.i += 1
        else
            break
        end
    end
end

function parse_string!(p::Parser)
    bump!(p) == 0x22 || error("expected string")
    buf = IOBuffer()
    while true
        p.i > p.n && error("unterminated string")
        c = bump!(p)
        if c == 0x22
            return String(take!(buf))
        elseif c == 0x5c
            e = bump!(p)
            if e == 0x22 || e == 0x5c || e == 0x2f
                write(buf, e)
            elseif e == 0x62
                write(buf, 0x08)
            elseif e == 0x66
                write(buf, 0x0c)
            elseif e == 0x6e
                write(buf, 0x0a)
            elseif e == 0x72
                write(buf, 0x0d)
            elseif e == 0x74
                write(buf, 0x09)
            elseif e == 0x75
                hex = String([Char(bump!(p)) for _ in 1:4])
                write(buf, Char(parse(UInt32, hex; base = 16)))
            else
                error("bad escape")
            end
        else
            write(buf, c)
        end
    end
end

function parse_number!(p::Parser)
    start = p.i
    peek(p) == 0x2d && bump!(p)
    while p.i <= p.n && 0x30 <= codeunit(p.s, p.i) <= 0x39
        bump!(p)
    end
    is_float = false
    if peek(p) == 0x2e
        is_float = true
        bump!(p)
        while p.i <= p.n && 0x30 <= codeunit(p.s, p.i) <= 0x39
            bump!(p)
        end
    end
    c = peek(p)
    if c == 0x65 || c == 0x45
        is_float = true
        bump!(p)
        c = peek(p)
        if c == 0x2b || c == 0x2d
            bump!(p)
        end
        while p.i <= p.n && 0x30 <= codeunit(p.s, p.i) <= 0x39
            bump!(p)
        end
    end
    text = p.s[start:(p.i - 1)]
    return is_float ? parse(Float64, text) : parse(Int, text)
end

function parse_array!(p::Parser)
    bump!(p)
    skipws!(p)
    acc = Any[]
    if peek(p) == 0x5d
        bump!(p)
        return acc
    end
    while true
        push!(acc, parse_value!(p))
        skipws!(p)
        c = bump!(p)
        if c == 0x5d
            return acc
        elseif c != 0x2c
            error("expected comma or ]")
        end
        skipws!(p)
    end
end

function parse_object!(p::Parser)
    bump!(p)
    skipws!(p)
    acc = Dict{String,Any}()
    if peek(p) == 0x7d
        bump!(p)
        return acc
    end
    while true
        skipws!(p)
        key = parse_string!(p)
        skipws!(p)
        bump!(p) == 0x3a || error("expected colon")
        skipws!(p)
        acc[key] = parse_value!(p)
        skipws!(p)
        c = bump!(p)
        if c == 0x7d
            return acc
        elseif c != 0x2c
            error("expected comma or }")
        end
    end
end

function parse_value!(p::Parser)
    skipws!(p)
    c = peek(p)
    if c == 0x6e
        p.s[p.i:(p.i + 3)] == "null" || error("expected null")
        p.i += 4
        return nothing
    elseif c == 0x74
        p.s[p.i:(p.i + 3)] == "true" || error("expected true")
        p.i += 4
        return true
    elseif c == 0x66
        p.s[p.i:(p.i + 4)] == "false" || error("expected false")
        p.i += 5
        return false
    elseif c == 0x22
        return parse_string!(p)
    elseif c == 0x5b
        return parse_array!(p)
    elseif c == 0x7b
        return parse_object!(p)
    elseif c == 0x2d || (0x30 <= c <= 0x39)
        return parse_number!(p)
    end
    error("unexpected json byte $c")
end

function decode(text::AbstractString)
    p = Parser(String(text), 1, ncodeunits(String(text)))
    val = parse_value!(p)
    skipws!(p)
    p.i > p.n || error("trailing json")
    return val
end

function write_val(io::IO, val::Nothing)
    print(io, "null")
end

function write_val(io::IO, val::Bool)
    print(io, val ? "true" : "false")
end

function write_val(io::IO, val::Integer)
    print(io, val)
end

function write_val(io::IO, val::AbstractFloat)
    if isinteger(val) && typemin(Int) <= val <= typemax(Int)
        print(io, Int(val))
    else
        print(io, val)
    end
end

function write_val(io::IO, val::AbstractString)
    print(io, '"')
    for c in val
        if c == '"'
            print(io, "\\\"")
        elseif c == '\\'
            print(io, "\\\\")
        elseif c == '\b'
            print(io, "\\b")
        elseif c == '\f'
            print(io, "\\f")
        elseif c == '\n'
            print(io, "\\n")
        elseif c == '\r'
            print(io, "\\r")
        elseif c == '\t'
            print(io, "\\t")
        elseif UInt32(c) < 0x20
            print(io, "\\u", lpad(string(UInt32(c); base = 16), 4, '0'))
        else
            print(io, c)
        end
    end
    print(io, '"')
end

function write_val(io::IO, val::AbstractVector)
    print(io, '[')
    for (i, item) in enumerate(val)
        i > 1 && print(io, ',')
        write_val(io, item)
    end
    print(io, ']')
end

function write_val(io::IO, val::Tuple)
    write_val(io, collect(val))
end

function write_val(io::IO, val::AbstractDict)
    print(io, '{')
    first = true
    for key in sort!(collect(keys(val)); by = string)
        first || print(io, ',')
        first = false
        write_val(io, string(key))
        print(io, ':')
        write_val(io, val[key])
    end
    print(io, '}')
end

function encode(val)
    buf = IOBuffer()
    write_val(buf, val)
    return String(take!(buf))
end

end

function fail_row(case_id, index, method, expected, actual)
    return Dict{String,Any}(
        "case" => case_id,
        "index" => index,
        "method" => method,
        "expected" => expected,
        "actual" => actual,
    )
end

function coerce(val)
    if val isa AbstractFloat
        i = round(Int, val)
        return val == Float64(i) ? i : val
    elseif val isa AbstractVector
        return Any[coerce(x) for x in val]
    else
        return val
    end
end

function exc_name(err)
    T = typeof(err)
    return string(nameof(T))
end

function new_target(class_name)
    T = getfield(Main, Symbol(class_name))
    return T()
end

function invoke_method(obj, method, args)
    fn = getfield(Main, Symbol(method))
    return fn(obj, args...)
end

function main()
    if length(ARGS) < 3
        println(stderr, "usage: julia adapter.jl <src> <class> <cases.json>")
        exit(2)
    end
    src, class_name, cases_path = ARGS[1], ARGS[2], ARGS[3]
    include(abspath(src))
    if !isdefined(Main, Symbol(class_name))
        println(stderr, "missing type $class_name")
        exit(2)
    end
    cases = MiniJson.decode(read(cases_path, String))
    failed = Any[]
    passed = 0
    for row in cases
        # include() defines types after this file compiled.
        obj = Base.invokelatest(new_target, class_name)
        case_id = string(row["id"])
        calls = Base.get(row, "calls", Any[])
        ok = true
        for i in eachindex(calls)
            call = calls[i]
            method = string(call["m"])
            args = Any[coerce(a) for a in Base.get(call, "a", Any[])]
            expected = coerce(call["e"])
            local actual
            try
                actual = Base.invokelatest(invoke_method, obj, method, args)
            catch err
                push!(
                    failed,
                    fail_row(case_id, i - 1, method, expected, "exc:$(exc_name(err))"),
                )
                ok = false
                break
            end
            if MiniJson.encode(actual) != MiniJson.encode(expected)
                push!(failed, fail_row(case_id, i - 1, method, expected, actual))
                ok = false
                break
            end
        end
        if ok
            passed += 1
        end
    end
    println(MiniJson.encode(Dict{String,Any}("failed" => failed, "passed" => passed)))
    exit(isempty(failed) ? 0 : 1)
end

main()
