#!/bin/sh
set -e
rm -rf .vim /tmp/readdir
cp -a vim .vim
mkdir /tmp/readdir
GIT_INDEX_FILE=git-index GIT_WORK_TREE=/tmp/readdir git checkout master -- .
GIT_INDEX_FILE=/tmp/readdir/git-index GIT_WORK_TREE=.vim git checkout-index -a
rm /tmp/readdir/git-index
HOME=$PWD MYVIMRC= VIMINIT= mvim -c echo /tmp/readdir
screencapture -W screenshot.png
open -a ImageOptim screenshot.png
rm -rf .vim /tmp/readdir
