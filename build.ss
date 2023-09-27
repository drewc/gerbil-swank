#!/usr/bin/env gxi
;; -*- Gerbil -*-

(import :std/build-script)

(##shell-command "touch gerbil-swank.ss")

(defbuild-script
  '("gerbil-swank/expander-context"
    "gerbil-swank/swank"
    "gerbil-swank/core"
    "gerbil-swank/r7rs/gerbil-swank"
    "gerbil-swank/package"
    "gerbil-swank/slynk"
    "gerbil-swank")
  #;verbose: #;10)
