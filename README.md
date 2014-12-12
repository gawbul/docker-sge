docker-sge
==========

Dockerfile to build a container with SGE installed.

To build type:

```
docker build -t gawbul/docker-sge .
```

To run type:

```
docker run -it --rm gawbul/docker-sge /sbin/my_init -- bash
```
