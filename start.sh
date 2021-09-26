docker build . -t $1
docker run -it --rm -v ${PWD}:/root/ --add-host kubernetes:127.0.0.1 --name $1 $1