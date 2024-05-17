FROM postgres:16

RUN apt-get update && apt-get install -y build-essential
RUN mkdir /usr/src/pgjwt
WORKDIR /usr/src/pgjwt
ADD https://github.com/michelp/pgjwt/archive/master.tar.gz .
RUN tar --strip-components=1 -xzf master.tar.gz
RUN make install