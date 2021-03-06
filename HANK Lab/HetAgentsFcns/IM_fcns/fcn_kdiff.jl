#----------------------------------------------------------------------------
# Functions for solving the Standard IM Model
#----------------------------------------------------------------------------

function Kdiff(K_guess::Float64, n_par::NumericalParameters, m_par::ModelParameters)
    # This function calculates the difference between the capital stock that is assumed
    # and the capital stock that prevails under that guessed capital stock's implied prices
    # when households face idiosyncratic income risk (aiyagari model).
    # K_GUESS is the capital stock guess
    # N_PAR and M_PAR contain numerical and model parameter values
    N       = employment(K_guess, 1.0 ./(m_par.μ*m_par.μw), m_par)
    r       = interest(K_guess,1.0 ./m_par.μ,N, m_par)
    w       = wage(K_guess,1 ./m_par.μ,N, m_par)
    profits = (1.0 .- 1.0 ./m_par.μ)*output(K_guess,1.0,N, m_par)
    K::Float64   = Ksupply(m_par.RB./m_par.π,1.0+r,w*N/n_par.H,profits, n_par,m_par)[1]
    diff    = K - K_guess
    return diff
end
