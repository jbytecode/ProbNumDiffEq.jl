function initialize_without_derivatives(prob, order, var=1e-3)
    q = order
    u0 = prob.u0
    d = length(u0)
    p = prob.p
    t0 = prob.tspan[1]

    m0 = zeros(d*(q+1))
    m0[1:d] = u0
    if !isinplace(prob)
        m0[d+1:2d] = prob.f(u0, p, t0)
    else
        prob.f(m0[d+1:2d], u0, p, t0)
    end
    P0 = [zeros(d, d) zeros(d, d*q);
          zeros(d*q, d) diagm(0 => var .* ones(d*q))]
    return m0, P0
end


function initialize_with_derivatives(prob::ODEProblem, order::Int)
    f = isinplace(prob) ? iip_to_oop(prob.f) : prob.f

    u0 = prob.u0
    t0 = prob.tspan[1]
    p = prob.p

    d = length(u0)
    q = order

    uElType = eltype(u0)
    m0 = zeros(uElType, d*(q+1))
    P0 = zeros(uElType, d*(q+1), d*(q+1))

    m0[1:d] .= u0
    m0[d+1:2d] .= f(u0, p, t0)

    f_derivatives = Function[f]
    for o in 2:q
        _curr_f_deriv = f_derivatives[end]
        dfdu(u, p, t) = ForwardDiff.jacobian(u -> _curr_f_deriv(u, p, t), u)
        dfdt(u, p, t) = ForwardDiff.derivative(t -> _curr_f_deriv(u, p, t), t)
        df(u, p, t) = dfdu(u, p, t) * f(u, p, t) + dfdt(u, p, t)
        push!(f_derivatives, df)
        m0[o*d+1:(o+1)*d] = df(u0, p, t0)
    end

    return m0, P0
end


function iip_to_oop(f!)
    function f(u, p, t)
        du = copy(u)
        f!(du, u, p, t)
        return du
    end
    return f
end
