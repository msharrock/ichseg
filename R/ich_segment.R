#' @title Predict ICH Segmentation
#' @description Will preprocess and predict the ICH voxels
#'
#' @param img CT image, object of class \code{nifti} or
#' character filename
#' @param mask binary brain mask, object of class \code{nifti} or
#' character filename
#' @param model model to use for prediction,
#' either the random forest (rf) or logistic
#' @param save_imgs Logical to save all images that are created as
#' predictors
#' @param outdir Output directory of saved images, needs to be set
#' if \code{save_imgs = TRUE}
#' @param stub Basename to write image names if \code{save_imgs = TRUE}
#' @param verbose Print diagnostic output
#' @param shiny Should shiny progress be called?
#' @param roi Filename of ROI, which will be transformed
#' @param erode_mask Should the brain mask be eroded?
#' @param ... Additional options passsed to \code{\link{ich_preprocess}}
#'
#' @return List of output prediction/probability images
#' @export
#' @importFrom fslr have.fsl
ich_segment = function(img,
                       ...,
                       verbose = TRUE,
                       shiny = FALSE,
                       model = c("rf", "logistic")) {

  model = match.arg(model)

  L = ich_process_predictors(
    img = img,
    ...,
    verbose = verbose,
    roi = NULL)
  df = L$img.pred$df
  nim = L$img.pred$nim
  L$img.pred = NULL
  preprocess = L$preprocess
  rm(list = "L");   gc()


  # data(MOD)
  ##############################################################
  # Making prediction images
  ##############################################################
  # grabbing the evnironment to extract exported stuff
  if (verbose) {
    msg = "# Running ich_predict"
    message(msg)
  }
  if (shiny) {
    shiny::setProgress(message = msg, value = 3/3 - 0.3)
  }
  L = ich_predict(df = df,
                  nim = nim,
                  model = model,
                  native_img = img,
                  native = TRUE,
                  verbose = verbose,
                  transformlist = preprocess$invtransforms,
                  interpolator = preprocess$interpolator,
                  shiny = shiny)
  L$preprocess = preprocess
  if (shiny) {
    shiny::setProgress(value = 3/3)
  }
  return(L)

}


#' @rdname ich_segment
#' @export
ich_process_predictors = function(
  img,
  mask = NULL,
  save_imgs = FALSE,
  outdir = NULL,
  stub = NULL,
  verbose = TRUE,
  shiny = FALSE,
  roi = NULL,
  erode_mask = TRUE,
  ...) {

  if (!have.fsl()) {
    stop("FSL Path Not Found!")
  }

  if (verbose) {
    msg = "# Processing The Data"
    message(msg)
  }
  if (shiny) {
    shiny::setProgress(message = msg, value = 0)
  }
  if (save_imgs) {
    if (is.character(img)) {
      if (is.null(stub)) {
        stub = paste0(nii.stub(img, bn = TRUE), "_reg_")
      }
    }
  }
  # orig.img = img
  preprocess = ich_preprocess(
    img = img,
    mask = mask,
    verbose = verbose,
    shiny = shiny,
    roi = roi,
    ...)

  timg = preprocess$transformed_image
  troi = preprocess$transformed_roi
  tmask = preprocess$transformed_mask > 0.5

  if (save_imgs) {
    if (!is.null(outdir)) {
      if (!is.null(stub)) {
        fname = file.path(outdir, paste0(stub, "_", "image"))
        writenii(timg, fname)
        if (!is.null(troi)) {
          fname = file.path(outdir, paste0(stub, "_", "roi"))
          writenii(troi, fname)
        }
        fname = file.path(outdir, paste0(stub, "_", "mask"))
        writenii(tmask, fname)
      }
    }
  }


  L = list(
    preprocess = preprocess
  )
  rm(list = "preprocess"); gc()

  if (verbose) {
    msg = "# Making Predictors"
    message(msg)
  }
  if (shiny) {
    shiny::setProgress(message = msg, value = 1/3)
  }

  img.pred = make_predictors(
    timg, mask = tmask,
    roi = troi,
    save_imgs = save_imgs,
    stub = stub,
    outdir = outdir,
    verbose = verbose,
    shiny = shiny,
    erode_mask = erode_mask)
  L$img.pred = img.pred
  rm(list = "img.pred")
  gc()

  if (shiny) {
    shiny::setProgress(value = 2/3)
  }
  return(L)
}