import MCMCDiagnosticTools

export relative_eff, psis_ess, sup_ess

"""
    relative_eff(
        sample::AbstractArray{<:Real, 3};
        source::Union{AbstractString, Symbol} = "default",
        kwargs..., 
    )

Calculate the relative efficiency of an MCMC chain, i.e., the effective sample size divided
by the nominal sample size.

If `lowercase(String(source))` is `"default"` or `"mcmc"`, the relative effective sample size is computed with `MCMCDiagnosticTools.ess`.
Otherwise a vector of ones for each chain is returned.
The remaining keyword arguments `kwargs` are forwarded to `MCMCDiagnosticTools.ess`.

# Arguments 

  - `sample::AbstractArray{<:Real, 3}`: An array of log-likelihood values of the shape `(parameters, draws, chains)`.
"""
function relative_eff(
    sample::AbstractArray{<:Real,3}; 
    source::Union{AbstractString, Symbol}="default",
    kwargs...,
)
    if lowercase(String(source)) ∉ ("mcmc", "default")
        # Avoid type instability by computing the return type of `ess`
        T = promote_type(eltype(sample), typeof(zero(eltype(sample)) / 1))
        res = similar(sample, T, (axes(sample, 3),))
        return fill!(res, 1)
    end
    ess_sample = PermutedDimsArray(sample, (2, 3, 1))
    return MCMCDiagnosticTools.ess(ess_sample; kwargs..., relative=true)
end


"""
    function psis_ess(
        weights::AbstractVector{T<:Real},
        r_eff::AbstractVector{T}
    ) -> AbstractVector{T}

Calculate the (approximate) effective sample size of a PSIS sample, using the correction in
Vehtari et al. 2019. This uses the entropy-based definition of ESS, measuring the K-L
divergence of the proposal and target distributions.

# Arguments

  - `weights`: A set of normalized importance sampling weights derived from PSIS.
  - `r_eff`: The relative efficiency of the MCMC chains from which PSIS samples were derived.

See `?relative_eff` to calculate `r_eff`.
"""
function psis_ess(
    weights::AbstractMatrix{T}, r_eff::AbstractVector{T}
) where T<:Real
    exp_entropy = zeros(T, size(weights, 1))
    @inbounds for y = axes(weights, 2), x = axes(weights, 1)
        exp_entropy[x] -= xlogx(weights[x, y])
    end
    for i = eachindex(exp_entropy)
        exp_entropy[i] = exp_inline(exp_entropy[i])
    end
    return r_eff .* exp_entropy
end


function psis_ess(weights::AbstractMatrix{<:Real})
    @warn "PSIS ESS not adjusted based on MCMC ESS. MCSE and ESS estimates " *
          "will be overoptimistic if samples are autocorrelated."
    return psis_ess(weights, ones(size(weights)))
end


"""
    function sup_ess(
        weights::AbstractMatrix{T},
        r_eff::AbstractVector{T}
    ) -> AbstractVector

Calculate the supremum-based effective sample size of a PSIS sample, i.e. the inverse of the
maximum weight. This measure is more sensitive than the `ess` from `psis_ess`, but also 
much more variable. It uses the L-∞ norm.

# Arguments
  - `weights`: A set of importance sampling weights derived from PSIS.
  - `r_eff`: The relative efficiency of the MCMC chains; see also [`relative_eff`]@ref.
"""
function sup_ess(
    weights::AbstractMatrix{T}, r_eff::AbstractVector{T}
) where T<:Real
    return inv.(dropdims(maximum(weights; dims=2); dims=2)) .* r_eff
end
