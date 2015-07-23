#!/bin/sh
export DIONI_RUNTIME_DIR=dioni/runtime

#Build dioni

(cd dioni && dub build)

#Compile scripts, generate libscript.a

dioni/dioni scripts/ball.dn

#Copy interface.d
cp gen-dioni/interface.d source/dioni/

#Build lethe
dub build
