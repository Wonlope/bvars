#' @export
#' @title Historical decomposition for bayesian vector autoregression
#' @param obj an S3 object generated by bvar
#' @param ... currently not used
#' @return returns an S3 object of the class histdecomp
hd.bvar <- function(obj,...){

  # Preliminary work
  nreps <- dim(obj$mcmc_draws$Alpha)[3]
  nT <- dim(obj$data_info$data)[1] - obj$general_info$nolags

  # lagdata
  lg <- lagdata(obj$data_info$data,intercept = obj$general_info$intercept,nolags=obj$general_info$nolags)

  # Declare variables to store historical decomposition
  HD <- 0

  for(ii in 1:nreps){
    print(ii)

    # Create residuals
    resid <- lg$y - lg$x %*% obj$mcmc_draws$Alpha[,,ii]

    # Create covariance matrix
    covar <- t(chol(obj$mcmc_draws$Sigma[,,ii])) # Identification using Cholesky decomposition
    nVar <- dim(covar)[1]
    seqCovar <- array(0,dim=c(nVar,nVar,nT))
    seqCovar[,,] <- covar

    # Create companion matrix
    if(obj$general_info$intercept){

      bta <- obj$mcmc_draws$Alpha[-c(1),,ii]

    }
    else{

      bta <- obj$mcmc_draws$Alpha[,,ii]

    }


    comp <- companionmatrix(bta,nolags=obj$general_info$nolags)
    nDim <- dim(comp)[1]
    seqCompanion <- array(0,dim=c(nDim,nDim,nT))
    seqCompanion[,,] <- comp

    # Create Historical decomposition

    HD <- HD + HDOnePath(seqCompanion,resid,seqCovar)


  }

  HD <- HD/nreps
  if(is.ts(obj$data_info$data)){

    timestamps <- time(obj$data_info$data)
    timestamps <- timestamps[-c(1:obj$general_info$nolags)]

  }
  else{
    timestamps = NULL
  }

  retlist <- structure(list(hd=HD,varnames=colnames(obj$data_info$data),date=timestamps),class="histdecomp")
  return(retlist)

}

#' @export
#' @title Historical decomposition for bayesian vector autoregression
#' @param obj an S3 object generated by bvar
#' @param ... currently not used
#' @return returns an S3 object of the class histdecomp

hd.msvar <- function(obj,...){

  regimes <- obj$mcmc_draws$regimes
  nreps <- dim(obj$mcmc_draws$Alpha)[4]
  nT <- dim(regimes)[1]

  lg <- lagdata(obj$data_info$data,intercept = obj$general_info$intercept,nolags=obj$general_info$nolags)
  HD <- 0

  for(ii in 1:nreps){

    if(ii %% 10 == 0){
      print(ii)
    }


    resid    <- array(0,dim=c(nT,obj$data_info$no_variables))
    seqCovar <- array(0,dim=c(obj$data_info$no_variables,obj$data_info$no_variables,nT))
    seqAlpha <- array(0,dim=c(obj$data_info$no_variables*obj$general_info$nolags,obj$data_info$no_variables*obj$general_info$nolags,nT))

    # Create sequence for variance-covariance matrix and companion matrices dependent on regime
    for(jj in 1:nT){


      seqCovar[,,jj] <- t(chol(obj$mcmc_draws$Sigma[,,regimes[jj],ii]))
      tmp_Alpha <- obj$mcmc_draws$Alpha[,,regimes[jj],ii]
      resid[jj,] <- lg$y[jj,] - lg$x[jj,] %*% tmp_Alpha

      if(obj$general_info$intercept){

        tmp_Alpha <- tmp_Alpha[-c(1),]

      }
      seqAlpha[,,jj] <- companionmatrix(tmp_Alpha,nolags=obj$general_info$nolags)

    }

    # Get historical decomposition for one path
    HD <- HD + HDOnePath(seqAlpha,resid,seqCovar)


  }

  HD <- HD/nreps
  if(is.ts(obj$data_info$data)){

    timestamps <- time(obj$data_info$data)
    timestamps <- timestamps[-c(1:obj$general_info$nolags)]

  }
  else{
    timestamps = NULL
  }

  retlist <- structure(list(hd=HD,varnames=colnames(obj$data_info$data),date=timestamps),class="histdecomp")
  return(retlist)


}

# function to calculate the historical decomposition for one path
# F <- sequence of companion matrices
# U <- sequence of reduced form residuals
# C <- sequence of identified covariance matrices
HDOnePath <- function(Fr,U,C){

  # Create 'structural structural shocks'
  nT   <- dim(U)[1]
  nVar <- dim(U)[2]

  eps  <- array(0,dim=c(nT,nVar^2))
  HDtemp <- array(NaN,dim=c(nVar^2,nT))
  bigeye <- array(0,dim=c(nVar,dim(Fr)[1]))
  bigeye[1:nVar,1:nVar] <- diag(1,nVar)


  for(ii in 1:nT){

    eps[ii,] <-   as.vector(pracma::repmat(pracma::mldivide(C[,,ii],U[ii,]),nVar,1))

  }

  HDtemp[,1] <- as.vector(C[,,1]) * eps[1,]

  for(jj in 2:nT){
    Ftrack <- diag(1,dim(Fr)[1])
    HDtemp[,jj] <- as.vector(C[,,jj]) * eps[jj,]

    for(kk in (jj-1):1){

      Ftrack <- Ftrack %*% Fr[,,kk+1]
      tmp1 <- as.vector(bigeye %*% Ftrack %*% t(bigeye) %*% C[,,kk]) * eps[kk,]
      HDtemp[,jj] <- HDtemp[,jj] + tmp1
    }


  }

  HD <- array(NaN,dim=c(nVar,nVar,nT))
  for(ii in 1:nVar){

    repma <- seq(ii,nVar^2,by=nVar)
    HD[ii,,] <- HDtemp[c(repma),]

  }

  return(HD)

}