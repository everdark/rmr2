# Copyright 2011 Revolution Analytics
#    
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#      http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, 
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

## push a file through this to get as many partitions as possible (depending on system settings)
## data is unchanged

scatter = function(input, output = NULL, ...)
  mapreduce(input, 
            output, 
            map = function(k, v) keyval(runif(1), v), 
            reduce = function(k, vv) vv,
            ...)

gather = function(input, output = NULL, ...) {
  backend.parameters = list(...)['backend.prameters']
  backend.parameters$hadoop = append(backend.parameters$hadoop, list(D='mapred.reduce.tasks=1'))
  mapreduce(input,
            output, 
            backend.parameters = backend.parameters,
            ...)}

#sampling

rmr.sample = function(input, output = NULL, method = c("any", "Bernoulli"), ...) {
  method = match.arg(method)
  if (method == "any") {
    n = list(...)[['n']]
    some = function(k, v) 
      keyval(
        if(is.null(k))
          list(NULL)
        else
          rmr.slice(k, 1:min(n, rmr.length(k))),
        rmr.slice(v, 1:min(n, rmr.length(v))))
    mapreduce(input, 
              output,
              map = some,
              combine = T,
              reduce = some)}
  else
    if(method == "Bernoulli"){
      p = list(...)[['p']]
      mapreduce(input,
                output,
                map = function(k, v) {
                  filter = rbinom(rmr.length(v), 1, p) == 1
                  keyval(rmr.slice(k, filter),
                         rmr.slice(v, filter))})}}

## map and reduce generators

partitioned.map = 
  function(map, n)
    function(k,v) {
      kv = map(k,v)
      keyval(
        data.frame(
          sample(
            1:n, size=length(k), 
            replace=T), k),
        v)}

partitioned.combine = 
  function(reduce)
    function(k,vv) {
      kv = reduce(k,vv)
      keyval(k[,-1], vv)}

## fast aggregate functions

vsum = 
  function(x) {
    if(is.list(x)) 
      .Call("vsum", x, PACKAGE = "rmr2")
    else  
      stop(paste("can't vsum a ", class(x)))}
            
##optimizer

is.mapreduce = function(x) {
  is.call(x) && x[[1]] == "mapreduce"}

mapreduce.arg = function(x, arg) {
  match.call(mapreduce, x) [[arg]]}

optimize = function(mrex) {
  mrin = mapreduce.arg(mrex, 'input')
  if (is.mapreduce(mrex) && 
    is.mapreduce(mrin) &&
    is.null(mapreduce.arg(mrin, 'output')) &&
    is.null(mapreduce.arg(mrin, 'reduce'))) {
    bquote(
      mapreduce(input =  .(mapreduce.arg(mrin, 'input')), 
                output = .(mapreduce.arg(mrex, 'output')), 
                map = .(compose.mapred)(.(mapreduce.arg(mrex, 'map')), 
                                        .(mapreduce.arg(mrin, 'map'))), 
                reduce = .(mapreduce.arg(mrex, 'reduce'))))}
  else mrex }

## dev support

reload = 
  function() {
    detach("package:rmr2", unload=T)
    library.dynam.unload("rmr2",system.file(package="rmr2"))
    library(rmr2)}

rmr.str = 
  function(x, ...) {
    sc = sys.calls()
    message(
      paste(
        c(
          capture.output(
            str(sc)), 
          match.call() [[2]], 
          capture.output(str(x, ...))), 
        collapse="\n"))
    x}
