docker run -it --rm --privileged \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v ~/amoebius:/amoebius \
  tuee22/amoebius:latest