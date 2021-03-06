# Licensed to the Apache Software Foundation (ASF) under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  The ASF licenses this file
# to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
# with the License.  You may obtain a copy of the License at
#
#   http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License.

#' @include array.R
#' @include chunked-array.R
#' @include scalar.R

call_function <- function(function_name, ..., args = list(...), options = empty_named_list()) {
  assert_that(is.string(function_name))
  assert_that(is.list(options), !is.null(names(options)))

  datum_classes <- c("Array", "ChunkedArray", "RecordBatch", "Table", "Scalar")
  valid_args <- map_lgl(args, ~inherits(., datum_classes))
  if (!all(valid_args)) {
    # Lame, just pick one to report
    first_bad <- min(which(!valid_args))
    stop("Argument ", first_bad, " is of class ", head(class(args[[first_bad]]), 1), " but it must be one of ", oxford_paste(datum_classes, "or"), call. = FALSE)
  }

  compute__CallFunction(function_name, args, options)
}

#' @export
sum.Array <- function(..., na.rm = FALSE) scalar_aggregate("sum", ..., na.rm = na.rm)

#' @export
sum.ChunkedArray <- sum.Array

#' @export
sum.Scalar <- sum.Array

#' @export
mean.Array <- function(..., na.rm = FALSE) scalar_aggregate("mean", ..., na.rm = na.rm)

#' @export
mean.ChunkedArray <- mean.Array

#' @export
mean.Scalar <- mean.Array

#' @export
min.Array <- function(..., na.rm = FALSE) {
  scalar_aggregate("min_max", ..., na.rm = na.rm)$GetFieldByName("min")
}

#' @export
min.ChunkedArray <- min.Array

#' @export
max.Array <- function(..., na.rm = FALSE) {
  scalar_aggregate("min_max", ..., na.rm = na.rm)$GetFieldByName("max")
}

#' @export
max.ChunkedArray <- max.Array

scalar_aggregate <- function(FUN, ..., na.rm = FALSE) {
  a <- collect_arrays_from_dots(list(...))
  if (!na.rm && a$null_count > 0 && (FUN %in% c("mean", "sum"))) {
    # Arrow sum/mean function always drops NAs so handle that here
    # https://issues.apache.org/jira/browse/ARROW-9054
    return(Scalar$create(NA_real_))
  }

  call_function(FUN, a, options = list(na.rm = na.rm))
}

collect_arrays_from_dots <- function(dots) {
  # Given a list that may contain both Arrays and ChunkedArrays,
  # return a single ChunkedArray containing all of those chunks
  # (may return a regular Array if there is only one element in dots)
  assert_that(all(map_lgl(dots, is.Array)))
  if (length(dots) == 1) {
    return(dots[[1]])
  }

  arrays <- unlist(lapply(dots, function(x) {
    if (inherits(x, "ChunkedArray")) {
      x$chunks
    } else {
      x
    }
  }))
  ChunkedArray$create(!!!arrays)
}

#' @export
unique.Array <- function(x, incomparables = FALSE, ...) {
  call_function("unique", x)
}

#' @export
unique.ChunkedArray <- unique.Array

#' `match` for Arrow objects
#'
#' `base::match()` is not a generic, so we can't just define Arrow methods for
#' it. This function exposes the analogous function in the Arrow C++ library.
#'
#' @param x `Array` or `ChunkedArray`
#' @param table `Array`, `ChunkedArray`, or R vector lookup table.
#' @param ... additional arguments, ignored
#' @return An `int32`-type `Array` of the same length as `x` with the
#' (0-based) indexes into `table`.
#' @export
match_arrow <- function(x, table, ...) UseMethod("match_arrow")

#' @export
match_arrow.default <- function(x, table, ...) match(x, table, ...)

#' @export
match_arrow.Array <- function(x, table, ...) {
  if (!inherits(table, c("Array", "ChunkedArray"))) {
    table <- Array$create(table)
  }
  call_function("index_in_meta_binary", x, table)
}

#' @export
match_arrow.ChunkedArray <- match_arrow.Array

CastOptions <- R6Class("CastOptions", inherit = ArrowObject)

#' Cast options
#'
#' @param safe enforce safe conversion
#' @param allow_int_overflow allow int conversion, `!safe` by default
#' @param allow_time_truncate allow time truncate, `!safe` by default
#' @param allow_float_truncate allow float truncate, `!safe` by default
#'
#' @export
cast_options <- function(safe = TRUE,
                         allow_int_overflow = !safe,
                         allow_time_truncate = !safe,
                         allow_float_truncate = !safe) {
  compute___CastOptions__initialize(allow_int_overflow, allow_time_truncate, allow_float_truncate)
}
